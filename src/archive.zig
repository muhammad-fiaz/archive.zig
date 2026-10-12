const std = @import("std");

pub const config = @import("config.zig");
pub const constants = @import("constants.zig");
pub const errors = @import("errors.zig");
pub const utils = @import("utils.zig");
pub const stream = @import("stream.zig");

pub const algorithms = struct {
    pub const deflate = @import("algorithms/deflate.zig");
    pub const gzip = @import("algorithms/gzip.zig");
    pub const lz4 = @import("algorithms/lz4.zig");
    pub const lzma = @import("algorithms/lzma.zig");
    pub const tar_gz = @import("algorithms/tar_gz.zig");
    pub const xz = @import("algorithms/xz.zig");
    pub const zip = @import("algorithms/zip.zig");
    pub const zlib = @import("algorithms/zlib.zig");
    pub const zstd = @import("algorithms/zstd.zig");
    pub const brotli = @import("algorithms/brotli.zig");
};

pub const CompressionConfig = config.CompressionConfig;
pub const Algorithm = config.Algorithm;
pub const Level = config.Level;
pub const CompressError = errors.CompressError;

/// Library release version. Keep in sync with `build.zig.zon`.
pub const version = "0.0.3";
/// Minimum supported Zig compiler version.
pub const minimum_zig_version = "0.17.0";

/// Short human-readable description of the unified one-shot API ownership:
/// every `compress`/`decompress` variant returns an owned slice that the
/// caller must free with the same allocator. Inputs are always borrowed.
pub const ownership_note = "Caller owns returned slices; inputs are borrowed.";

pub const Archive = struct {
    allocator: std.mem.Allocator,
    cfg: config.CompressionConfig,

    pub fn init(allocator: std.mem.Allocator, cfg: config.CompressionConfig) Archive {
        return .{
            .allocator = allocator,
            .cfg = cfg,
        };
    }

    pub fn deinit(self: *Archive) void {
        _ = self;
    }

    pub fn compress(self: *Archive, data: []const u8) ![]u8 {
        try self.cfg.validate();
        const options = config.Options.fromConfig(self.cfg);
        try options.validate(self.cfg.algorithm);
        return switch (self.cfg.algorithm) {
            .none => self.allocator.dupe(u8, data),
            .deflate => algorithms.deflate.compress(self.allocator, data, options),
            .gzip => algorithms.gzip.compress(self.allocator, data, options),
            .zlib => algorithms.zlib.compress(self.allocator, data, options),
            .lz4 => algorithms.lz4.compress(self.allocator, data, options),
            .lzma => algorithms.lzma.compress(self.allocator, data, options),
            .xz => algorithms.xz.compress(self.allocator, data, options),
            .tar_gz => algorithms.tar_gz.compress(self.allocator, data, options),
            .zip => algorithms.zip.compress(self.allocator, data, options),
            .zstd => algorithms.zstd.compress(self.allocator, data, options),
            .raw_deflate => algorithms.deflate.compress(self.allocator, data, options),
            .lzma2 => algorithms.lzma.compress(self.allocator, data, options),
            .brotli => algorithms.brotli.compress(self.allocator, data, options),
        };
    }

    pub fn decompress(self: *Archive, data: []const u8) ![]u8 {
        try self.cfg.validate();
        const options = config.Options.fromConfig(self.cfg);
        try options.validate(self.cfg.algorithm);
        return switch (self.cfg.algorithm) {
            .none => self.allocator.dupe(u8, data),
            .deflate => algorithms.deflate.decompress(self.allocator, data, options),
            .gzip => algorithms.gzip.decompress(self.allocator, data, options),
            .zlib => algorithms.zlib.decompress(self.allocator, data, options),
            .lz4 => algorithms.lz4.decompress(self.allocator, data, options),
            .lzma => algorithms.lzma.decompress(self.allocator, data, options),
            .xz => algorithms.xz.decompress(self.allocator, data, options),
            .tar_gz => algorithms.tar_gz.decompress(self.allocator, data, options),
            .zip => algorithms.zip.decompress(self.allocator, data, options),
            .zstd => algorithms.zstd.decompress(self.allocator, data, options),
            .raw_deflate => algorithms.deflate.decompress(self.allocator, data, options),
            .lzma2 => algorithms.lzma.decompress(self.allocator, data, options),
            .brotli => algorithms.brotli.decompress(self.allocator, data, options),
        };
    }
};

pub fn compress(allocator: std.mem.Allocator, data: []const u8, algorithm: Algorithm) ![]u8 {
    var archive = Archive.init(allocator, CompressionConfig.init(algorithm));
    defer archive.deinit();
    return archive.compress(data);
}

pub fn decompress(allocator: std.mem.Allocator, data: []const u8, algorithm: Algorithm) ![]u8 {
    var archive = Archive.init(allocator, CompressionConfig.init(algorithm));
    defer archive.deinit();
    return archive.decompress(data);
}

pub fn compressWithConfig(allocator: std.mem.Allocator, data: []const u8, cfg: config.CompressionConfig) ![]u8 {
    var archive = Archive.init(allocator, cfg);
    defer archive.deinit();
    return archive.compress(data);
}

pub fn decompressWithConfig(allocator: std.mem.Allocator, data: []const u8, cfg: config.CompressionConfig) ![]u8 {
    var archive = Archive.init(allocator, cfg);
    defer archive.deinit();
    return archive.decompress(data);
}

pub const Compressor = struct {
    allocator: std.mem.Allocator,
    algorithm: Algorithm,
    level: ?u8 = null,
    zstd_level: ?i32 = null,
    lz4_level: ?i32 = null,
    checksum: bool = false,

    pub fn init(allocator: std.mem.Allocator, algorithm: Algorithm) Compressor {
        return .{ .allocator = allocator, .algorithm = algorithm };
    }

    pub fn withLevel(self: Compressor, level: u8) Compressor {
        var result = self;
        result.level = level;
        return result;
    }

    pub fn withZstdLevel(self: Compressor, level: i32) Compressor {
        var result = self;
        result.zstd_level = level;
        return result;
    }

    pub fn withLz4Level(self: Compressor, level: i32) Compressor {
        var result = self;
        result.lz4_level = level;
        return result;
    }

    pub fn withChecksum(self: Compressor) Compressor {
        var result = self;
        result.checksum = true;
        return result;
    }

    fn buildConfig(self: Compressor) config.CompressionConfig {
        var cfg = CompressionConfig.init(self.algorithm);
        if (self.level) |l| cfg = cfg.withCustomLevel(l);
        if (self.zstd_level) |l| cfg = cfg.withZstdLevel(l);
        if (self.lz4_level) |l| cfg = cfg.withLz4Level(l);
        if (self.checksum) cfg = cfg.withChecksum();
        return cfg;
    }

    pub fn compress_data(self: Compressor, data: []const u8) ![]u8 {
        return compressWithConfig(self.allocator, data, self.buildConfig());
    }

    pub fn decompress_data(self: Compressor, data: []const u8) ![]u8 {
        return decompressWithConfig(self.allocator, data, self.buildConfig());
    }
};

test "archive basic functionality" {
    const testing = std.testing;
    var archive = Archive.init(testing.allocator, CompressionConfig.init(.deflate).withLevel(.default));
    defer archive.deinit();

    const data = "Hello, World! This is a test string for compression.";
    const compressed = try archive.compress(data);
    defer testing.allocator.free(compressed);

    const decompressed = try archive.decompress(compressed);
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}

test "unified roundtrip all enabled algorithms" {
    const testing = std.testing;
    const algos = [_]Algorithm{ .gzip, .zlib, .deflate, .raw_deflate, .lz4, .lzma, .xz, .tar_gz, .zip, .zstd, .brotli };
    const input = "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs! 0123456789";

    for (algos) |algo| {
        const compressed = try compress(testing.allocator, input, algo);
        defer testing.allocator.free(compressed);
        const decompressed = try decompress(testing.allocator, compressed, algo);
        defer testing.allocator.free(decompressed);
        try testing.expectEqualStrings(input, decompressed);
    }
}

test "unified roundtrip aliases none and lzma2" {
    const testing = std.testing;
    const input = "Alias coverage: none passes through, lzma2 maps to lzma.";

    for ([_]Algorithm{ .none, .lzma2 }) |algo| {
        const compressed = try compress(testing.allocator, input, algo);
        defer testing.allocator.free(compressed);
        const decompressed = try decompress(testing.allocator, compressed, algo);
        defer testing.allocator.free(decompressed);
        try testing.expectEqualStrings(input, decompressed);
    }
}

test "unified roundtrip binary with zero bytes" {
    const testing = std.testing;
    var input: [256]u8 = undefined;
    for (&input, 0..) |*b, i| b.* = @intCast(i);
    const algos = [_]Algorithm{ .gzip, .zlib, .deflate, .lz4, .lzma, .xz, .tar_gz, .zip, .zstd, .brotli };

    for (algos) |algo| {
        const compressed = try compress(testing.allocator, &input, algo);
        defer testing.allocator.free(compressed);
        const decompressed = try decompress(testing.allocator, compressed, algo);
        defer testing.allocator.free(decompressed);
        try testing.expectEqualSlices(u8, &input, decompressed);
    }
}

test "unified roundtrip large input" {
    const testing = std.testing;
    const base = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. ";
    const total = base.len * 200;
    const input = try testing.allocator.alloc(u8, total);
    defer testing.allocator.free(input);
    for (0..200) |i| @memcpy(input[i * base.len .. (i + 1) * base.len], base);

    const algos = [_]Algorithm{ .gzip, .zlib, .deflate, .lz4, .lzma, .xz, .tar_gz, .zip, .zstd, .brotli };
    for (algos) |algo| {
        const compressed = try compress(testing.allocator, input, algo);
        defer testing.allocator.free(compressed);
        const decompressed = try decompress(testing.allocator, compressed, algo);
        defer testing.allocator.free(decompressed);
        try testing.expectEqualSlices(u8, input, decompressed);
    }
}

test "unified rejects truncated and invalid input" {
    const testing = std.testing;
    const input = "truncate me: hello world hello world hello world";
    const algos = [_]Algorithm{ .gzip, .zlib, .deflate, .lz4, .zstd, .brotli };

    for (algos) |algo| {
        const compressed = try compress(testing.allocator, input, algo);
        defer testing.allocator.free(compressed);
        try testing.expect(compressed.len > 0);
        // Truncated payload must fail, never succeed silently.
        const half = compressed[0 .. compressed.len / 2];
        if (decompress(testing.allocator, half, algo)) |ok| {
            testing.allocator.free(ok);
            try testing.expect(false);
        } else |_| {}
    }

    const garbage = [_]u8{ 0xFF, 0x00, 0xAB, 0x42, 0x11, 0x77, 0x99, 0x00 };
    for (algos) |algo| {
        if (algo == .lz4) continue; // lz4 magic check covered in module tests
        const result = decompress(testing.allocator, &garbage, algo);
        try testing.expect(result == error.InvalidData or result == error.InvalidMagic or result == error.ReadFailed or result == error.CorruptedStream or result == error.ChecksumMismatch or result == error.ZstdError);
        if (result) |ok| testing.allocator.free(ok) else |_| {}
    }
}

test "unified rejects invalid configuration" {
    const testing = std.testing;
    // Threads > 1 are only supported by zstd.
    const bad_threads = CompressionConfig.init(.gzip).withThreads(4);
    try testing.expectError(error.UnsupportedAlgorithm, bad_threads.validate());
    // Zero buffer size is rejected.
    var zero_buf = CompressionConfig.init(.gzip);
    zero_buf.buffer_size = 0;
    try testing.expectError(error.InvalidData, zero_buf.validate());
    // Strict level builders reject out-of-range values.
    try testing.expectError(error.InvalidData, CompressionConfig.init(.gzip).withCheckedLevel(99));
    try testing.expectError(error.InvalidData, CompressionConfig.init(.zstd).withCheckedZstdLevel(99));
    try testing.expectError(error.InvalidData, CompressionConfig.init(.brotli).withBrotliQuality(12));
}

test "public api version exports" {
    const testing = std.testing;
    try testing.expectEqualStrings("0.0.3", version);
    try testing.expectEqualStrings("0.17.0", minimum_zig_version);
    try testing.expectEqualStrings("0.0.3", constants.library_version);
    try testing.expectEqualStrings("0.0.4", constants.DependencyVersions.zstd);
    try testing.expectEqualStrings("0.0.4", constants.DependencyVersions.brotli);
}
