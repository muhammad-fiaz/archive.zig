const std = @import("std");
const config = @import("../config.zig");
const errors = @import("../errors.zig");
const zstd = @import("zstd");

pub fn compress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    if (data.len == 0) return allocator.alloc(u8, 0);

    const level = options.zstd_level orelse @as(i32, @intCast(options.level orelse 3));
    const compressed = zstd.compress(allocator, data, level) catch return errors.CompressError.ZstdError;
    return compressed;
}

pub fn decompress(allocator: std.mem.Allocator, data: []const u8, _: config.Options) ![]u8 {
    if (data.len == 0) return allocator.alloc(u8, 0);

    const content_size = zstd.getFrameContentSize(data);
    const expected_size: usize = switch (content_size) {
        .known => |size| @intCast(size),
        .unknown => data.len * 4,
        .@"error" => return errors.CompressError.InvalidData,
    };

    const decompressed = zstd.decompress(allocator, data, expected_size) catch return errors.CompressError.ZstdError;
    return decompressed;
}

test "zstd compress and decompress" {
    const testing = std.testing;

    const data = "Hello, World! This is a test string for Zstandard compression.";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}

test "zstd compress with custom level" {
    const testing = std.testing;

    const data = "Hello, World! This is a test string for Zstandard compression.";
    const compressed = try compress(testing.allocator, data, .{ .zstd_level = 10 });
    defer testing.allocator.free(compressed);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}

test "zstd empty data" {
    const testing = std.testing;

    const data = "";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}
