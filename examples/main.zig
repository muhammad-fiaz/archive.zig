const std = @import("std");
const archive = @import("archive");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    std.debug.print("=== Archive.zig Examples ===\n\n", .{});

    try basicRoundtrip(allocator);
    try allAlgorithms(allocator);
    try configPresets(allocator);
    try autoDetection(allocator);

    std.debug.print("All examples completed successfully!\n", .{});
}

fn basicRoundtrip(allocator: std.mem.Allocator) !void {
    std.debug.print("1. Basic Roundtrip\n", .{});

    const input = "Hello, Archive.zig!";

    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);

    const decompressed = try archive.decompress(allocator, compressed, .gzip);
    defer allocator.free(decompressed);

    const ok = std.mem.eql(u8, input, decompressed);
    std.debug.print("   gzip: {d} -> {d} bytes, verified: {s}\n\n", .{ input.len, compressed.len, if (ok) "OK" else "FAIL" });
}

fn allAlgorithms(allocator: std.mem.Allocator) !void {
    std.debug.print("2. All Algorithms\n", .{});

    const input = "The quick brown fox jumps over the lazy dog. " ** 100;

    const algos = [_]archive.Algorithm{ .gzip, .zlib, .deflate, .zstd, .lz4, .lzma, .xz, .tar_gz, .zip, .brotli };

    for (algos) |algo| {
        const compressed = try archive.compress(allocator, input, algo);
        defer allocator.free(compressed);

        const decompressed = try archive.decompress(allocator, compressed, algo);
        defer allocator.free(decompressed);

        const ok = std.mem.eql(u8, input, decompressed);
        const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;
        std.debug.print("   {s:8} {d:6} -> {d:6} bytes ({d:.1}%) verified: {s}\n", .{ @tagName(algo), input.len, compressed.len, ratio, if (ok) "OK" else "FAIL" });
    }
    std.debug.print("\n", .{});
}

fn configPresets(allocator: std.mem.Allocator) !void {
    std.debug.print("3. Configuration Presets\n", .{});

    const input = "The quick brown fox jumps over the lazy dog. " ** 100;

    const levels = [_]archive.Level{ .fastest, .fast, .default, .best, .ultra };
    for (levels) |level| {
        const cfg = archive.CompressionConfig.init(.zstd).withLevel(level);
        const compressed = try archive.compressWithConfig(allocator, input, cfg);
        defer allocator.free(compressed);
        const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;
        std.debug.print("   {s:8} {d:6} bytes ({d:.1}%)\n", .{ @tagName(level), compressed.len, ratio });
    }

    const custom = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(15)
        .withChecksum()
        .withWindowSize(1 << 22);
    const custom_compressed = try archive.compressWithConfig(allocator, input, custom);
    defer allocator.free(custom_compressed);
    std.debug.print("   {s:8} {d:6} bytes (custom zstd:15)\n\n", .{ "custom", custom_compressed.len });
}

fn autoDetection(allocator: std.mem.Allocator) !void {
    std.debug.print("4. Auto-Detection\n", .{});

    const input = "Auto-detection test data for all algorithms.";

    const algos = [_]archive.Algorithm{ .gzip, .zstd, .lz4, .zlib, .lzma, .xz, .brotli };
    for (algos) |algo| {
        const compressed = try archive.compress(allocator, input, algo);
        defer allocator.free(compressed);

        const detected = archive.detectAlgorithm(compressed);
        const ok = detected != null and detected.? == algo;
        std.debug.print("   {s:8} -> {s:8} {s}\n", .{ @tagName(algo), if (detected) |d| @tagName(d) else "none", if (ok) "OK" else "FAIL" });
    }
    std.debug.print("\n", .{});
}
