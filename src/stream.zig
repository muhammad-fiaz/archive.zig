const std = @import("std");
const config = @import("config.zig");
const errors = @import("errors.zig");

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
        const algorithms = @import("archive.zig").algorithms;
        const options = config.Options{ .level = self.level.toInt() };

        return switch (self.algorithm) {
            .none => self.allocator.dupe(u8, self.buffer.items),
            .deflate => algorithms.deflate.compress(self.allocator, self.buffer.items, options),
            .gzip => algorithms.gzip.compress(self.allocator, self.buffer.items, options),
            .zlib => algorithms.zlib.compress(self.allocator, self.buffer.items, options),
            .lz4 => algorithms.lz4.compress(self.allocator, self.buffer.items, options),
            .lzma => algorithms.lzma.compress(self.allocator, self.buffer.items, options),
            .xz => algorithms.xz.compress(self.allocator, self.buffer.items, options),
            .tar_gz => algorithms.tar_gz.compress(self.allocator, self.buffer.items, options),
            .zip => algorithms.zip.compress(self.allocator, self.buffer.items, options),
            .zstd => algorithms.zstd.compress(self.allocator, self.buffer.items, options),
            .raw_deflate => algorithms.deflate.compress(self.allocator, self.buffer.items, options),
            .lzma2 => algorithms.lzma.compress(self.allocator, self.buffer.items, options),
            .brotli => algorithms.brotli.compress(self.allocator, self.buffer.items, options),
        };
    }
};

pub const DecompressStream = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) DecompressStream {
        return DecompressStream{
            .allocator = allocator,
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
        const archive = @import("archive.zig");
        const detected = archive.detectFormat(self.buffer.items);
        const algorithms = archive.algorithms;
        const options = config.Options{};

        return switch (detected) {
            .none => self.allocator.dupe(u8, self.buffer.items),
            .deflate => algorithms.deflate.decompress(self.allocator, self.buffer.items, options),
            .gzip => algorithms.gzip.decompress(self.allocator, self.buffer.items, options),
            .zlib => algorithms.zlib.decompress(self.allocator, self.buffer.items, options),
            .lz4 => algorithms.lz4.decompress(self.allocator, self.buffer.items, options),
            .lzma => algorithms.lzma.decompress(self.allocator, self.buffer.items, options),
            .xz => algorithms.xz.decompress(self.allocator, self.buffer.items, options),
            .tar_gz => algorithms.tar_gz.decompress(self.allocator, self.buffer.items, options),
            .zip => algorithms.zip.decompress(self.allocator, self.buffer.items, options),
            .zstd => algorithms.zstd.decompress(self.allocator, self.buffer.items, options),
            .raw_deflate => algorithms.deflate.decompress(self.allocator, self.buffer.items, options),
            .lzma2 => algorithms.lzma.decompress(self.allocator, self.buffer.items, options),
            .brotli => algorithms.brotli.decompress(self.allocator, self.buffer.items, options),
        };
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

    var decompress_stream = DecompressStream.init(testing.allocator);
    defer decompress_stream.deinit();

    try decompress_stream.write(compressed);

    const decompressed = try decompress_stream.finish();
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(original, decompressed);
}
