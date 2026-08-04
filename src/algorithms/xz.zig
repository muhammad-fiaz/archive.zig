const std = @import("std");
const config = @import("../config.zig");
const errors = @import("../errors.zig");
const constants = @import("../constants.zig");
const utils = @import("../utils.zig");
const lzma = @import("lzma.zig");

pub fn compress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    try result.appendSlice(allocator, &constants.Magic.xz);

    try result.appendSlice(allocator, &[_]u8{ 0x00, 0x04 });

    const flags_crc = utils.calculateCRC32(&[_]u8{ 0x00, 0x04 });
    try result.appendSlice(allocator, &std.mem.toBytes(flags_crc));

    const block_start = result.items.len;
    try result.append(allocator, 0x00);
    try result.append(allocator, 0x00);

    try result.append(allocator, 0x21);
    try result.append(allocator, 0x01);
    try result.append(allocator, 0x00);

    while ((result.items.len - block_start + 4) % 4 != 0) {
        try result.append(allocator, 0x00);
    }

    const header_content_size = result.items.len - block_start;
    const total_header_size = header_content_size + 4;
    result.items[block_start] = @intCast((total_header_size / 4) - 1);

    const header_crc = utils.calculateCRC32(result.items[block_start..]);
    try result.appendSlice(allocator, &std.mem.toBytes(header_crc));

    const lzma_data = try compressLzma2(allocator, data, options.level orelse 6);
    defer allocator.free(lzma_data);

    try result.appendSlice(allocator, lzma_data);

    while (result.items.len % 4 != 0) {
        try result.append(allocator, 0x00);
    }

    const data_crc = utils.calculateCRC32(data);
    try result.appendSlice(allocator, &std.mem.toBytes(data_crc));

    const index_start = result.items.len;
    try result.append(allocator, 0x00);
    try result.append(allocator, 0x01);

    try result.append(allocator, @intCast(@min(lzma_data.len, 127)));
    try result.append(allocator, @intCast(@min(data.len, 127)));

    while ((result.items.len - index_start) % 4 != 0) {
        try result.append(allocator, 0x00);
    }

    const index_crc = utils.calculateCRC32(result.items[index_start..]);
    try result.appendSlice(allocator, &std.mem.toBytes(index_crc));

    const footer_crc = utils.calculateCRC32(&[_]u8{ 0x00, 0x04 });
    try result.appendSlice(allocator, &std.mem.toBytes(footer_crc));

    const index_size = result.items.len - index_start;
    try result.appendSlice(allocator, &std.mem.toBytes(@as(u32, @intCast(index_size / 4 - 1))));
    try result.appendSlice(allocator, &[_]u8{ 0x00, 0x04 });
    try result.appendSlice(allocator, &constants.Magic.xz_footer);

    return result.toOwnedSlice(allocator);
}

pub fn decompress(allocator: std.mem.Allocator, data: []const u8, _: config.Options) ![]u8 {
    if (data.len < 12) return errors.CompressError.InvalidData;

    const magic = data[0..6];
    if (!std.mem.eql(u8, magic, &constants.Magic.xz)) {
        return errors.CompressError.InvalidMagic;
    }

    var pos: usize = 6 + 6; // skip magic + flags

    const header_size_encoded = data[pos];
    pos += 1;
    if (header_size_encoded == 0) return errors.CompressError.InvalidData;

    const header_size = (@as(usize, header_size_encoded) + 1) * 4;
    pos += header_size - 1;

    const lzma2_data = data[pos .. data.len - 12];
    return decompressLzma2(allocator, lzma2_data);
}

fn compressLzma2(allocator: std.mem.Allocator, data: []const u8, level: u8) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    if (data.len == 0) {
        try result.append(allocator, 0x00);
        return result.toOwnedSlice(allocator);
    }

    const chunk_size = constants.LzmaConstants.chunk_size;
    var pos: usize = 0;

    while (pos < data.len) {
        const end = @min(pos + chunk_size, data.len);
        const chunk = data[pos..end];
        const uncompressed_size = chunk.len;

        var lzma_data: std.ArrayList(u8) = .empty;
        defer lzma_data.deinit(allocator);

        const compressed_chunk = try lzma.compress(allocator, chunk, .{ .level = level });
        defer allocator.free(compressed_chunk);

        try lzma_data.appendSlice(allocator, compressed_chunk[13..]);

        if (lzma_data.items.len > 65535) {
            return errors.CompressError.OutputTooLarge;
        }

        try result.append(allocator, 0x02);
        try result.appendSlice(allocator, &std.mem.toBytes(@as(u16, @intCast(uncompressed_size - 1))));
        try result.appendSlice(allocator, &std.mem.toBytes(@as(u16, @intCast(lzma_data.items.len - 1))));
        try result.appendSlice(allocator, lzma_data.items);

        pos += uncompressed_size;
    }

    try result.append(allocator, 0x00);
    return result.toOwnedSlice(allocator);
}

fn decompressLzma2(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    if (data.len < 1) return errors.CompressError.InvalidData;

    var pos: usize = 0;
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(allocator);

    while (pos < data.len) {
        const control = data[pos];
        pos += 1;
        if (control == 0x00) break;

        if (control == 0x02) {
            if (pos + 4 > data.len) return errors.CompressError.InvalidData;
            const unpacked_size = @as(usize, std.mem.readInt(u16, data[pos..][0..2], .little)) + 1;
            const packed_size = @as(usize, std.mem.readInt(u16, data[pos + 2 ..][0..2], .little)) + 1;
            pos += 4;

            if (pos + packed_size > data.len) return errors.CompressError.InvalidData;

            const chunk_data = data[pos .. pos + packed_size];
            pos += packed_size;

            var lzma_header: std.ArrayList(u8) = .empty;
            defer lzma_header.deinit(allocator);

            try lzma_header.append(allocator, constants.LzmaConstants.properties_byte);
            try lzma_header.appendSlice(allocator, &std.mem.toBytes(@as(u32, constants.LzmaConstants.dict_size)));
            try lzma_header.appendSlice(allocator, &std.mem.toBytes(@as(u64, unpacked_size)));
            try lzma_header.appendSlice(allocator, chunk_data);

            const chunk_decompressed = try lzma.decompress(allocator, lzma_header.items, .{});
            defer allocator.free(chunk_decompressed);

            try result.appendSlice(allocator, chunk_decompressed);
        } else {
            return errors.CompressError.UnsupportedLzma2Chunk;
        }
    }

    return result.toOwnedSlice(allocator);
}

test "xz compress and decompress" {
    const testing = std.testing;

    const data = "Hello, World! This is a test string for XZ compression.";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    try testing.expect(std.mem.startsWith(u8, compressed, &constants.Magic.xz));

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}

test "xz empty data" {
    const testing = std.testing;

    const data = "";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}
