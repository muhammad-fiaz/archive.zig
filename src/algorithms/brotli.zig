const std = @import("std");
const config = @import("../config.zig");
const errors = @import("../errors.zig");
const brotli = @import("brotli");

/// Library version of the integrated brotli.zig dependency (pure Zig, no libc).
pub const dependency_version = brotli.version;
/// Wire-format specification implemented by the dependency.
pub const spec_version = brotli.spec_version;

pub fn compress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    if (data.len == 0) return allocator.alloc(u8, 0);

    const quality: u32 = if (options.level) |lvl| @min(@as(u32, lvl), 11) else 6;
    if (options.dictionary) |_| return error.UnsupportedAlgorithm;

    var opts = brotli.CompressionOptions{ .quality = quality };
    if (options.window_size) |ws| {
        const lg = std.math.log2_int(usize, @max(ws, 1024));
        opts.lgWin = @intCast(@min(@max(lg, 10), 24));
    }

    return brotli.compressWithOptions(allocator, data, opts) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => errors.CompressError.InternalFailure,
    };
}

pub fn decompress(allocator: std.mem.Allocator, data: []const u8, _: config.Options) ![]u8 {
    if (data.len == 0) return allocator.alloc(u8, 0);

    return brotli.decompress(allocator, data) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => errors.CompressError.InvalidData,
    };
}

test "brotli compress and decompress" {
    const testing = std.testing;

    const data = "Hello, World! This is a test string for brotli compression.";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}

test "brotli empty data" {
    const testing = std.testing;

    const data = "";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}

test "brotli repetitive data" {
    const testing = std.testing;

    const data = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    try testing.expect(compressed.len < data.len);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}

test "brotli large data" {
    const testing = std.testing;

    var data: [10240]u8 = undefined;
    for (&data, 0..) |*ch, i| {
        ch.* = @intCast(i % 256);
    }

    const compressed = try compress(testing.allocator, &data, .{ .level = 6 });
    defer testing.allocator.free(compressed);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(&data, decompressed);
}

test "brotli quality levels" {
    const testing = std.testing;

    const data = "Testing brotli quality levels for compression ratio comparison. This is a longer string to ensure meaningful compression differences between quality levels.";

    for ([_]u8{ 1, 3, 6, 9, 11 }) |level| {
        const compressed = try compress(testing.allocator, data, .{ .level = level });
        defer testing.allocator.free(compressed);

        const decompressed = try decompress(testing.allocator, compressed, .{});
        defer testing.allocator.free(decompressed);

        try testing.expectEqualStrings(data, decompressed);
    }
}
