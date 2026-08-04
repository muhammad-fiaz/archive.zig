const std = @import("std");
const Constants = @import("constants.zig");

pub fn parseSize(s: []const u8) ?u64 {
    var end: usize = 0;
    while (end < s.len and std.ascii.isDigit(s[end])) : (end += 1) {}
    if (end == 0) return null;
    const num = std.fmt.parseInt(u64, s[0..end], 10) catch return null;
    var unit_start = end;
    while (unit_start < s.len and std.ascii.isWhitespace(s[unit_start])) : (unit_start += 1) {}
    if (unit_start >= s.len) return num;
    const unit = s[unit_start..];
    if (std.ascii.eqlIgnoreCase(unit, "B")) return num;
    if (std.ascii.eqlIgnoreCase(unit, "K") or std.ascii.eqlIgnoreCase(unit, "KB")) return num * Constants.SizeConstants.bytes_per_kb;
    if (std.ascii.eqlIgnoreCase(unit, "M") or std.ascii.eqlIgnoreCase(unit, "MB")) return num * Constants.SizeConstants.bytes_per_mb;
    if (std.ascii.eqlIgnoreCase(unit, "G") or std.ascii.eqlIgnoreCase(unit, "GB")) return num * Constants.SizeConstants.bytes_per_gb;
    if (std.ascii.eqlIgnoreCase(unit, "T") or std.ascii.eqlIgnoreCase(unit, "TB")) return num * Constants.SizeConstants.bytes_per_tb;
    return num;
}

pub fn writeSize(writer: anytype, bytes: u64) !void {
    const units = [_][]const u8{ "B", "KB", "MB", "GB", "TB" };
    const bytes_per_kb_f: f64 = @floatFromInt(Constants.SizeConstants.bytes_per_kb);
    var value: f64 = @floatFromInt(bytes);
    var unit_idx: usize = 0;
    while (value >= bytes_per_kb_f and unit_idx < units.len - 1) {
        value /= bytes_per_kb_f;
        unit_idx += 1;
    }
    if (unit_idx == 0) {
        try writer.print("{d} {s}", .{ bytes, units[unit_idx] });
    } else {
        try writer.print("{d:.2} {s}", .{ value, units[unit_idx] });
    }
}

pub fn formatSize(allocator: std.mem.Allocator, bytes: u64) ![]u8 {
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);
    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();
    try writeSize(&aw.writer, bytes);
    return aw.toOwnedSlice();
}

pub fn parseDuration(s: []const u8) ?i64 {
    var end: usize = 0;
    while (end < s.len and std.ascii.isDigit(s[end])) : (end += 1) {}
    if (end == 0) return null;
    const num = std.fmt.parseInt(i64, s[0..end], 10) catch return null;
    var unit_start = end;
    while (unit_start < s.len and std.ascii.isWhitespace(s[unit_start])) : (unit_start += 1) {}
    if (unit_start >= s.len) return num;
    const unit = s[unit_start..];
    if (std.ascii.eqlIgnoreCase(unit, "ms")) return num;
    if (std.ascii.eqlIgnoreCase(unit, "s")) return num * @as(i64, @intCast(Constants.TimeConstants.ms_per_second));
    if (std.ascii.eqlIgnoreCase(unit, "m")) return num * @as(i64, @intCast(Constants.TimeConstants.seconds_per_minute * Constants.TimeConstants.ms_per_second));
    if (std.ascii.eqlIgnoreCase(unit, "h")) return num * @as(i64, @intCast(Constants.TimeConstants.seconds_per_hour * Constants.TimeConstants.ms_per_second));
    if (std.ascii.eqlIgnoreCase(unit, "d")) return num * @as(i64, @intCast(Constants.TimeConstants.seconds_per_day * Constants.TimeConstants.ms_per_second));
    return num;
}

pub fn currentNanos() i128 {
    return std.time.nanoTimestamp();
}

pub fn currentMillis() i64 {
    return std.time.milliTimestamp();
}

pub fn atomicLoadU64(atomic: anytype) u64 {
    return @as(u64, atomic.load(.monotonic));
}

pub fn calculateErrorRate(errors: u64, total: u64) f64 {
    if (total == 0) return 0.0;
    return @as(f64, @floatFromInt(errors)) / @as(f64, @floatFromInt(total));
}

pub fn calculateCRC32(data: []const u8) u32 {
    return std.hash.Crc32.hash(data);
}

pub fn lzmaHash(data: []const u8, len: usize) u32 {
    if (len < 2) return 0;
    var hash: u32 = 0;
    for (0..len) |i| {
        hash = (hash *% 31) +% data[i];
    }
    return hash;
}

pub fn lz4Hash(data: *const [4]u8) u32 {
    var h: u32 = 0;
    for (data) |b| h = (h *% 31) +% b;
    return @intCast(h % Constants.Lz4Constants.hash_size);
}

pub fn matchGlob(name: []const u8, pattern: []const u8) bool {
    return matchGlobWithCase(name, pattern, true);
}

pub fn matchGlobIgnoreCase(name: []const u8, pattern: []const u8) bool {
    return matchGlobWithCase(name, pattern, false);
}

pub fn matchGlobWithCase(name: []const u8, pattern: []const u8, case_sensitive: bool) bool {
    if (std.mem.eql(u8, pattern, "*")) return true;
    if (std.mem.eql(u8, pattern, "**")) return true;

    if (std.mem.startsWith(u8, pattern, "*.")) {
        const ext = pattern[1..];
        return if (case_sensitive)
            std.mem.endsWith(u8, name, ext)
        else
            std.ascii.endsWithIgnoreCase(name, ext);
    }

    if (std.mem.startsWith(u8, pattern, "**/")) {
        const suffix = pattern[3..];
        return if (case_sensitive)
            std.mem.indexOf(u8, name, suffix) != null
        else
            std.ascii.indexOfIgnoreCase(name, suffix) != null;
    }

    if (std.mem.endsWith(u8, pattern, "/**")) {
        const prefix = pattern[0 .. pattern.len - 3];
        return if (case_sensitive)
            std.mem.startsWith(u8, name, prefix)
        else
            std.ascii.startsWithIgnoreCase(name, prefix);
    }

    if (std.mem.indexOf(u8, pattern, "*")) |_| {
        return globMatchAdvanced(name, pattern, case_sensitive);
    }

    return if (case_sensitive)
        std.mem.eql(u8, name, pattern)
    else
        std.ascii.eqlIgnoreCase(name, pattern);
}

pub fn globMatchAdvanced(text: []const u8, pattern: []const u8, case_sensitive: bool) bool {
    var t_idx: usize = 0;
    var p_idx: usize = 0;
    var star_idx: ?usize = null;
    var match_idx: usize = 0;

    while (t_idx < text.len) {
        if (p_idx < pattern.len and (pattern[p_idx] == '?' or
            (case_sensitive and pattern[p_idx] == text[t_idx]) or
            (!case_sensitive and std.ascii.toLower(pattern[p_idx]) == std.ascii.toLower(text[t_idx]))))
        {
            t_idx += 1;
            p_idx += 1;
        } else if (p_idx < pattern.len and pattern[p_idx] == '*') {
            star_idx = p_idx;
            match_idx = t_idx;
            p_idx += 1;
        } else if (star_idx) |s_idx| {
            p_idx = s_idx + 1;
            match_idx += 1;
            t_idx = match_idx;
        } else {
            return false;
        }
    }

    while (p_idx < pattern.len and pattern[p_idx] == '*') {
        p_idx += 1;
    }

    return p_idx == pattern.len;
}

pub fn shouldIncludePath(path: []const u8, include_patterns: []const []const u8, exclude_patterns: []const []const u8) bool {
    return shouldIncludePathWithCase(path, include_patterns, exclude_patterns, false);
}

pub fn shouldIncludePathWithCase(path: []const u8, include_patterns: []const []const u8, exclude_patterns: []const []const u8, case_sensitive: bool) bool {
    for (exclude_patterns) |pat| {
        if (matchGlobWithCase(path, pat, case_sensitive)) return false;
    }
    if (include_patterns.len == 0) return true;
    for (include_patterns) |pat| {
        if (matchGlobWithCase(path, pat, case_sensitive)) return true;
    }
    return false;
}

pub fn validateCompressionLevel(algorithm: u8, level: u8) bool {
    return switch (algorithm) {
        0 => level == 0,
        1, 2, 3, 4 => level >= 1 and level <= 9,
        5 => level >= 1 and level <= 22,
        6, 7, 8 => level >= 1 and level <= 9,
        9 => level >= 1 and level <= 9,
        10 => level >= 1 and level <= 9,
        11 => level >= 1 and level <= 12,
        else => false,
    };
}

pub fn getOptimalBufferSize(file_size: u64, algorithm: u8) usize {
    const base_size = Constants.BufferSizes.compression;

    if (file_size < 1024) return Constants.BufferSizes.min_buffer;
    if (file_size > Constants.BufferSizes.max_buffer) return Constants.BufferSizes.max_buffer;

    return switch (algorithm) {
        5 => @min(Constants.BufferSizes.zstd_in, @as(usize, @intCast(file_size / 4))),
        11 => @min(Constants.BufferSizes.lz4_block_max, @as(usize, @intCast(file_size / 2))),
        else => @min(base_size * 2, @as(usize, @intCast(file_size / 8))),
    };
}

pub fn estimateCompressionRatio(algorithm: u8, level: u8, data_type: u8) f64 {
    const base_ratio = switch (algorithm) {
        0 => 1.0,
        1, 2, 3, 4 => 0.3 + (@as(f64, @floatFromInt(9 - level)) * 0.05),
        5 => 0.2 + (@as(f64, @floatFromInt(22 - level)) * 0.02),
        6, 7, 8 => 0.25 + (@as(f64, @floatFromInt(9 - level)) * 0.04),
        9 => 0.35 + (@as(f64, @floatFromInt(9 - level)) * 0.05),
        10 => 0.35 + (@as(f64, @floatFromInt(9 - level)) * 0.05),
        11 => 0.6 + (@as(f64, @floatFromInt(12 - level)) * 0.02),
        else => 0.5,
    };

    const type_modifier = switch (data_type) {
        0 => 1.0,
        1 => 0.8,
        2 => 1.2,
        3 => 0.6,
        else => 1.0,
    };

    return base_ratio * type_modifier;
}

pub fn isPathSafe(path: []const u8) bool {
    if (path.len == 0) return false;
    if (std.mem.startsWith(u8, path, "..")) return false;
    if (std.mem.indexOf(u8, path, "../")) |_| return false;
    if (std.mem.indexOf(u8, path, "\\..\\")) |_| return false;
    if (std.mem.indexOf(u8, path, "//")) |_| return false;
    if (std.mem.indexOf(u8, path, "\\\\")) |_| return false;
    return true;
}

pub fn normalizePathSeparators(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    return try std.mem.replace(u8, allocator, path, "\\", "/");
}

pub fn getFileExtension(path: []const u8) []const u8 {
    const base = std.fs.path.basename(path);
    if (std.mem.lastIndexOf(u8, base, ".")) |dot_idx| {
        return base[dot_idx..];
    }
    return "";
}

pub fn hasExtension(path: []const u8, extensions: []const []const u8) bool {
    const ext = getFileExtension(path);
    for (extensions) |target_ext| {
        if (std.ascii.eqlIgnoreCase(ext, target_ext)) return true;
    }
    return false;
}

pub fn isCompressedFile(path: []const u8) bool {
    const compressed_extensions = [_][]const u8{ ".gz", ".bz2", ".xz", ".lzma", ".zst", ".lz4", ".zip", ".rar", ".7z", ".tar.gz", ".tar.bz2", ".tar.xz" };
    return hasExtension(path, &compressed_extensions);
}

pub fn calculateOptimalThreads(file_size: u64, available_cores: u32) u32 {
    if (file_size < 1024 * 1024) return 1;
    if (file_size < 10 * 1024 * 1024) return @min(2, available_cores);
    if (file_size < 100 * 1024 * 1024) return @min(4, available_cores);
    return @min(8, available_cores);
}

pub fn getBasename(path: []const u8) []const u8 {
    return std.fs.path.basename(path);
}

pub fn getDirname(path: []const u8) []const u8 {
    return std.fs.path.dirname(path) orelse "";
}

test "parseSize" {
    const testing = std.testing;
    try testing.expect(parseSize("1024").? == 1024);
    try testing.expect(parseSize("1KB").? == 1024);
    try testing.expect(parseSize("1MB").? == 1024 * 1024);
    try testing.expect(parseSize("invalid") == null);
}

test "matchGlob advanced patterns" {
    const testing = std.testing;
    try testing.expect(matchGlob("file.txt", "*.txt"));
    try testing.expect(!matchGlob("file.txt", "*.log"));
    try testing.expect(matchGlob("anything", "*"));
    try testing.expect(matchGlob("src/main.zig", "src/*.zig"));
    try testing.expect(matchGlob("deep/nested/file.zig", "**/file.zig"));
    try testing.expect(matchGlob("src/utils/helper.zig", "src/**"));
}

test "shouldIncludePath with case sensitivity" {
    const testing = std.testing;
    const include = [_][]const u8{"*.TXT"};
    const exclude = [_][]const u8{"*.tmp"};

    try testing.expect(shouldIncludePathWithCase("file.txt", &include, &exclude, false));
    try testing.expect(!shouldIncludePathWithCase("file.txt", &include, &exclude, true));
    try testing.expect(!shouldIncludePathWithCase("file.tmp", &include, &exclude, false));
}

test "validateCompressionLevel" {
    const testing = std.testing;
    try testing.expect(validateCompressionLevel(5, 10));
    try testing.expect(!validateCompressionLevel(5, 25));
    try testing.expect(validateCompressionLevel(1, 6));
    try testing.expect(!validateCompressionLevel(1, 15));
}

test "isPathSafe" {
    const testing = std.testing;
    try testing.expect(isPathSafe("src/main.zig"));
    try testing.expect(!isPathSafe("../etc/passwd"));
    try testing.expect(!isPathSafe("src/../../../etc/passwd"));
    try testing.expect(isPathSafe("normal/path/file.txt"));
}

test "getOptimalBufferSize" {
    const testing = std.testing;
    const size1 = getOptimalBufferSize(1024 * 1024, 5);
    const size2 = getOptimalBufferSize(100, 1);
    try testing.expect(size1 > Constants.BufferSizes.min_buffer);
    try testing.expect(size2 == Constants.BufferSizes.min_buffer);
}

test "calculateCRC32" {
    const testing = std.testing;
    const crc = calculateCRC32("hello");
    try testing.expect(crc != 0);
}

pub fn copyMatchData(result: *std.ArrayList(u8), allocator: std.mem.Allocator, offset: usize, length: usize) !void {
    if (offset > result.items.len or offset == 0) return error.InvalidOffset;

    const start = result.items.len - offset;
    var i: usize = 0;
    while (i < length) : (i += 1) {
        const idx = start + (i % offset);
        try result.append(allocator, result.items[idx]);
    }
}

pub fn lz4HeaderChecksum(data: []const u8) u32 {
    var hash: u32 = 0;
    for (data) |b| {
        hash = (hash *% 31) +% b;
    }
    return hash;
}

pub fn writeVariableLength(result: *std.ArrayList(u8), allocator: std.mem.Allocator, value: usize) !void {
    var remaining = value;
    while (remaining >= 255) {
        try result.append(allocator, 255);
        remaining -= 255;
    }
    try result.append(allocator, @intCast(remaining));
}

pub fn readVariableLength(data: []const u8, pos: *usize) !usize {
    var value: usize = 0;
    while (pos.* < data.len) {
        const byte = data[pos.*];
        pos.* += 1;
        value += byte;
        if (byte != 255) break;
    }
    return value;
}

pub fn validateCompressionRatio(original_size: usize, compressed_size: usize, max_ratio: f64) bool {
    if (original_size == 0) return true;
    const ratio = @as(f64, @floatFromInt(compressed_size)) / @as(f64, @floatFromInt(original_size));
    return ratio <= max_ratio;
}

pub fn formatCompressionRatio(original_size: usize, compressed_size: usize) f64 {
    if (original_size == 0) return 0.0;
    return @as(f64, @floatFromInt(compressed_size)) / @as(f64, @floatFromInt(original_size)) * 100.0;
}

test "copyMatchData" {
    const testing = std.testing;
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(testing.allocator);

    try result.appendSlice(testing.allocator, "hello");
    try copyMatchData(&result, testing.allocator, 2, 2);
    try testing.expectEqualStrings("hellolo", result.items);
    result.deinit(testing.allocator);
}

test "lz4HeaderChecksum" {
    const testing = std.testing;
    const hash1 = lz4HeaderChecksum("hello");
    const hash2 = lz4HeaderChecksum("world");
    try testing.expect(hash1 != hash2);
    try testing.expect(hash1 == lz4HeaderChecksum("hello"));
}

test "formatCompressionRatio" {
    const testing = std.testing;
    const ratio = formatCompressionRatio(100, 50);
    try testing.expect(ratio == 50.0);
}
