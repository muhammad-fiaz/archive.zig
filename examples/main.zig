const std = @import("std");
const archive = @import("archive");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    std.debug.print("=== Archive.zig Examples ===\n\n", .{});

    try basicCompression(allocator);
    try configurationExamples(allocator, io);
    try algorithmComparison(allocator, io);
    try autoDetectionExample(allocator);

    std.debug.print("\nAll examples completed successfully!\n", .{});
}

fn getTimestampNs(io: std.Io) i96 {
    return std.Io.Clock.awake.now(io).nanoseconds;
}

fn basicCompression(allocator: std.mem.Allocator) !void {
    std.debug.print("1. Basic Compression\n", .{});
    std.debug.print("   ==================\n", .{});

    const input = "Hello, World! This is a test of the archive library.";

    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);

    const decompressed = try archive.decompress(allocator, compressed, .gzip);
    defer allocator.free(decompressed);

    const verified = std.mem.eql(u8, input, decompressed);
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;

    std.debug.print("   Input: {d} bytes\n", .{input.len});
    std.debug.print("   Compressed: {d} bytes ({d:.1}%)\n", .{ compressed.len, ratio });
    std.debug.print("   Verified: {s}\n\n", .{if (verified) "OK" else "FAIL"});
}

fn configurationExamples(allocator: std.mem.Allocator, io: std.Io) !void {
    std.debug.print("2. Configuration Examples\n", .{});
    std.debug.print("   ======================\n", .{});

    const config_test_file = "build.zig";
    const file_data = std.Io.Dir.cwd().readFileAlloc(io, config_test_file, allocator, .limited(10 * 1024 * 1024)) catch |err| {
        std.debug.print("   ERROR Could not read {s}: {}\n", .{ config_test_file, err });
        return;
    };
    defer allocator.free(file_data);

    std.debug.print("   File: {s} ({d} bytes)\n\n", .{ config_test_file, file_data.len });

    std.debug.print("   ZSTD Compression Levels:\n", .{});
    const zstd_levels = [_]c_int{ 1, 3, 6, 10, 15, 19, 22 };
    for (zstd_levels) |level| {
        const cfg = archive.CompressionConfig.init(.zstd).withZstdLevel(level);
        const start_time = getTimestampNs(io);

        const compressed = archive.compressWithConfig(allocator, file_data, cfg) catch |err| {
            std.debug.print("     Level {d:2}: ERROR - {}\n", .{ level, err });
            continue;
        };
        defer allocator.free(compressed);

        const compress_time = getTimestampNs(io);
        const comp_ms = @as(f64, @floatFromInt(@as(i128, compress_time - start_time))) / 1_000_000.0;

        if (compressed.len < file_data.len) {
            const savings = ((1.0 - (@as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(file_data.len)))) * 100.0);
            std.debug.print("     Level {d:2}: {d:6} bytes ({d:5.1}% smaller) - {d:6.2}ms\n", .{ level, compressed.len, savings, comp_ms });
        } else {
            std.debug.print("     Level {d:2}: {d:6} bytes (larger) - {d:6.2}ms\n", .{ level, compressed.len, comp_ms });
        }
    }

    std.debug.print("\n   Level Enum:\n", .{});
    const levels = [_]archive.Level{ .fastest, .fast, .default, .best, .ultra };
    for (levels) |level| {
        const cfg = archive.CompressionConfig.init(.gzip).withLevel(level);
        const compressed = archive.compressWithConfig(allocator, file_data, cfg) catch continue;
        defer allocator.free(compressed);
        std.debug.print("     {s:10}: {d:6} bytes\n", .{ @tagName(level), compressed.len });
    }

    std.debug.print("\n   Builder Pattern:\n", .{});
    const custom_cfg = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(15)
        .withChecksum()
        .withWindowSize(1 << 22)
        .withMemoryLevel(8);
    const compressed = archive.compressWithConfig(allocator, file_data, custom_cfg) catch |err| {
        std.debug.print("     ERROR: {}\n", .{err});
        return;
    };
    defer allocator.free(compressed);
    std.debug.print("     Custom config: {d} bytes\n", .{compressed.len});

    std.debug.print("\n", .{});
}

fn algorithmComparison(allocator: std.mem.Allocator, io: std.Io) !void {
    std.debug.print("3. Algorithm Performance Comparison\n", .{});
    std.debug.print("   ================================\n", .{});

    const test_file = "src/archive.zig";
    const file_data = std.Io.Dir.cwd().readFileAlloc(io, test_file, allocator, .limited(10 * 1024 * 1024)) catch |err| {
        std.debug.print("   ERROR Could not read {s}: {}\n", .{ test_file, err });
        return;
    };
    defer allocator.free(file_data);

    std.debug.print("   File: {s} ({d} bytes)\n\n", .{ test_file, file_data.len });

    const algos = [_]struct { algo: archive.Algorithm, name: []const u8 }{
        .{ .algo = .deflate, .name = "deflate" },
        .{ .algo = .gzip, .name = "gzip" },
        .{ .algo = .zlib, .name = "zlib" },
        .{ .algo = .zstd, .name = "zstd" },
        .{ .algo = .lz4, .name = "lz4" },
        .{ .algo = .lzma, .name = "lzma" },
        .{ .algo = .xz, .name = "xz" },
        .{ .algo = .tar_gz, .name = "tar_gz" },
        .{ .algo = .zip, .name = "zip" },
        .{ .algo = .brotli, .name = "brotli" },
    };

    std.debug.print("   Algorithm | Compressed | Ratio      | Comp Time | Decomp Time | Status\n", .{});
    std.debug.print("   ----------|------------|------------|-----------|-------------|--------\n", .{});

    for (algos) |algo| {
        const start_time = getTimestampNs(io);

        const compressed = archive.compress(allocator, file_data, algo.algo) catch |err| {
            std.debug.print("   {s:9} | ERROR: {}\n", .{ algo.name, err });
            continue;
        };
        defer allocator.free(compressed);

        const compress_time = getTimestampNs(io);

        const decompressed = archive.decompress(allocator, compressed, algo.algo) catch |err| {
            std.debug.print("   {s:9} | DECOMP ERROR: {}\n", .{ algo.name, err });
            continue;
        };
        defer allocator.free(decompressed);

        const decompress_time = getTimestampNs(io);

        const verified = std.mem.eql(u8, file_data, decompressed);
        const comp_ms = @as(f64, @floatFromInt(@as(i128, compress_time - start_time))) / 1_000_000.0;
        const decomp_ms = @as(f64, @floatFromInt(@as(i128, decompress_time - compress_time))) / 1_000_000.0;

        if (compressed.len < file_data.len) {
            const savings = ((1.0 - (@as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(file_data.len)))) * 100.0);
            std.debug.print("   {s:9} | {d:8}B | {d:6.1}% less | {d:7.2}ms | {d:9.2}ms | {s}\n", .{ algo.name, compressed.len, savings, comp_ms, decomp_ms, if (verified) "OK" else "FAIL" });
        } else {
            const increase = ((@as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(file_data.len))) - 1.0) * 100.0;
            std.debug.print("   {s:9} | {d:8}B | {d:6.1}% more | {d:7.2}ms | {d:9.2}ms | {s}\n", .{ algo.name, compressed.len, increase, comp_ms, decomp_ms, if (verified) "OK" else "FAIL" });
        }
    }
    std.debug.print("\n", .{});
}

fn autoDetectionExample(allocator: std.mem.Allocator) !void {
    std.debug.print("4. Auto-Detection\n", .{});
    std.debug.print("   ===============\n", .{});

    const input = "Auto-detection test data for compression algorithms.";

    const test_algorithms = [_]archive.Algorithm{ .gzip, .zstd, .lz4, .zlib, .lzma, .xz, .brotli };
    for (test_algorithms) |algo| {
        const compressed = archive.compress(allocator, input, algo) catch continue;
        defer allocator.free(compressed);

        const detected = archive.detectAlgorithm(compressed);
        const auto_decompressed = archive.autoDecompress(allocator, compressed) catch continue;
        defer allocator.free(auto_decompressed);

        const verified = std.mem.eql(u8, input, auto_decompressed);
        std.debug.print("   {s:8}: detected as {s:8} - {s}\n", .{ @tagName(algo), if (detected) |d| @tagName(d) else "none", if (verified) "OK" else "FAIL" });
    }

    std.debug.print("\n   File Extension Mapping:\n", .{});
    const ext_algorithms = [_]archive.Algorithm{ .gzip, .zstd, .lz4, .lzma, .xz, .deflate, .zlib, .brotli };
    for (ext_algorithms) |algo| {
        const ext = algo.extension();
        std.debug.print("     {s:8} -> {s}\n", .{ @tagName(algo), ext });
    }

    std.debug.print("\n", .{});
}
