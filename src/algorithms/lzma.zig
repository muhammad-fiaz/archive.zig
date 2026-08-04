const std = @import("std");
const config = @import("../config.zig");
const errors = @import("../errors.zig");
const constants = @import("../constants.zig");
const utils = @import("../utils.zig");

pub fn compress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    try result.append(allocator, constants.LzmaConstants.properties_byte);

    const dict_size: u32 = constants.LzmaConstants.dict_size;
    try result.appendSlice(allocator, &std.mem.toBytes(dict_size));

    try result.appendSlice(allocator, &std.mem.toBytes(@as(u64, data.len)));

    if (data.len == 0) {
        return result.toOwnedSlice(allocator);
    }

    const compressed_data = try compressLzmaData(allocator, data, options.level orelse 6);
    defer allocator.free(compressed_data);

    try result.appendSlice(allocator, compressed_data);

    return result.toOwnedSlice(allocator);
}

pub fn decompress(allocator: std.mem.Allocator, data: []const u8, _: config.Options) ![]u8 {
    if (data.len < 13) return errors.CompressError.InvalidLzmaHeader;

    _ = data[0]; // properties byte
    const dict_size = std.mem.readInt(u32, data[1..5], .little);
    _ = dict_size;
    const uncompressed_len = std.mem.readInt(u64, data[5..13], .little);

    if (uncompressed_len > std.math.maxInt(usize)) return errors.CompressError.OutputTooLarge;

    const output_size = if (uncompressed_len == 0 or uncompressed_len == std.math.maxInt(u64))
        data.len * 4
    else
        @as(usize, @intCast(uncompressed_len));

    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    try result.ensureTotalCapacity(allocator, output_size);

    const compressed_data = data[13..];
    const decompressed_data = try decompressLzmaData(allocator, compressed_data, output_size);
    defer allocator.free(decompressed_data);

    try result.appendSlice(allocator, decompressed_data);

    return result.toOwnedSlice(allocator);
}

fn compressLzmaData(allocator: std.mem.Allocator, data: []const u8, level: u8) ![]u8 {
    _ = level;

    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    const min_match: usize = constants.LzmaConstants.min_match;
    const max_offset: usize = constants.LzmaConstants.max_offset;
    const hash_bits: u5 = 14;
    const hash_size: usize = 1 << hash_bits;

    var hash_table = try allocator.alloc(u32, hash_size);
    defer allocator.free(hash_table);
    @memset(hash_table, 0);

    var chain_table = try allocator.alloc(u32, @min(data.len, max_offset));
    defer allocator.free(chain_table);
    @memset(chain_table, 0);

    var pos: usize = 0;
    var anchor: usize = 0;

    while (pos + min_match <= data.len) {
        const hash = utils.lzmaHash(data[pos..], @min(3, data.len - pos)) % hash_size;
        const prev_pos = hash_table[hash];
        chain_table[pos % max_offset] = prev_pos;
        hash_table[hash] = @intCast(pos);

        var best_len: usize = 0;
        var best_offset: usize = 0;
        var search_pos = prev_pos;
        var chain_len: usize = 0;
        const max_chain: usize = 32;

        while (search_pos > 0 and chain_len < max_chain) : (chain_len += 1) {
            if (search_pos >= pos or pos - search_pos > max_offset) break;

            const offset = pos - search_pos;
            if (offset == 0) break;

            var match_len: usize = 0;
            while (pos + match_len < data.len and
                search_pos + match_len < pos and
                data[search_pos + match_len] == data[pos + match_len] and
                match_len < constants.LzmaConstants.max_match)
            {
                match_len += 1;
            }

            if (match_len >= min_match and match_len > best_len) {
                best_len = match_len;
                best_offset = offset;
            }

            search_pos = chain_table[search_pos % max_offset];
        }

        if (best_len >= min_match) {
            if (pos > anchor) {
                try writeLzmaLiterals(&result, allocator, data[anchor..pos]);
            }

            try writeLzmaMatch(&result, allocator, @intCast(best_offset), best_len);
            pos += best_len;
            anchor = pos;
        } else {
            pos += 1;
        }
    }

    if (anchor < data.len) {
        try writeLzmaLiterals(&result, allocator, data[anchor..]);
    }

    try result.append(allocator, 0x00);
    return result.toOwnedSlice(allocator);
}

fn decompressLzmaData(allocator: std.mem.Allocator, data: []const u8, expected_size: usize) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    try result.ensureTotalCapacity(allocator, expected_size);

    var pos: usize = 0;

    while (pos < data.len) {
        const byte = data[pos];

        if (byte == 0x00) {
            break;
        } else if ((byte & 0x80) != 0) {
            var lit_len: usize = 0;
            if (byte == 0xFF) {
                if (pos + 3 > data.len) return errors.CompressError.InvalidData;
                lit_len = std.mem.readInt(u16, data[pos + 1 ..][0..2], .little);
                pos += 3;
            } else {
                lit_len = byte & 0x7F;
                pos += 1;
            }

            if (pos + lit_len > data.len) return errors.CompressError.InvalidData;

            const literals = data[pos .. pos + lit_len];
            try result.appendSlice(allocator, literals);
            pos += lit_len;
        } else {
            if ((byte & 0x40) == 0) {
                if (pos + 2 > data.len) return errors.CompressError.InvalidData;

                const len = @as(usize, byte & 0x0F) + 2;
                const offset = @as(usize, data[pos + 1]);
                pos += 2;

                try copyLzmaMatch(&result, allocator, offset, len);
            } else {
                if (pos + 3 > data.len) return errors.CompressError.InvalidData;

                var len = @as(usize, byte & 0x0F) + 2;
                const offset = std.mem.readInt(u16, data[pos + 1 ..][0..2], .little);
                pos += 3;

                if (len == 17) {
                    if (pos >= data.len) return errors.CompressError.InvalidData;
                    len += @as(usize, data[pos]);
                    pos += 1;
                }

                try copyLzmaMatch(&result, allocator, offset, len);
            }
        }
    }

    return result.toOwnedSlice(allocator);
}

fn writeLzmaLiterals(result: *std.ArrayList(u8), allocator: std.mem.Allocator, literals: []const u8) !void {
    var offset: usize = 0;
    while (offset < literals.len) {
        const remaining = literals.len - offset;
        const chunk_len = @min(remaining, constants.LzmaConstants.max_offset);
        const chunk = literals[offset .. offset + chunk_len];

        if (chunk_len <= 126) {
            try result.append(allocator, 0x80 | @as(u8, @intCast(chunk_len)));
        } else {
            try result.append(allocator, 0xFF);
            try result.appendSlice(allocator, &std.mem.toBytes(@as(u16, @intCast(chunk_len))));
        }

        try result.appendSlice(allocator, chunk);
        offset += chunk_len;
    }
}

fn writeLzmaMatch(result: *std.ArrayList(u8), allocator: std.mem.Allocator, offset: u16, length: usize) !void {
    if (length <= 16 and offset <= 255) {
        try result.append(allocator, @as(u8, @intCast((length - 2) & 0x0F)));
        try result.append(allocator, @as(u8, @intCast(offset)));
    } else {
        try result.append(allocator, 0x40 | @as(u8, @intCast(@min(length - 2, 15))));
        try result.appendSlice(allocator, &std.mem.toBytes(offset));

        if (length >= 17) {
            try result.append(allocator, @as(u8, @intCast(@min(length - 17, 255))));
        }
    }
}

fn copyLzmaMatch(result: *std.ArrayList(u8), allocator: std.mem.Allocator, offset: usize, length: usize) !void {
    if (offset > result.items.len or offset == 0) return errors.CompressError.InvalidOffset;

    const start = result.items.len - offset;
    var i: usize = 0;
    while (i < length) : (i += 1) {
        const idx = start + (i % offset);
        try result.append(allocator, result.items[idx]);
    }
}

test "lzma compress and decompress" {
    const testing = std.testing;

    const data = "Hello, World! This is a test string for LZMA compression.";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}

test "lzma empty data" {
    const testing = std.testing;

    const data = "";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}
