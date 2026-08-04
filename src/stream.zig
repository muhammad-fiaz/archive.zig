const std = @import("std");
const config = @import("config.zig");

fn dispatchCompress(allocator: std.mem.Allocator, algorithm: config.Algorithm, options: config.Options, data: []const u8) ![]u8 {
    const algorithms = @import("archive.zig").algorithms;
    return switch (algorithm) {
        .none => allocator.dupe(u8, data),
        .deflate => algorithms.deflate.compress(allocator, data, options),
        .gzip => algorithms.gzip.compress(allocator, data, options),
        .zlib => algorithms.zlib.compress(allocator, data, options),
        .lz4 => algorithms.lz4.compress(allocator, data, options),
        .lzma => algorithms.lzma.compress(allocator, data, options),
        .xz => algorithms.xz.compress(allocator, data, options),
        .tar_gz => algorithms.tar_gz.compress(allocator, data, options),
        .zip => algorithms.zip.compress(allocator, data, options),
        .zstd => algorithms.zstd.compress(allocator, data, options),
        .raw_deflate => algorithms.deflate.compress(allocator, data, options),
        .lzma2 => algorithms.lzma.compress(allocator, data, options),
        .brotli => algorithms.brotli.compress(allocator, data, options),
    };
}

fn dispatchDecompress(allocator: std.mem.Allocator, algorithm: config.Algorithm, options: config.Options, data: []const u8) ![]u8 {
    const algorithms = @import("archive.zig").algorithms;
    return switch (algorithm) {
        .none => allocator.dupe(u8, data),
        .deflate => algorithms.deflate.decompress(allocator, data, options),
        .gzip => algorithms.gzip.decompress(allocator, data, options),
        .zlib => algorithms.zlib.decompress(allocator, data, options),
        .lz4 => algorithms.lz4.decompress(allocator, data, options),
        .lzma => algorithms.lzma.decompress(allocator, data, options),
        .xz => algorithms.xz.decompress(allocator, data, options),
        .tar_gz => algorithms.tar_gz.decompress(allocator, data, options),
        .zip => algorithms.zip.decompress(allocator, data, options),
        .zstd => algorithms.zstd.decompress(allocator, data, options),
        .raw_deflate => algorithms.deflate.decompress(allocator, data, options),
        .lzma2 => algorithms.lzma.decompress(allocator, data, options),
        .brotli => algorithms.brotli.decompress(allocator, data, options),
    };
}

pub const CompressStream = struct {
    allocator: std.mem.Allocator,
    algorithm: config.Algorithm,
    level: config.Level,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, algorithm: config.Algorithm, level: config.Level) !CompressStream {
        return CompressStream{
            .allocator = allocator,
            .algorithm = algorithm,
            .level = level,
            .buffer = .empty,
        };
    }

    pub fn deinit(self: *CompressStream) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn write(self: *CompressStream, data: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, data);
    }

    pub fn finish(self: *CompressStream) ![]u8 {
        return dispatchCompress(self.allocator, self.algorithm, config.Options{ .level = self.level.toInt() }, self.buffer.items);
    }
};

pub const DecompressStream = struct {
    allocator: std.mem.Allocator,
    algorithm: config.Algorithm,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, algorithm: config.Algorithm) DecompressStream {
        return DecompressStream{
            .allocator = allocator,
            .algorithm = algorithm,
            .buffer = .empty,
        };
    }

    pub fn deinit(self: *DecompressStream) void {
        self.buffer.deinit(self.allocator);
    }

    pub fn write(self: *DecompressStream, data: []const u8) !void {
        try self.buffer.appendSlice(self.allocator, data);
    }

    pub fn finish(self: *DecompressStream) ![]u8 {
        return dispatchDecompress(self.allocator, self.algorithm, config.Options{}, self.buffer.items);
    }
};

test "compress stream" {
    const testing = std.testing;

    var stream = try CompressStream.init(testing.allocator, .deflate, .default);
    defer stream.deinit();

    try stream.write("Hello, ");
    try stream.write("World!");

    const compressed = try stream.finish();
    defer testing.allocator.free(compressed);

    try testing.expect(compressed.len > 0);
}

test "decompress stream" {
    const testing = std.testing;

    var compress_stream = try CompressStream.init(testing.allocator, .deflate, .default);
    defer compress_stream.deinit();

    const original = "Hello, World!";
    try compress_stream.write(original);

    const compressed = try compress_stream.finish();
    defer testing.allocator.free(compressed);

    var decompress_stream = DecompressStream.init(testing.allocator, .deflate);
    defer decompress_stream.deinit();

    try decompress_stream.write(compressed);

    const decompressed = try decompress_stream.finish();
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(original, decompressed);
}
