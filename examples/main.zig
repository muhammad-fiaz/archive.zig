const std = @import("std");
const archive = @import("archive");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    std.debug.print("=== Archive.zig v{s} Examples (Zig 0.17.0+) ===\n\n", .{archive.version});

    try basicRoundtrip(allocator);
    try allAlgorithms(allocator);
    try configPresets(allocator);
    try streamingExample(allocator);
    try archiveEntriesExample(allocator);
    try brotliZstdExample(allocator);
    try errorHandlingExample(allocator);

    std.debug.print("All examples completed successfully!\n", .{});
}

fn repeatAlloc(allocator: std.mem.Allocator, pattern: []const u8, times: usize) ![]u8 {
    const out = try allocator.alloc(u8, pattern.len * times);
    for (0..times) |i| {
        @memcpy(out[i * pattern.len .. (i + 1) * pattern.len], pattern);
    }
    return out;
}

fn basicRoundtrip(allocator: std.mem.Allocator) !void {
    std.debug.print("1. Basic Roundtrip (caller owns every returned slice)\n", .{});

    const input = "Hello, Archive.zig!";

    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);

    const decompressed = try archive.decompress(allocator, compressed, .gzip);
    defer allocator.free(decompressed);

    const ok = std.mem.eql(u8, input, decompressed);
    std.debug.print("   gzip: {d} -> {d} bytes, verified: {s}\n\n", .{ input.len, compressed.len, if (ok) "OK" else "FAIL" });
}

fn allAlgorithms(allocator: std.mem.Allocator) !void {
    std.debug.print("2. All Algorithms (unified API)\n", .{});

    const input = try repeatAlloc(allocator, "The quick brown fox jumps over the lazy dog. ", 100);
    defer allocator.free(input);

    const algos = [_]archive.Algorithm{ .gzip, .zlib, .deflate, .lz4, .lzma, .xz, .tar_gz, .zip, .zstd, .brotli };

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

    const input = try repeatAlloc(allocator, "The quick brown fox jumps over the lazy dog. ", 100);
    defer allocator.free(input);

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
    std.debug.print("   {s:8} {d:6} bytes (custom zstd:15)\n", .{ "custom", custom_compressed.len });

    // Strict validation rejects bad levels instead of clamping.
    const bad = archive.CompressionConfig.init(.zstd).withCheckedZstdLevel(99);
    std.debug.print("   strict level rejected invalid input: {s}\n\n", .{if (bad) |_| "NO (unexpected)" else |_| "yes"});
}

fn streamingExample(allocator: std.mem.Allocator) !void {
    std.debug.print("4. Streaming Interface (buffered adapter: input chunks in, one-shot encode on finish)\n", .{});

    const input = try repeatAlloc(allocator, "Streaming compression example data. ", 50);
    defer allocator.free(input);

    var compress_stream = try archive.stream.CompressStream.init(allocator, .deflate, .default);
    defer compress_stream.deinit();

    // Incremental input: split across chunk boundaries.
    var off: usize = 0;
    while (off < input.len) {
        const end = @min(off + 64, input.len);
        try compress_stream.write(input[off..end]);
        off = end;
    }
    const compressed = try compress_stream.finish();
    defer allocator.free(compressed);

    var decompress_stream = archive.stream.DecompressStream.init(allocator, .deflate);
    defer decompress_stream.deinit();

    // Feed the compressed bytes back in two halves.
    const mid = compressed.len / 2;
    try decompress_stream.write(compressed[0..mid]);
    try decompress_stream.write(compressed[mid..]);
    const decompressed = try decompress_stream.finish();
    defer allocator.free(decompressed);

    const ok = std.mem.eql(u8, input, decompressed);
    std.debug.print("   deflate streaming: {d} -> {d} -> {d} bytes, verified: {s}\n\n", .{ input.len, compressed.len, decompressed.len, if (ok) "OK" else "FAIL" });
}

fn archiveEntriesExample(allocator: std.mem.Allocator) !void {
    std.debug.print("5. Archive Entries (multi-file ZIP and TAR.GZ)\n", .{});

    // ZIP with two entries.
    const zip_entries = [_]archive.algorithms.zip.ZipEntryData{
        .{ .name = "hello.txt", .data = "Hello, ZIP!" },
        .{ .name = "docs/readme.txt", .data = "Second entry contents." },
    };
    const zip_bytes = try archive.algorithms.zip.pack(allocator, &zip_entries, .{});
    defer allocator.free(zip_bytes);
    const zip_parsed = try archive.algorithms.zip.unpackAll(allocator, zip_bytes);
    defer archive.algorithms.zip.freeUnpacked(allocator, zip_parsed);
    std.debug.print("   zip: {d} entries, first={s} ({d} bytes)\n", .{ zip_parsed.len, zip_parsed[0].name, zip_parsed[0].data.len });

    // TAR.GZ with two entries.
    const tar_entries = [_]archive.algorithms.tar_gz.TarEntry{
        .{ .name = "hello.txt", .data = "Hello, TAR.GZ!" },
        .{ .name = "docs/readme.txt", .data = "Second entry contents." },
    };
    const tar_bytes = try archive.algorithms.tar_gz.pack(allocator, &tar_entries, .{});
    defer allocator.free(tar_bytes);
    const tar_parsed = try archive.algorithms.tar_gz.unpack(allocator, tar_bytes, .{});
    defer archive.algorithms.tar_gz.freeEntries(allocator, tar_parsed);
    std.debug.print("   tar.gz: {d} entries, first={s} ({d} bytes)\n\n", .{ tar_parsed.len, tar_parsed[0].name, tar_parsed[0].data.len });
}

fn brotliZstdExample(allocator: std.mem.Allocator) !void {
    std.debug.print("6. Brotli and Zstandard Integration (native-Zig deps v0.0.4)\n", .{});
    const input = "Brotli and Zstandard round-trip through the unified API with algorithm-specific levels.";

    {
        const cfg = archive.CompressionConfig.init(.zstd).withZstdLevel(10);
        const compressed = try archive.compressWithConfig(allocator, input, cfg);
        defer allocator.free(compressed);
        const decompressed = try archive.decompress(allocator, compressed, .zstd);
        defer allocator.free(decompressed);
        std.debug.print("   zstd level 10: {d} -> {d} bytes, verified: {s}\n", .{ input.len, compressed.len, if (std.mem.eql(u8, input, decompressed)) "OK" else "FAIL" });
    }

    {
        const cfg = try archive.CompressionConfig.init(.brotli).withBrotliQuality(9);
        const compressed = try archive.compressWithConfig(allocator, input, cfg);
        defer allocator.free(compressed);
        const decompressed = try archive.decompress(allocator, compressed, .brotli);
        defer allocator.free(decompressed);
        std.debug.print("   brotli quality 9: {d} -> {d} bytes, verified: {s}\n", .{ input.len, compressed.len, if (std.mem.eql(u8, input, decompressed)) "OK" else "FAIL" });
    }

    std.debug.print("\n", .{});
}

fn errorHandlingExample(allocator: std.mem.Allocator) !void {
    std.debug.print("7. Error Handling (truncated and corrupt input are never silent)\n", .{});

    const input = "Error-handling demo payload. Error-handling demo payload.";
    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);

    // Truncated input must fail.
    const half = compressed[0 .. compressed.len / 2];
    if (archive.decompress(allocator, half, .gzip)) |ok| {
        allocator.free(ok);
        std.debug.print("   truncated gzip unexpectedly decoded (BUG)\n", .{});
    } else |err| {
        std.debug.print("   truncated gzip rejected: {s}\n", .{@errorName(err)});
    }

    // Invalid configuration is rejected before any allocation work.
    const bad = archive.CompressionConfig.init(.gzip).withThreads(4);
    if (bad.validate()) {
        std.debug.print("   invalid config unexpectedly accepted (BUG)\n", .{});
    } else |err| {
        std.debug.print("   threads=4 on gzip rejected: {s}\n\n", .{@errorName(err)});
    }
}
