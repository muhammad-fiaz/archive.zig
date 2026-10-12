const std = @import("std");
const config = @import("../config.zig");
const gzip = @import("gzip.zig");
const errors = @import("../errors.zig");

/// Default entry name used by one-shot `compress`.
pub const default_entry_name = "payload.bin";
/// TAR block size in bytes.
pub const block_size = 512;

/// A single TAR archive member. `data` is borrowed; `pack` copies it.
pub const TarEntry = struct {
    name: []const u8,
    data: []const u8,
    mode: u32 = 0o644,
    mtime: u64 = 0,
};

/// An owned TAR member returned by `parseTar` / `unpack`.
pub const OwnedTarEntry = struct {
    name: []u8,
    data: []u8,
    mode: u32,
    mtime: u64,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *OwnedTarEntry) void {
        self.allocator.free(self.name);
        self.allocator.free(self.data);
    }
};

pub fn freeEntries(allocator: std.mem.Allocator, entries: []OwnedTarEntry) void {
    for (entries) |*e| e.deinit();
    allocator.free(entries);
}

fn writeOctalField(buf: []u8, value: u64) !void {
    // Standard ustar numeric field: '0'-padded octal digits with a trailing
    // NUL, matching `std.tar.Writer.Header` ("w minus 1 digits, and a null").
    // NUL-padded fields are rejected by `std.tar`, so '0'-padding matters
    // for interoperability.
    @memset(buf, '0');
    buf[buf.len - 1] = 0;
    var v = value;
    var i: usize = buf.len - 1;
    while (i > 0) {
        i -= 1;
        buf[i] = @intCast((v & 7) + '0');
        v >>= 3;
        if (v == 0) break;
    }
    if (v != 0) return error.OutputTooLarge;
}

fn parseOctalField(field: []const u8) !u64 {
    var value: u64 = 0;
    var saw_digit = false;
    for (field) |c| {
        if (c == 0 or c == ' ') {
            if (saw_digit) break;
            continue;
        }
        if (c < '0' or c > '7') return error.InvalidTarArchive;
        saw_digit = true;
        value = try std.math.mul(u64, value, 8);
        value = try std.math.add(u64, value, c - '0');
    }
    if (!saw_digit) return error.InvalidTarArchive;
    return value;
}

fn headerChecksum(header: *const [512]u8) u32 {
    var sum: u32 = 0;
    for (header, 0..) |b, i| {
        if (i >= 148 and i < 156) {
            sum += ' ';
        } else {
            sum += b;
        }
    }
    return sum;
}

fn splitName(name: []const u8) struct { name: []const u8, prefix: []const u8 } {
    if (name.len <= 100) return .{ .name = name, .prefix = "" };
    // Split at the last '/' such that both parts fit.
    var i = name.len;
    while (i > 0) : (i -= 1) {
        if (name[i - 1] == '/' and i - 1 <= 155 and name.len - i <= 100) {
            return .{ .name = name[i..], .prefix = name[0 .. i - 1] };
        }
    }
    return .{ .name = name[name.len - 100 ..], .prefix = "" };
}

/// Builds a raw (uncompressed) TAR archive from `entries`.
/// The caller owns the returned bytes.
pub fn buildTar(allocator: std.mem.Allocator, entries: []const TarEntry) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    for (entries) |entry| {
        if (entry.name.len == 0 or entry.name.len > 255) return error.InvalidTarArchive;
        if (!@import("../utils.zig").isPathSafe(entry.name)) return error.InvalidTarArchive;

        var header: [512]u8 = @splat(0);
        const parts = splitName(entry.name);
        if (parts.name.len == 0 or parts.name.len > 100 or parts.prefix.len > 155) return error.InvalidTarArchive;
        @memcpy(header[0..parts.name.len], parts.name);
        try writeOctalField(header[100..108], entry.mode & 0o7777);
        try writeOctalField(header[108..116], 0); // uid
        try writeOctalField(header[116..124], 0); // gid
        try writeOctalField(header[124..136], entry.data.len);
        try writeOctalField(header[136..148], entry.mtime);
        header[156] = '0'; // regular file
        @memcpy(header[257..263], "ustar ");
        @memcpy(header[263..265], "00");
        const sum = headerChecksum(&header);
        try writeOctalField(header[148..156], sum);

        try out.appendSlice(allocator, &header);
        try out.appendSlice(allocator, entry.data);
        const pad = (block_size - (entry.data.len % block_size)) % block_size;
        if (pad > 0) {
            const zeros: [64]u8 = @splat(0);
            var remaining = pad;
            while (remaining > 0) {
                const n = @min(remaining, zeros.len);
                try out.appendSlice(allocator, zeros[0..n]);
                remaining -= n;
            }
        }
    }

    // Two zero blocks terminate the archive.
    const terminator: [64]u8 = @splat(0);
    for (0..(1024 / 64)) |_| try out.appendSlice(allocator, &terminator);

    return out.toOwnedSlice(allocator);
}

/// Parses a raw (uncompressed) TAR archive. The caller owns the returned
/// entries and must release them with `freeEntries`.
pub fn parseTar(allocator: std.mem.Allocator, tar_data: []const u8) ![]OwnedTarEntry {
    var entries: std.ArrayList(OwnedTarEntry) = .empty;
    errdefer {
        for (entries.items) |*e| e.deinit();
        entries.deinit(allocator);
    }

    var pos: usize = 0;
    while (true) {
        if (pos + block_size > tar_data.len) return error.InvalidTarArchive;
        const block = tar_data[pos .. pos + block_size];

        var all_zero = true;
        for (block) |b| {
            if (b != 0) {
                all_zero = false;
                break;
            }
        }
        if (all_zero) break; // end-of-archive marker
        pos += block_size;

        if (block[156] != 0 and block[156] != '0') return error.InvalidTarArchive;

        const stored = parseOctalField(block[148..156]) catch return error.InvalidTarArchive;
        var header_copy: [512]u8 = undefined;
        @memcpy(&header_copy, block);
        if (headerChecksum(&header_copy) != stored) return error.InvalidTarArchive;

        const size = parseOctalField(block[124..136]) catch return error.InvalidTarArchive;
        const mtime = parseOctalField(block[136..148]) catch return error.InvalidTarArchive;
        const mode = parseOctalField(block[100..108]) catch 0o644;

        const name_end = std.mem.indexOfScalar(u8, block[0..100], 0) orelse 100;
        const prefix_end = std.mem.indexOfScalar(u8, block[345..500], 0) orelse 155;
        const name_part = block[0..name_end];
        const prefix_part = block[345 .. 345 + prefix_end];

        var full_name: std.ArrayList(u8) = .empty;
        defer full_name.deinit(allocator);
        if (prefix_part.len > 0) {
            try full_name.appendSlice(allocator, prefix_part);
            try full_name.append(allocator, '/');
        }
        try full_name.appendSlice(allocator, name_part);
        if (full_name.items.len == 0) return error.InvalidTarArchive;

        if (pos + size > tar_data.len) return error.InvalidTarArchive;
        const name = try allocator.dupe(u8, full_name.items);
        errdefer allocator.free(name);
        const data = try allocator.dupe(u8, tar_data[pos .. pos + size]);
        errdefer allocator.free(data);

        try entries.append(allocator, .{
            .name = name,
            .data = data,
            .mode = @intCast(mode & 0o7777),
            .mtime = mtime,
            .allocator = allocator,
        });

        pos += size;
        pos += (block_size - (size % block_size)) % block_size;
    }

    return entries.toOwnedSlice(allocator);
}

/// Packs `entries` into a TAR archive and compresses it with gzip.
/// The caller owns the returned bytes.
pub fn pack(allocator: std.mem.Allocator, entries: []const TarEntry, options: config.Options) ![]u8 {
    const tar_data = try buildTar(allocator, entries);
    defer allocator.free(tar_data);
    return gzip.compress(allocator, tar_data, options) catch |err| switch (err) {
        error.OutOfMemory => error.OutOfMemory,
        else => err,
    };
}

/// Decompresses a `.tar.gz` payload and parses the TAR members.
/// The caller owns the entries; release with `freeEntries`.
pub fn unpack(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]OwnedTarEntry {
    const tar_data = try gzip.decompress(allocator, data, options);
    defer allocator.free(tar_data);
    return parseTar(allocator, tar_data);
}

/// One-shot compression: wraps `data` as a single TAR entry named
/// `default_entry_name` and compresses it with gzip.
/// The caller owns the returned bytes.
pub fn compress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    if (data.len == 0) {
        const empty = try buildTar(allocator, &.{});
        defer allocator.free(empty);
        return gzip.compress(allocator, empty, options);
    }
    return pack(allocator, &.{.{ .name = default_entry_name, .data = data }}, options);
}

/// One-shot decompression: gunzips `data`, parses the TAR archive, and
/// returns the payload of its single entry. Archives with zero entries yield
/// an empty slice; archives with more than one entry report
/// `error.InvalidTarArchive` (use `unpack` for multi-entry archives).
/// The caller owns the returned bytes.
pub fn decompress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    if (data.len == 0) return allocator.alloc(u8, 0);
    const entries = try unpack(allocator, data, options);
    defer freeEntries(allocator, entries);
    if (entries.len == 0) return allocator.alloc(u8, 0);
    if (entries.len != 1) return error.InvalidTarArchive;
    return allocator.dupe(u8, entries[0].data) catch error.OutOfMemory;
}

test "tar_gz roundtrip" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const input = "Hello, World! This is a tar.gz test.";
    const compressed = try compress(allocator, input, .{});
    defer allocator.free(compressed);
    const decompressed = try decompress(allocator, compressed, .{});
    defer allocator.free(decompressed);
    try testing.expectEqualStrings(input, decompressed);
}

test "tar_gz multi entry pack unpack" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const entries = [_]TarEntry{
        .{ .name = "a.txt", .data = "first file" },
        .{ .name = "dir/b.txt", .data = "second file", .mode = 0o600 },
    };
    const archive_bytes = try pack(allocator, &entries, .{});
    defer allocator.free(archive_bytes);
    const parsed = try unpack(allocator, archive_bytes, .{});
    defer freeEntries(allocator, parsed);
    try testing.expect(parsed.len == 2);
    try testing.expectEqualStrings("a.txt", parsed[0].name);
    try testing.expectEqualStrings("first file", parsed[0].data);
    try testing.expectEqualStrings("dir/b.txt", parsed[1].name);
    try testing.expectEqualStrings("second file", parsed[1].data);
}

test "tar_gz rejects multi entry one-shot" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const entries = [_]TarEntry{
        .{ .name = "a.txt", .data = "one" },
        .{ .name = "b.txt", .data = "two" },
    };
    const archive_bytes = try pack(allocator, &entries, .{});
    defer allocator.free(archive_bytes);
    try testing.expectError(error.InvalidTarArchive, decompress(allocator, archive_bytes, .{}));
}

test "tar_gz rejects corrupt input" {
    const testing = std.testing;
    const bad = [_]u8{ 0x1f, 0x8b, 0x00, 0x01 };
    const result = unpack(testing.allocator, &bad, .{});
    try testing.expect(result == error.InvalidData or result == error.ReadFailed or result == error.CorruptedStream);
}

test "tar std Writer interop" {
    // Archives built with `std.tar.Writer` must parse with our `parseTar`.
    const testing = std.testing;
    const allocator = testing.allocator;

    var aw = std.Io.Writer.Allocating.init(allocator);
    defer aw.deinit();
    var tw = std.tar.Writer{ .underlying_writer = &aw.writer };
    try tw.writeFileBytes("a.txt", "first file", .{});
    try tw.writeFileBytes("dir/b.txt", "second file", .{ .mode = 0o600, .mtime = 1234567890 });
    try tw.finishPedantically();
    const tar_bytes = try aw.toOwnedSlice();
    defer allocator.free(tar_bytes);

    const parsed = try parseTar(allocator, tar_bytes);
    defer freeEntries(allocator, parsed);
    try testing.expect(parsed.len == 2);
    try testing.expectEqualStrings("a.txt", parsed[0].name);
    try testing.expectEqualStrings("first file", parsed[0].data);
    try testing.expectEqualStrings("dir/b.txt", parsed[1].name);
    try testing.expectEqualStrings("second file", parsed[1].data);
    try testing.expect(parsed[1].mode == 0o600);
    try testing.expect(parsed[1].mtime == 1234567890);
}

test "tar std Iterator interop" {
    // Archives built with our `buildTar` must iterate with `std.tar.Iterator`,
    // proving the headers are genuine ustar, not just self-consistent.
    const testing = std.testing;
    const allocator = testing.allocator;

    const entries = [_]TarEntry{
        .{ .name = "a.txt", .data = "first file" },
        .{ .name = "dir/b.txt", .data = "second file", .mode = 0o600, .mtime = 42 },
    };
    const tar_bytes = try buildTar(allocator, &entries);
    defer allocator.free(tar_bytes);

    var name_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    var link_buf: [std.Io.Dir.max_path_bytes]u8 = undefined;
    var fixed = std.Io.Reader.fixed(tar_bytes);
    var it = std.tar.Iterator.init(&fixed, .{
        .file_name_buffer = &name_buf,
        .link_name_buffer = &link_buf,
    });

    var count: usize = 0;
    while (try it.next()) |file| {
        try testing.expect(count < entries.len);
        try testing.expectEqualStrings(entries[count].name, file.name);
        try testing.expect(file.size == entries[count].data.len);
        // Consume the entry body through the iterator so padding and
        // bookkeeping stay in sync for the following entry.
        var body = std.Io.Writer.Allocating.init(allocator);
        defer body.deinit();
        try it.streamRemaining(file, &body.writer);
        try testing.expectEqualSlices(u8, entries[count].data, body.written());
        count += 1;
    }
    try testing.expect(count == entries.len);
}
