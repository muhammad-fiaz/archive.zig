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
        const options = config.Options{
            .level = self.cfg.getEffectiveLevel(),
            .checksum = self.cfg.checksum,
            .zstd_level = if (self.cfg.algorithm == .zstd) self.cfg.getEffectiveZstdLevel() else null,
            .dictionary = self.cfg.dictionary,
            .window_size = self.cfg.window_size,
            .memory_level = self.cfg.memory_level,
            .strategy = self.cfg.strategy,
        };
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
        const detected = if (self.cfg.algorithm != .none) self.cfg.algorithm else detectFormat(data);
        const options = config.Options{
            .level = self.cfg.getEffectiveLevel(),
            .checksum = self.cfg.checksum,
            .zstd_level = if (detected == .zstd) self.cfg.getEffectiveZstdLevel() else null,
            .dictionary = self.cfg.dictionary,
            .window_size = self.cfg.window_size,
            .memory_level = self.cfg.memory_level,
            .strategy = self.cfg.strategy,
        };
        return switch (detected) {
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

    pub fn compressFile(self: *Archive, input_path: []const u8, output_path: ?[]const u8) !void {
        const file = try std.fs.cwd().openFile(input_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, std.math.maxInt(usize));
        defer self.allocator.free(content);

        const compressed = try self.compress(content);
        defer self.allocator.free(compressed);

        const out_path = output_path orelse blk: {
            break :blk try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ input_path, self.cfg.algorithm.extension() });
        };
        defer if (output_path == null) self.allocator.free(out_path);

        const out_file = try std.fs.cwd().createFile(out_path, .{});
        defer out_file.close();
        try out_file.writeAll(compressed);
    }

    pub fn decompressFile(self: *Archive, input_path: []const u8, output_path: ?[]const u8) !void {
        const file = try std.fs.cwd().openFile(input_path, .{});
        defer file.close();

        const content = try file.readToEndAlloc(self.allocator, std.math.maxInt(usize));
        defer self.allocator.free(content);

        const decompressed = try self.decompress(content);
        defer self.allocator.free(decompressed);

        const out_path = output_path orelse blk: {
            if (std.mem.endsWith(u8, input_path, ".gz")) {
                break :blk input_path[0 .. input_path.len - 3];
            } else if (std.mem.endsWith(u8, input_path, ".zst")) {
                break :blk input_path[0 .. input_path.len - 4];
            } else {
                break :blk try std.fmt.allocPrint(self.allocator, "{s}.decompressed", .{input_path});
            }
        };
        defer if (output_path == null and !std.mem.endsWith(u8, input_path, ".gz") and !std.mem.endsWith(u8, input_path, ".zst")) {
            self.allocator.free(out_path);
        };

        const out_file = try std.fs.cwd().createFile(out_path, .{});
        defer out_file.close();
        try out_file.writeAll(decompressed);
    }
};

pub fn detectFormat(data: []const u8) Algorithm {
    if (data.len < 4) return .none;

    if (std.mem.startsWith(u8, data, &constants.Magic.gzip)) return .gzip;
    if (std.mem.startsWith(u8, data, &constants.Magic.zlib)) return .zlib;
    if (std.mem.startsWith(u8, data, &constants.Magic.xz)) return .xz;
    if (data.len >= 4 and std.mem.readInt(u32, data[0..4], .little) == constants.Magic.zip_local) return .zip;

    const zstd_magic = [4]u8{ 0x28, 0xB5, 0x2F, 0xFD };
    if (std.mem.startsWith(u8, data, &zstd_magic)) return .zstd;

    const lz4_magic = [4]u8{ 0x04, 0x22, 0x4D, 0x18 };
    if (std.mem.startsWith(u8, data, &lz4_magic)) return .lz4;

    if (data.len >= 13 and data[0] == 0x5D) {
        const dict = std.mem.readInt(u32, data[1..5], .little);
        if (dict != 0 and (dict & (dict - 1)) == 0) return .lzma;
    }

    return .deflate;
}

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

pub fn detectAlgorithm(data: []const u8) ?Algorithm {
    const detected = detectFormat(data);
    return if (detected == .none) null else detected;
}

pub fn autoDecompress(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const detected = detectFormat(data);
    return decompress(allocator, data, detected);
}

pub const Compressor = struct {
    allocator: std.mem.Allocator,
    algorithm: Algorithm,
    level: ?u8 = null,
    zstd_level: ?c_int = null,
    checksum: bool = false,

    pub fn init(allocator: std.mem.Allocator, algorithm: Algorithm) Compressor {
        return .{ .allocator = allocator, .algorithm = algorithm };
    }

    pub fn withLevel(self: Compressor, level: u8) Compressor {
        var result = self;
        result.level = level;
        return result;
    }

    pub fn withZstdLevel(self: Compressor, level: c_int) Compressor {
        var result = self;
        result.zstd_level = level;
        return result;
    }

    pub fn withChecksum(self: Compressor) Compressor {
        var result = self;
        result.checksum = true;
        return result;
    }

    pub fn compress_data(self: Compressor, data: []const u8) ![]u8 {
        var cfg = CompressionConfig.init(self.algorithm);
        if (self.level) |l| {
            cfg = cfg.withCustomLevel(l);
        }
        if (self.zstd_level) |l| {
            cfg = cfg.withZstdLevel(l);
        }
        if (self.checksum) {
            cfg = cfg.withChecksum();
        }
        return compressWithConfig(self.allocator, data, cfg);
    }

    pub fn decompress_data(self: Compressor, data: []const u8) ![]u8 {
        return autoDecompress(self.allocator, data);
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
