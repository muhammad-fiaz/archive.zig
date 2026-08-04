const std = @import("std");
const Constants = @import("constants.zig");
const utils = @import("utils.zig");

pub const Algorithm = enum {
    none,
    deflate,
    zlib,
    raw_deflate,
    gzip,
    zstd,
    lzma,
    lzma2,
    xz,
    tar_gz,
    zip,
    lz4,
    brotli,

    pub fn extension(self: Algorithm) []const u8 {
        return switch (self) {
            .none => Constants.Extensions.none,
            .deflate => Constants.Extensions.deflate,
            .zlib => Constants.Extensions.zlib_ext,
            .raw_deflate => Constants.Extensions.deflate,
            .gzip => Constants.Extensions.gzip,
            .zstd => Constants.Extensions.zstd,
            .lzma => Constants.Extensions.lzma,
            .lzma2 => Constants.Extensions.lzma2,
            .xz => Constants.Extensions.xz,
            .tar_gz => Constants.Extensions.tar_gz,
            .zip => Constants.Extensions.zip,
            .lz4 => Constants.Extensions.lz4,
            .brotli => Constants.Extensions.brotli,
        };
    }

    pub fn supportsDirectory(self: Algorithm) bool {
        return switch (self) {
            .tar_gz, .zip => true,
            else => false,
        };
    }

    pub fn getDefaultLevel(self: Algorithm) u8 {
        return switch (self) {
            .none => 0,
            .deflate, .zlib, .raw_deflate, .gzip => 6,
            .zstd => 3,
            .lzma, .lzma2, .xz => 6,
            .tar_gz => 6,
            .zip => 6,
            .lz4 => 1,
            .brotli => 6,
        };
    }

    pub fn getMaxLevel(self: Algorithm) u8 {
        return switch (self) {
            .none => 0,
            .deflate, .zlib, .raw_deflate, .gzip => 9,
            .zstd => 22,
            .lzma, .lzma2, .xz => 9,
            .tar_gz => 9,
            .zip => 9,
            .lz4 => 12,
            .brotli => 11,
        };
    }

    pub fn getMinLevel(self: Algorithm) u8 {
        return switch (self) {
            .none => 0,
            .zstd => 1,
            else => 1,
        };
    }
};

pub const Level = enum {
    none,
    fastest,
    fast,
    default,
    best,
    ultra,

    pub fn toInt(self: Level) u8 {
        return switch (self) {
            .none => 0,
            .fastest => 1,
            .fast => 3,
            .default => 6,
            .best => 9,
            .ultra => 12,
        };
    }

    pub fn toZstdLevel(self: Level) c_int {
        return switch (self) {
            .none => 0,
            .fastest => 1,
            .fast => 3,
            .default => 10,
            .best => 19,
            .ultra => 22,
        };
    }

    pub fn toLz4Level(self: Level) c_int {
        return switch (self) {
            .none => 0,
            .fastest => 1,
            .fast => 3,
            .default => 6,
            .best => 9,
            .ultra => 12,
        };
    }
};

pub const Strategy = enum {
    default,
    filtered,
    huffman_only,
    rle,
    fixed,
    fast,
    dfast,
    greedy,
    lazy,
    lazy2,
    btlazy2,
    btopt,
    btultra,
    btultra2,
};

pub const CompressionMode = enum {
    compress,
    decompress,
    both,
};

pub const FlushMode = enum {
    none,
    sync,
    full,
    finish,
    block,
};

pub const FilterRule = struct {
    pattern: []const u8,
    is_directory: bool = false,
    is_recursive: bool = true,
    case_sensitive: bool = false,
    negate: bool = false,
};

pub const PathFilter = struct {
    include_rules: []const FilterRule = &[_]FilterRule{},
    exclude_rules: []const FilterRule = &[_]FilterRule{},
    default_action: bool = true,

    pub fn shouldInclude(self: PathFilter, path: []const u8, is_directory: bool) bool {
        for (self.exclude_rules) |rule| {
            if (rule.is_directory != is_directory and rule.is_directory) continue;
            if (matchesPattern(path, rule.pattern, rule.case_sensitive)) {
                return if (rule.negate) true else false;
            }
        }

        if (self.include_rules.len == 0) return self.default_action;

        for (self.include_rules) |rule| {
            if (rule.is_directory != is_directory and rule.is_directory) continue;
            if (matchesPattern(path, rule.pattern, rule.case_sensitive)) {
                return if (rule.negate) false else true;
            }
        }

        return false;
    }

    fn matchesPattern(path: []const u8, pattern: []const u8, case_sensitive: bool) bool {
        return utils.matchGlobWithCase(path, pattern, case_sensitive);
    }
};

pub const CompressionConfig = struct {
    algorithm: Algorithm = .none,
    level: Level = .default,
    custom_level: ?u8 = null,
    zstd_level: ?c_int = null,
    lz4_level: ?c_int = null,
    extension: []const u8 = "",
    mode: CompressionMode = .compress,

    checksum: bool = false,
    verify_checksum: bool = true,
    keep_original: bool = false,
    overwrite_existing: bool = false,
    create_directories: bool = true,

    path_filter: PathFilter = .{},
    recursive: bool = true,
    follow_symlinks: bool = false,
    max_depth: ?u32 = null,
    min_file_size: u64 = 0,
    max_file_size: ?u64 = null,

    buffer_size: usize = Constants.BufferSizes.compression,
    read_buffer_size: usize = Constants.BufferSizes.compression,
    write_buffer_size: usize = Constants.BufferSizes.compression,

    memory_level: ?u8 = null,
    window_size: ?usize = null,
    window_log: ?u8 = null,
    hash_log: ?u8 = null,
    chain_log: ?u8 = null,
    search_log: ?u8 = null,
    min_match: ?u8 = null,
    target_length: ?u32 = null,

    strategy: Strategy = .default,
    flush_mode: FlushMode = .sync,

    dictionary: ?[]const u8 = null,
    dictionary_id: ?u32 = null,

    threads: u32 = 1,
    job_size: ?usize = null,
    overlap_log: ?u8 = null,

    content_size_flag: bool = true,
    dict_id_flag: bool = true,

    enable_ldm: bool = false,
    ldm_hash_log: ?u8 = null,
    ldm_min_match: ?u8 = null,
    ldm_bucket_size_log: ?u8 = null,
    ldm_hash_rate_log: ?u8 = null,

    format_version: u8 = 1,
    magic_bytes: bool = true,

    progress_callback: ?*const fn (u64, u64) void = null,
    user_data: ?*anyopaque = null,

    pub fn init(algorithm: Algorithm) CompressionConfig {
        return .{
            .algorithm = algorithm,
            .extension = algorithm.extension(),
            .level = .default,
            .custom_level = algorithm.getDefaultLevel(),
        };
    }

    pub fn withLevel(self: CompressionConfig, level: Level) CompressionConfig {
        var cfg = self;
        cfg.level = level;
        cfg.custom_level = null;
        return cfg;
    }

    pub fn withCustomLevel(self: CompressionConfig, level: u8) CompressionConfig {
        var cfg = self;
        const max_level = cfg.algorithm.getMaxLevel();
        const min_level = cfg.algorithm.getMinLevel();
        cfg.custom_level = std.math.clamp(level, min_level, max_level);
        return cfg;
    }

    pub fn withZstdLevel(self: CompressionConfig, level: c_int) CompressionConfig {
        var cfg = self;
        cfg.zstd_level = std.math.clamp(level, Constants.ZstdConstants.min_level, Constants.ZstdConstants.max_level);
        return cfg;
    }

    pub fn withLz4Level(self: CompressionConfig, level: c_int) CompressionConfig {
        var cfg = self;
        cfg.lz4_level = std.math.clamp(level, 1, 12);
        return cfg;
    }

    pub fn withMode(self: CompressionConfig, mode: CompressionMode) CompressionConfig {
        var cfg = self;
        cfg.mode = mode;
        return cfg;
    }

    pub fn withChecksum(self: CompressionConfig) CompressionConfig {
        var cfg = self;
        cfg.checksum = true;
        return cfg;
    }

    pub fn withVerifyChecksum(self: CompressionConfig, verify: bool) CompressionConfig {
        var cfg = self;
        cfg.verify_checksum = verify;
        return cfg;
    }

    pub fn withKeepOriginal(self: CompressionConfig) CompressionConfig {
        var cfg = self;
        cfg.keep_original = true;
        return cfg;
    }

    pub fn withOverwriteExisting(self: CompressionConfig) CompressionConfig {
        var cfg = self;
        cfg.overwrite_existing = true;
        return cfg;
    }

    pub fn withCreateDirectories(self: CompressionConfig, create: bool) CompressionConfig {
        var cfg = self;
        cfg.create_directories = create;
        return cfg;
    }

    pub fn withRecursive(self: CompressionConfig, recursive: bool) CompressionConfig {
        var cfg = self;
        cfg.recursive = recursive;
        return cfg;
    }

    pub fn withFollowSymlinks(self: CompressionConfig) CompressionConfig {
        var cfg = self;
        cfg.follow_symlinks = true;
        return cfg;
    }

    pub fn withMaxDepth(self: CompressionConfig, depth: u32) CompressionConfig {
        var cfg = self;
        cfg.max_depth = depth;
        return cfg;
    }

    pub fn withSizeRange(self: CompressionConfig, min_size: u64, max_size: ?u64) CompressionConfig {
        var cfg = self;
        cfg.min_file_size = min_size;
        cfg.max_file_size = max_size;
        return cfg;
    }

    pub fn withBufferSize(self: CompressionConfig, size: usize) CompressionConfig {
        var cfg = self;
        cfg.buffer_size = size;
        cfg.read_buffer_size = size;
        cfg.write_buffer_size = size;
        return cfg;
    }

    pub fn withReadBufferSize(self: CompressionConfig, size: usize) CompressionConfig {
        var cfg = self;
        cfg.read_buffer_size = size;
        return cfg;
    }

    pub fn withWriteBufferSize(self: CompressionConfig, size: usize) CompressionConfig {
        var cfg = self;
        cfg.write_buffer_size = size;
        return cfg;
    }

    pub fn withMemoryLevel(self: CompressionConfig, level: u8) CompressionConfig {
        var cfg = self;
        cfg.memory_level = std.math.clamp(level, 1, 9);
        return cfg;
    }

    pub fn withWindowSize(self: CompressionConfig, size: usize) CompressionConfig {
        var cfg = self;
        cfg.window_size = size;
        return cfg;
    }

    pub fn withWindowLog(self: CompressionConfig, log: u8) CompressionConfig {
        var cfg = self;
        cfg.window_log = std.math.clamp(log, 10, 31);
        return cfg;
    }

    pub fn withHashLog(self: CompressionConfig, log: u8) CompressionConfig {
        var cfg = self;
        cfg.hash_log = std.math.clamp(log, 6, 26);
        return cfg;
    }

    pub fn withChainLog(self: CompressionConfig, log: u8) CompressionConfig {
        var cfg = self;
        cfg.chain_log = std.math.clamp(log, 6, 28);
        return cfg;
    }

    pub fn withSearchLog(self: CompressionConfig, log: u8) CompressionConfig {
        var cfg = self;
        cfg.search_log = std.math.clamp(log, 1, 26);
        return cfg;
    }

    pub fn withMinMatch(self: CompressionConfig, min_match: u8) CompressionConfig {
        var cfg = self;
        cfg.min_match = std.math.clamp(min_match, 3, 7);
        return cfg;
    }

    pub fn withTargetLength(self: CompressionConfig, length: u32) CompressionConfig {
        var cfg = self;
        cfg.target_length = length;
        return cfg;
    }

    pub fn withStrategy(self: CompressionConfig, strategy: Strategy) CompressionConfig {
        var cfg = self;
        cfg.strategy = strategy;
        return cfg;
    }

    pub fn withFlushMode(self: CompressionConfig, mode: FlushMode) CompressionConfig {
        var cfg = self;
        cfg.flush_mode = mode;
        return cfg;
    }

    pub fn withDictionary(self: CompressionConfig, dict: []const u8) CompressionConfig {
        var cfg = self;
        cfg.dictionary = dict;
        return cfg;
    }

    pub fn withDictionaryId(self: CompressionConfig, id: u32) CompressionConfig {
        var cfg = self;
        cfg.dictionary_id = id;
        return cfg;
    }

    pub fn withThreads(self: CompressionConfig, threads: u32) CompressionConfig {
        var cfg = self;
        cfg.threads = std.math.clamp(threads, 1, 128);
        return cfg;
    }

    pub fn withJobSize(self: CompressionConfig, size: usize) CompressionConfig {
        var cfg = self;
        cfg.job_size = size;
        return cfg;
    }

    pub fn withOverlapLog(self: CompressionConfig, log: u8) CompressionConfig {
        var cfg = self;
        cfg.overlap_log = std.math.clamp(log, 0, 9);
        return cfg;
    }

    pub fn withContentSizeFlag(self: CompressionConfig, flag: bool) CompressionConfig {
        var cfg = self;
        cfg.content_size_flag = flag;
        return cfg;
    }

    pub fn withDictIdFlag(self: CompressionConfig, flag: bool) CompressionConfig {
        var cfg = self;
        cfg.dict_id_flag = flag;
        return cfg;
    }

    pub fn withLongDistanceMatching(self: CompressionConfig) CompressionConfig {
        var cfg = self;
        cfg.enable_ldm = true;
        return cfg;
    }

    pub fn withLdmHashLog(self: CompressionConfig, log: u8) CompressionConfig {
        var cfg = self;
        cfg.ldm_hash_log = std.math.clamp(log, 6, 26);
        return cfg;
    }

    pub fn withLdmMinMatch(self: CompressionConfig, min_match: u8) CompressionConfig {
        var cfg = self;
        cfg.ldm_min_match = std.math.clamp(min_match, 4, 4096);
        return cfg;
    }

    pub fn withLdmBucketSizeLog(self: CompressionConfig, log: u8) CompressionConfig {
        var cfg = self;
        cfg.ldm_bucket_size_log = std.math.clamp(log, 1, 8);
        return cfg;
    }

    pub fn withLdmHashRateLog(self: CompressionConfig, log: u8) CompressionConfig {
        var cfg = self;
        cfg.ldm_hash_rate_log = log;
        return cfg;
    }

    pub fn withFormatVersion(self: CompressionConfig, version: u8) CompressionConfig {
        var cfg = self;
        cfg.format_version = version;
        return cfg;
    }

    pub fn withMagicBytes(self: CompressionConfig, magic: bool) CompressionConfig {
        var cfg = self;
        cfg.magic_bytes = magic;
        return cfg;
    }

    pub fn withProgressCallback(self: CompressionConfig, callback: *const fn (u64, u64) void) CompressionConfig {
        var cfg = self;
        cfg.progress_callback = callback;
        return cfg;
    }

    pub fn withUserData(self: CompressionConfig, data: *anyopaque) CompressionConfig {
        var cfg = self;
        cfg.user_data = data;
        return cfg;
    }

    pub fn withPathFilter(self: CompressionConfig, filter: PathFilter) CompressionConfig {
        var cfg = self;
        cfg.path_filter = filter;
        return cfg;
    }

    pub fn includeFiles(self: CompressionConfig, allocator: std.mem.Allocator, patterns: []const []const u8) !CompressionConfig {
        var cfg = self;
        var rules: std.ArrayList(FilterRule) = .empty;
        defer rules.deinit(allocator);
        for (patterns) |pattern| {
            try rules.append(allocator, .{ .pattern = pattern, .is_directory = false });
        }
        var new_filter = cfg.path_filter;
        new_filter.include_rules = try rules.toOwnedSlice(allocator);
        cfg.path_filter = new_filter;
        return cfg;
    }

    pub fn includeDirectories(self: CompressionConfig, allocator: std.mem.Allocator, patterns: []const []const u8, recursive: bool) !CompressionConfig {
        var cfg = self;
        var rules: std.ArrayList(FilterRule) = .empty;
        defer rules.deinit(allocator);
        for (patterns) |pattern| {
            try rules.append(allocator, .{ .pattern = pattern, .is_directory = true, .is_recursive = recursive });
        }
        var new_filter = cfg.path_filter;
        new_filter.include_rules = try rules.toOwnedSlice(allocator);
        cfg.path_filter = new_filter;
        return cfg;
    }

    pub fn excludeFiles(self: CompressionConfig, allocator: std.mem.Allocator, patterns: []const []const u8) !CompressionConfig {
        var cfg = self;
        var rules: std.ArrayList(FilterRule) = .empty;
        defer rules.deinit(allocator);
        for (patterns) |pattern| {
            try rules.append(allocator, .{ .pattern = pattern, .is_directory = false });
        }
        var new_filter = cfg.path_filter;
        new_filter.exclude_rules = try rules.toOwnedSlice(allocator);
        cfg.path_filter = new_filter;
        return cfg;
    }

    pub fn excludeDirectories(self: CompressionConfig, allocator: std.mem.Allocator, patterns: []const []const u8, recursive: bool) !CompressionConfig {
        var cfg = self;
        var rules: std.ArrayList(FilterRule) = .empty;
        defer rules.deinit(allocator);
        for (patterns) |pattern| {
            try rules.append(allocator, .{ .pattern = pattern, .is_directory = true, .is_recursive = recursive });
        }
        var new_filter = cfg.path_filter;
        new_filter.exclude_rules = try rules.toOwnedSlice(allocator);
        cfg.path_filter = new_filter;
        return cfg;
    }

    pub fn getEffectiveLevel(self: CompressionConfig) u8 {
        if (self.custom_level) |l| return l;
        return self.level.toInt();
    }

    pub fn getEffectiveZstdLevel(self: CompressionConfig) c_int {
        if (self.zstd_level) |l| return l;
        if (self.custom_level) |l| return @intCast(l);
        return self.level.toZstdLevel();
    }

    pub fn getEffectiveLz4Level(self: CompressionConfig) c_int {
        if (self.lz4_level) |l| return l;
        if (self.custom_level) |l| return @intCast(l);
        return self.level.toLz4Level();
    }

    pub fn shouldIncludePath(self: CompressionConfig, path: []const u8, is_directory: bool) bool {
        return self.path_filter.shouldInclude(path, is_directory);
    }

    pub fn isValidForAlgorithm(self: CompressionConfig) bool {
        const max_level = self.algorithm.getMaxLevel();
        const min_level = self.algorithm.getMinLevel();

        if (self.custom_level) |level| {
            if (level < min_level or level > max_level) return false;
        }

        if (self.algorithm == .zstd and self.zstd_level != null) {
            const level = self.zstd_level.?;
            if (level < Constants.ZstdConstants.min_level or level > Constants.ZstdConstants.max_level) return false;
        }

        if (self.algorithm == .lz4 and self.lz4_level != null) {
            const level = self.lz4_level.?;
            if (level < 1 or level > 12) return false;
        }

        return true;
    }

    pub fn optimize(self: CompressionConfig) CompressionConfig {
        var cfg = self;

        if (cfg.algorithm == .zstd and cfg.threads > 1) {
            if (cfg.job_size == null) {
                cfg.job_size = cfg.buffer_size * 4;
            }
            if (cfg.overlap_log == null) {
                cfg.overlap_log = 6;
            }
        }

        if (cfg.algorithm == .lz4 and cfg.memory_level == null) {
            cfg.memory_level = 1;
        }

        if (cfg.window_size == null and cfg.window_log != null) {
            cfg.window_size = @as(usize, 1) << @intCast(cfg.window_log.?);
        }

        return cfg;
    }
};

pub const Options = struct {
    level: ?u8 = null,
    checksum: bool = false,
    dictionary: ?[]const u8 = null,
    window_size: ?usize = null,
    memory_level: ?u8 = null,
    strategy: Strategy = .default,
    zstd_level: ?c_int = null,
    lz4_level: ?c_int = null,
    threads: u32 = 1,
    buffer_size: usize = Constants.BufferSizes.compression,
    flush_mode: FlushMode = .sync,

    pub fn withLevel(level: u8) Options {
        return .{ .level = level };
    }

    pub fn withZstdLevel(level: c_int) Options {
        return .{ .zstd_level = level };
    }

    pub fn withLz4Level(level: c_int) Options {
        return .{ .lz4_level = level };
    }

    pub fn withChecksum() Options {
        return .{ .checksum = true };
    }

    pub fn withDictionary(dict: []const u8) Options {
        return .{ .dictionary = dict };
    }

    pub fn withWindowSize(size: usize) Options {
        return .{ .window_size = size };
    }

    pub fn withMemoryLevel(level: u8) Options {
        return .{ .memory_level = level };
    }

    pub fn withStrategy(strategy: Strategy) Options {
        return .{ .strategy = strategy };
    }

    pub fn withThreads(threads: u32) Options {
        return .{ .threads = threads };
    }

    pub fn withBufferSize(size: usize) Options {
        return .{ .buffer_size = size };
    }

    pub fn withFlushMode(mode: FlushMode) Options {
        return .{ .flush_mode = mode };
    }

    pub fn fromConfig(cfg: CompressionConfig) Options {
        return .{
            .level = cfg.getEffectiveLevel(),
            .checksum = cfg.checksum,
            .dictionary = cfg.dictionary,
            .window_size = cfg.window_size,
            .memory_level = cfg.memory_level,
            .strategy = cfg.strategy,
            .zstd_level = if (cfg.algorithm == .zstd) cfg.getEffectiveZstdLevel() else null,
            .lz4_level = if (cfg.algorithm == .lz4) cfg.getEffectiveLz4Level() else null,
            .threads = cfg.threads,
            .buffer_size = cfg.buffer_size,
            .flush_mode = cfg.flush_mode,
        };
    }
};

pub const StreamingOptions = struct {
    buffer_size: usize = Constants.BufferSizes.streaming,
    flush_mode: FlushMode = .sync,
    auto_flush: bool = false,
    sync_flush: bool = false,

    pub fn withBufferSize(size: usize) StreamingOptions {
        return .{ .buffer_size = size };
    }

    pub fn withFlushMode(mode: FlushMode) StreamingOptions {
        return .{ .flush_mode = mode };
    }

    pub fn withAutoFlush() StreamingOptions {
        return .{ .auto_flush = true };
    }

    pub fn withSyncFlush() StreamingOptions {
        return .{ .sync_flush = true };
    }
};

test "config creation and customization" {
    const testing = std.testing;

    var config = CompressionConfig.init(.zstd)
        .withZstdLevel(15)
        .withChecksum()
        .withRecursive(true)
        .withThreads(4);

    try testing.expect(config.algorithm == .zstd);
    try testing.expect(config.getEffectiveZstdLevel() == 15);
    try testing.expect(config.checksum == true);
    try testing.expect(config.recursive == true);
    try testing.expect(config.threads == 4);
}

test "zstd level clamping" {
    const testing = std.testing;

    var config1 = CompressionConfig.init(.zstd).withZstdLevel(25);
    try testing.expect(config1.getEffectiveZstdLevel() == 22);

    var config2 = CompressionConfig.init(.zstd).withZstdLevel(-5);
    try testing.expect(config2.getEffectiveZstdLevel() == 1);

    var config3 = CompressionConfig.init(.zstd).withZstdLevel(10);
    try testing.expect(config3.getEffectiveZstdLevel() == 10);
}

test "algorithm level validation" {
    const testing = std.testing;

    var config1 = CompressionConfig.init(.gzip).withCustomLevel(15);
    try testing.expect(config1.isValidForAlgorithm());
    try testing.expect(config1.custom_level.? == 9);

    var config2 = CompressionConfig.init(.gzip).withCustomLevel(6);
    try testing.expect(config2.isValidForAlgorithm());

    var config3 = CompressionConfig.init(.zstd).withZstdLevel(10);
    try testing.expect(config3.isValidForAlgorithm());
}

test "path filter functionality" {
    const testing = std.testing;

    const exclude_rules = [_]FilterRule{
        .{ .pattern = "*.tmp", .is_directory = false },
        .{ .pattern = "*.log", .is_directory = false },
        .{ .pattern = "node_modules/**", .is_directory = true },
    };

    const include_rules = [_]FilterRule{
        .{ .pattern = "*.zig", .is_directory = false },
        .{ .pattern = "*.md", .is_directory = false },
        .{ .pattern = "src/**", .is_directory = true },
    };

    var filter = PathFilter{
        .include_rules = &include_rules,
        .exclude_rules = &exclude_rules,
        .default_action = false,
    };

    try testing.expect(!filter.shouldInclude("test.tmp", false));
    try testing.expect(!filter.shouldInclude("debug.log", false));
    try testing.expect(filter.shouldInclude("main.zig", false));
    try testing.expect(filter.shouldInclude("README.md", false));
    try testing.expect(!filter.shouldInclude("node_modules/package", true));
    try testing.expect(filter.shouldInclude("src/main.zig", false));
}

test "options from config" {
    const testing = std.testing;

    const config = CompressionConfig.init(.zstd)
        .withZstdLevel(12)
        .withChecksum()
        .withThreads(2)
        .withBufferSize(128 * 1024);

    const options = Options.fromConfig(config);

    try testing.expect(options.checksum == true);
    try testing.expect(options.zstd_level.? == 12);
    try testing.expect(options.threads == 2);
    try testing.expect(options.buffer_size == 128 * 1024);
}
