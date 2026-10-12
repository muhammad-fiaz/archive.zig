const std = @import("std");
const config = @import("../config.zig");
const errors = @import("../errors.zig");
const zstd = @import("zstd");

fn effectiveLevel(options: config.Options) i32 {
    if (options.zstd_level) |l| return std.math.clamp(l, 1, 22);
    if (options.level) |l| return std.math.clamp(@as(i32, l), 1, 22);
    return 3;
}

fn mapCompressError(err: anyerror) errors.CompressError {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.ZstdError,
    };
}

fn mapDecompressError(err: anyerror) errors.CompressError {
    return switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => error.InvalidData,
    };
}

pub fn compress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    if (data.len == 0) return allocator.alloc(u8, 0);

    const level: i32 = effectiveLevel(options);
    var opts = zstd.CompressionOptions{ .level = level };
    opts.checksum = options.checksum;
    if (options.window_size) |ws| {
        // windowLog is log2(window size), clamped to the format range.
        const ws_log = std.math.log2_int(usize, @max(ws, 1024));
        opts.windowLog = @intCast(@min(@max(ws_log, 10), 27));
    }
    if (options.dictionary) |_| {
        // Raw-slice dictionaries are not part of the 0.0.4 one-shot API that
        // takes ownership-safe prepared dictionaries; report explicitly.
        return error.UnsupportedAlgorithm;
    }

    return zstd.compressWithOptions(allocator, data, opts) catch |err| mapCompressError(err);
}

pub fn decompress(allocator: std.mem.Allocator, data: []const u8, _: config.Options) ![]u8 {
    if (data.len == 0) return allocator.alloc(u8, 0);
    if (!zstd.isFrame(data)) return error.InvalidData;

    return zstd.decompress(allocator, data) catch |err| mapDecompressError(err);
}

/// Returns true when `data` starts with a Zstandard frame magic.
pub fn isFrame(data: []const u8) bool {
    return zstd.isFrame(data);
}

/// Declared decompressed size of the first frame, or null when unknown/invalid.
pub fn frameContentSize(data: []const u8) ?u64 {
    const size = zstd.getFrameContentSize(data);
    if (size == zstd.CONTENTSIZE_UNKNOWN or size == zstd.CONTENTSIZE_ERROR) return null;
    return size;
}

test "zstd compress and decompress" {
    const testing = std.testing;

    const data = "Hello, World! This is a test string for Zstandard compression.";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    try testing.expect(isFrame(compressed));

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

test "zstd invalid data" {
    const testing = std.testing;
    const bad = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0x04 };
    try testing.expectError(error.InvalidData, decompress(testing.allocator, &bad, .{}));
}

test "zstd dependency version" {
    const testing = std.testing;
    try testing.expectEqualStrings("0.0.4", zstd.version);
    try testing.expect(zstd.maxCLevel() >= 22);
}
