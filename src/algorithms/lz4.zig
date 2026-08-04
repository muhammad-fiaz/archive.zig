const std = @import("std");
const config = @import("../config.zig");
const errors = @import("../errors.zig");
const constants = @import("../constants.zig");
const utils = @import("../utils.zig");

const LZ4_MAGIC = [4]u8{ 0x04, 0x22, 0x4D, 0x18 };

pub fn compress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    _ = options;
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, &LZ4_MAGIC);

    const flags: u8 = 0x40;
    try result.append(allocator, flags);

    const block_size: u8 = 0x70;
    try result.append(allocator, block_size);

    const header_checksum = utils.lz4HeaderChecksum(&[_]u8{ flags, block_size }) & 0xFF;
    try result.append(allocator, @intCast(header_checksum));

    if (data.len == 0) {
        try result.appendSlice(allocator, &[_]u8{ 0, 0, 0, 0 });
        return result.toOwnedSlice(allocator);
    }

    const compressed_block = try compressBlock(allocator, data);
    defer allocator.free(compressed_block);

    const block_size_le = @as(u32, @intCast(compressed_block.len));
    try result.appendSlice(allocator, &std.mem.toBytes(block_size_le));
    try result.appendSlice(allocator, compressed_block);

    try result.appendSlice(allocator, &[_]u8{ 0, 0, 0, 0 });

    return result.toOwnedSlice(allocator);
}

pub fn decompress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    _ = options;
    if (data.len < 7) return errors.CompressError.InvalidData;

    if (!std.mem.eql(u8, data[0..4], &LZ4_MAGIC)) {
        return errors.CompressError.InvalidMagic;
    }

    var pos: usize = 7;
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    while (pos + 4 <= data.len) {
        const block_size = std.mem.readInt(u32, data[pos..][0..4], .little);
        pos += 4;

        if (block_size == 0) break;

        if (pos + block_size > data.len) return errors.CompressError.InvalidData;

        const block_data = data[pos .. pos + block_size];
        const decompressed_block = try decompressBlock(allocator, block_data);
        defer allocator.free(decompressed_block);

        try result.appendSlice(allocator, decompressed_block);
        pos += block_size;
    }

    return result.toOwnedSlice(allocator);
}

fn compressBlock(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    if (data.len == 0) return allocator.alloc(u8, 0);

    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    const min_match = constants.Lz4Constants.min_match;
    const max_offset = constants.Lz4Constants.max_offset;
    const hash_size = constants.Lz4Constants.hash_size;

    var hash_table = try allocator.alloc(u32, hash_size);
    defer allocator.free(hash_table);
    @memset(hash_table, 0);

    var pos: usize = 0;
    var anchor: usize = 0;

    while (pos + min_match <= data.len) {
        const hash = utils.lz4Hash(data[pos..][0..4]);
        const match_pos = hash_table[hash];
        hash_table[hash] = @intCast(pos);

        const offset = pos - match_pos;
        if (match_pos > 0 and offset > 0 and offset <= max_offset and
            pos + min_match <= data.len and match_pos + min_match <= data.len and
            std.mem.eql(u8, data[match_pos..][0..min_match], data[pos..][0..min_match]))
        {
            var match_len: usize = min_match;
            while (pos + match_len < data.len and
                match_pos + match_len < pos and
                data[match_pos + match_len] == data[pos + match_len])
            {
                match_len += 1;
            }

            try writeLz4Sequence(&result, allocator, data[anchor..pos], @intCast(offset), match_len);
            pos += match_len;
            anchor = pos;
        } else {
            pos += 1;
        }
    }

    if (anchor < data.len) {
        try writeLz4Literals(&result, allocator, data[anchor..]);
    }

    return result.toOwnedSlice(allocator);
}

fn decompressBlock(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    var pos: usize = 0;

    while (pos < data.len) {
        if (pos >= data.len) break;

        const token = data[pos];
        pos += 1;

        var lit_len: usize = @intCast((token >> 4) & 0x0F);
        var ml: usize = @intCast(token & 0x0F);

        if (lit_len == 15) {
            while (pos < data.len) {
                const byte = data[pos];
                pos += 1;
                lit_len += byte;
                if (byte != 255) break;
            }
        }

        if (pos + lit_len > data.len) return errors.CompressError.InvalidData;

        const literals = data[pos .. pos + lit_len];
        try result.appendSlice(allocator, literals);
        pos += lit_len;

        if (pos >= data.len) break;

        if (pos + 2 > data.len) return errors.CompressError.InvalidData;
        const offset = std.mem.readInt(u16, data[pos..][0..2], .little);
        pos += 2;

        if (ml == 15) {
            while (pos < data.len) {
                const byte = data[pos];
                pos += 1;
                ml += byte;
                if (byte != 255) break;
            }
        }

        const match_len = ml + 4;
        try copyMatch(&result, allocator, offset, match_len);
    }

    return result.toOwnedSlice(allocator);
}

fn writeLz4Sequence(result: *std.ArrayList(u8), allocator: std.mem.Allocator, literals: []const u8, offset: u16, match_len: usize) !void {
    const lit_len = literals.len;
    const ml = match_len - 4;

    var token: u8 = 0;
    if (lit_len >= 15) {
        token |= 0xF0;
    } else {
        token |= @as(u8, @intCast(lit_len)) << 4;
    }

    if (ml >= 15) {
        token |= 0x0F;
    } else {
        token |= @as(u8, @intCast(ml));
    }

    try result.append(allocator, token);

    if (lit_len >= 15) {
        var remaining = lit_len - 15;
        while (remaining >= 255) {
            try result.append(allocator, 255);
            remaining -= 255;
        }
        try result.append(allocator, @intCast(remaining));
    }

    try result.appendSlice(allocator, literals);
    try result.appendSlice(allocator, &std.mem.toBytes(offset));

    if (ml >= 15) {
        var remaining = ml - 15;
        while (remaining >= 255) {
            try result.append(allocator, 255);
            remaining -= 255;
        }
        try result.append(allocator, @intCast(remaining));
    }
}

fn writeLz4Literals(result: *std.ArrayList(u8), allocator: std.mem.Allocator, literals: []const u8) !void {
    const lit_len = literals.len;

    var token: u8 = 0;
    if (lit_len >= 15) {
        token = 0xF0;
    } else {
        token = @as(u8, @intCast(lit_len)) << 4;
    }

    try result.append(allocator, token);

    if (lit_len >= 15) {
        var remaining = lit_len - 15;
        while (remaining >= 255) {
            try result.append(allocator, 255);
            remaining -= 255;
        }
        try result.append(allocator, @intCast(remaining));
    }

    try result.appendSlice(allocator, literals);
}

fn copyMatch(result: *std.ArrayList(u8), allocator: std.mem.Allocator, offset: usize, length: usize) !void {
    if (offset > result.items.len or offset == 0) return errors.CompressError.InvalidOffset;

    const start = result.items.len - offset;
    var i: usize = 0;
    while (i < length) : (i += 1) {
        const idx = start + (i % offset);
        try result.append(allocator, result.items[idx]);
    }
}

test "lz4 compress and decompress" {
    const testing = std.testing;

    const data = "Hello, World! This is a test string for LZ4 compression.";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    try testing.expect(std.mem.startsWith(u8, compressed, &LZ4_MAGIC));

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}

test "lz4 empty data" {
    const testing = std.testing;

    const data = "";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}
