const std = @import("std");
const config = @import("../config.zig");
const deflate = @import("deflate.zig");
const utils = @import("../utils.zig");
const Constants = @import("../constants.zig");
const CompressError = @import("../errors.zig").CompressError;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

pub const EocdBase = packed struct {
    disk_number: u16,
    cd_start_disk: u16,
    cd_entries_disk: u16,
    total_cd_entries: u16,
    cd_size: u32,
    cd_offset: u32,
    comment_len: u16,
};

pub const Eocd = struct {
    base: EocdBase,
    comment: []const u8,
    allocator: Allocator,

    pub fn newFromReader(allocator: Allocator, reader: *std.Io.Reader) !Eocd {
        var buff: [Constants.ZipConstants.EOCD_SIZE_NOV - Constants.ZipConstants.SIGNATURE_LENGTH]u8 = undefined;
        try reader.readSliceAll(&buff);
        var r: std.Io.Reader = .fixed(&buff);
        const base = EocdBase{
            .disk_number = try r.takeInt(u16, .little),
            .cd_start_disk = try r.takeInt(u16, .little),
            .cd_entries_disk = try r.takeInt(u16, .little),
            .total_cd_entries = try r.takeInt(u16, .little),
            .cd_size = try r.takeInt(u32, .little),
            .cd_offset = try r.takeInt(u32, .little),
            .comment_len = try r.takeInt(u16, .little),
        };

        const comment = try allocator.alloc(u8, base.comment_len);
        errdefer allocator.free(comment);
        if (base.comment_len != 0)
            try reader.readSliceAll(comment);

        return Eocd{
            .base = base,
            .comment = comment,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: Eocd) void {
        self.allocator.free(self.comment);
    }
};

pub const CdfhBase = packed struct {
    made_by_ver: u16,
    extract_ver: u16,
    gp_flag: u16,
    compression: u16,
    mod_time: u16,
    mod_date: u16,
    crc32: u32,
    comp_size: u32,
    uncomp_size: u32,
    name_len: u16,
    extra_len: u16,
    comment_len: u16,
    start_disk: u16,
    int_attrs: u16,
    ext_attrs: u32,
    lfh_offset: u32,
};

pub const Cdfh = struct {
    base: CdfhBase,
    name: []const u8,
    extra: []const u8,
    comment: []const u8,
    allocator: Allocator,

    pub fn newFromReader(allocator: Allocator, reader: *std.Io.Reader) !Cdfh {
        var buff: [Constants.ZipConstants.CDHF_SIZE_NOV - Constants.ZipConstants.SIGNATURE_LENGTH]u8 = undefined;
        try reader.readSliceAll(&buff);
        var r: std.Io.Reader = .fixed(&buff);
        const base = CdfhBase{
            .made_by_ver = try r.takeInt(u16, .little),
            .extract_ver = try r.takeInt(u16, .little),
            .gp_flag = try r.takeInt(u16, .little),
            .compression = try r.takeInt(u16, .little),
            .mod_time = try r.takeInt(u16, .little),
            .mod_date = try r.takeInt(u16, .little),
            .crc32 = try r.takeInt(u32, .little),
            .comp_size = try r.takeInt(u32, .little),
            .uncomp_size = try r.takeInt(u32, .little),
            .name_len = try r.takeInt(u16, .little),
            .extra_len = try r.takeInt(u16, .little),
            .comment_len = try r.takeInt(u16, .little),
            .start_disk = try r.takeInt(u16, .little),
            .int_attrs = try r.takeInt(u16, .little),
            .ext_attrs = try r.takeInt(u32, .little),
            .lfh_offset = try r.takeInt(u32, .little),
        };

        const name = try allocator.alloc(u8, base.name_len);
        errdefer allocator.free(name);
        const extra = try allocator.alloc(u8, base.extra_len);
        errdefer allocator.free(extra);
        const comment = try allocator.alloc(u8, base.comment_len);
        errdefer allocator.free(comment);

        try reader.readSliceAll(name);
        try reader.readSliceAll(extra);
        try reader.readSliceAll(comment);

        return Cdfh{ .base = base, .name = name, .extra = extra, .comment = comment, .allocator = allocator };
    }

    pub fn deinit(self: Cdfh) void {
        self.allocator.free(self.name);
        self.allocator.free(self.extra);
        self.allocator.free(self.comment);
    }
};

pub const LfhBase = packed struct {
    extract_ver: u16,
    gp_flag: u16,
    compression: u16,
    mod_time: u16,
    mod_date: u16,
    crc32: u32,
    comp_size: u32,
    uncomp_size: u32,
    name_len: u16,
    extra_len: u16,
};

pub const Lfh = struct {
    base: LfhBase,
    name: []const u8,
    extra: []const u8,
    allocator: Allocator,

    pub fn newFromReader(allocator: Allocator, reader: *std.Io.Reader) !Lfh {
        var buff: [Constants.ZipConstants.LFH_SIZE_NOV - Constants.ZipConstants.SIGNATURE_LENGTH]u8 = undefined;
        try reader.readSliceAll(&buff);
        var r: std.Io.Reader = .fixed(&buff);
        const base = LfhBase{
            .extract_ver = try r.takeInt(u16, .little),
            .gp_flag = try r.takeInt(u16, .little),
            .compression = try r.takeInt(u16, .little),
            .mod_time = try r.takeInt(u16, .little),
            .mod_date = try r.takeInt(u16, .little),
            .crc32 = try r.takeInt(u32, .little),
            .comp_size = try r.takeInt(u32, .little),
            .uncomp_size = try r.takeInt(u32, .little),
            .name_len = try r.takeInt(u16, .little),
            .extra_len = try r.takeInt(u16, .little),
        };

        const name = try allocator.alloc(u8, base.name_len);
        errdefer allocator.free(name);
        const extra = try allocator.alloc(u8, base.extra_len);
        errdefer allocator.free(extra);

        try reader.readSliceAll(name);
        try reader.readSliceAll(extra);

        return Lfh{ .base = base, .name = name, .extra = extra, .allocator = allocator };
    }

    pub fn deinit(self: Lfh) void {
        self.allocator.free(self.name);
        self.allocator.free(self.extra);
    }
};

pub const ZipArchive = struct {
    data: []const u8,
    allocator: Allocator,
    eocd: Eocd,
    entries: std.ArrayList(ZipEntry),

    pub fn init(allocator: Allocator, data: []const u8) !ZipArchive {
        var reader: std.Io.Reader = .fixed(data);

        const eocd_offset = try findEocd(data);
        reader.seek = eocd_offset + 4;
        const eocd = try Eocd.newFromReader(allocator, &reader);
        errdefer eocd.deinit();

        var entries: std.ArrayList(ZipEntry) = .empty;
        errdefer entries.deinit(allocator);

        reader.seek = eocd.base.cd_offset;
        var offset = eocd.base.cd_offset;

        for (0..eocd.base.total_cd_entries) |_| {
            var sig_buf: [4]u8 = undefined;
            try reader.readSliceAll(&sig_buf);
            const sig = std.mem.readInt(u32, &sig_buf, .little);
            if (sig != Constants.ZipConstants.CDFH_SIGNATURE) return error.InvalidZipArchive;

            const cdfh = try Cdfh.newFromReader(allocator, &reader);
            defer cdfh.deinit();

            const next_cd_pos = reader.seek;

            reader.seek = cdfh.base.lfh_offset;
            try reader.readSliceAll(&sig_buf);
            if (std.mem.readInt(u32, &sig_buf, .little) != Constants.ZipConstants.LFH_SIGNATURE) return error.InvalidZipArchive;

            const lfh = try Lfh.newFromReader(allocator, &reader);
            defer lfh.deinit();

            const entry = try ZipEntry.init(allocator, cdfh, lfh, offset);
            try entries.append(allocator, entry);

            offset += @as(u32, @intCast(Constants.ZipConstants.CDHF_SIZE_NOV)) + cdfh.base.name_len + cdfh.base.extra_len + cdfh.base.comment_len;

            reader.seek = next_cd_pos;
        }

        return ZipArchive{
            .data = data,
            .allocator = allocator,
            .eocd = eocd,
            .entries = entries,
        };
    }

    pub fn deinit(self: *ZipArchive) void {
        self.eocd.deinit();
        for (self.entries.items) |*e| {
            e.deinit();
        }
        self.entries.deinit(self.allocator);
    }
};

fn findEocd(data: []const u8) !u64 {
    const min_eocd_size = Constants.ZipConstants.EOCD_SIZE_NOV;
    if (data.len < min_eocd_size) return error.InvalidZipArchive;

    const max_comment = Constants.ZipConstants.MAX_COMMENT_SIZE;
    const search_len = @min(data.len, max_comment + min_eocd_size);
    const start_search = data.len - search_len;

    var i: usize = data.len - min_eocd_size;
    while (i >= start_search) : (i -= 1) {
        if (std.mem.readInt(u32, data[i..][0..4], .little) == Constants.ZipConstants.EOCD_SIGNATURE) {
            return i;
        }
        if (i == 0) break;
    }
    return error.InvalidZipArchive;
}

pub const CompressionMethod = enum(u16) {
    Store = 0,
    Deflate = 8,
    _,
};

pub const ZipEntry = struct {
    name: []u8,
    compression: CompressionMethod,
    comp_size: u32,
    uncomp_size: u32,
    crc32: u32,
    lfh_offset: u32,
    data_offset: u32,
    allocator: Allocator,

    pub fn init(allocator: Allocator, cd: Cdfh, lfh: Lfh, offset: u32) !ZipEntry {
        _ = offset;
        const data_offset: u32 = @intCast(cd.base.lfh_offset + Constants.ZipConstants.LFH_SIZE_NOV + lfh.base.name_len + lfh.base.extra_len);

        return ZipEntry{
            .name = try allocator.dupe(u8, cd.name),
            .compression = @fromBackingInt(@intCast(cd.base.compression)),
            .comp_size = cd.base.comp_size,
            .uncomp_size = cd.base.uncomp_size,
            .crc32 = cd.base.crc32,
            .lfh_offset = cd.base.lfh_offset,
            .data_offset = data_offset,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ZipEntry) void {
        self.allocator.free(self.name);
    }

    pub fn extract(self: ZipEntry, allocator: Allocator, archive_data: []const u8) ![]u8 {
        if (self.data_offset + self.comp_size > archive_data.len) return error.InvalidZipArchive;
        const comp_data = archive_data[self.data_offset..][0..self.comp_size];

        switch (self.compression) {
            .Store => {
                if (comp_data.len != self.uncomp_size) return error.ZipUncompressSizeMismatch;
                return allocator.dupe(u8, comp_data);
            },
            .Deflate => {
                return deflate.decompress(allocator, comp_data, .{});
            },
            else => return error.UnsupportedCompressionMethod,
        }
    }
};

/// Default entry name used by one-shot `compress`.
pub const default_entry_name = "payload.bin";

/// A single ZIP archive member for `pack`. `data` is borrowed.
pub const ZipEntryData = struct {
    name: []const u8,
    data: []const u8,
    method: CompressionMethod = .Deflate,
};

/// An owned extracted member returned by `unpackAll`.
pub const OwnedZipEntry = struct {
    name: []u8,
    data: []u8,
    allocator: Allocator,

    pub fn deinit(self: *OwnedZipEntry) void {
        self.allocator.free(self.name);
        self.allocator.free(self.data);
    }
};

pub fn freeUnpacked(allocator: Allocator, entries: []OwnedZipEntry) void {
    for (entries) |*e| e.deinit();
    allocator.free(entries);
}

fn writeU16(buf: *ArrayList(u8), allocator: Allocator, v: u16) !void {
    try buf.appendSlice(allocator, &std.mem.toBytes(v));
}

fn writeU32(buf: *ArrayList(u8), allocator: Allocator, v: u32) !void {
    try buf.appendSlice(allocator, &std.mem.toBytes(v));
}

/// Packs `entries` into a real ZIP archive (local headers + central
/// directory + EOCD) using store or deflate per entry.
/// The caller owns the returned bytes.
pub fn pack(allocator: Allocator, entries: []const ZipEntryData, options: config.Options) ![]u8 {
    if (entries.len > std.math.maxInt(u16)) return error.OutputTooLarge;
    var out: ArrayList(u8) = .empty;
    errdefer out.deinit(allocator);

    var central: ArrayList(u8) = .empty;
    defer central.deinit(allocator);

    for (entries) |entry| {
        if (entry.name.len == 0 or entry.name.len > std.math.maxInt(u16)) return error.InvalidZipArchive;
        if (!utils.isPathSafe(entry.name)) return error.InvalidZipArchive;
        if (entry.data.len > std.math.maxInt(u32)) return error.OutputTooLarge;

        const crc = utils.calculateCRC32(entry.data);
        const payload: []const u8 = payload_blk: {
            if (entry.method == .Store or entry.data.len == 0) break :payload_blk entry.data;
            break :payload_blk try deflate.compress(allocator, entry.data, options);
        };
        defer if (payload.ptr != entry.data.ptr) allocator.free(payload);
        const method: u16 = if (payload.ptr == entry.data.ptr and entry.method == .Store) 0 else if (payload.ptr == entry.data.ptr) 0 else 8;
        const actual_method: u16 = if (entry.data.len == 0) 0 else if (entry.method == .Store) 0 else 8;

        const lfh_offset: u32 = @intCast(out.items.len);
        try writeU32(&out, allocator, Constants.ZipConstants.LFH_SIGNATURE);
        try writeU16(&out, allocator, 20); // version needed
        try writeU16(&out, allocator, 0); // flags
        try writeU16(&out, allocator, actual_method);
        try writeU16(&out, allocator, 0); // mod time
        try writeU16(&out, allocator, 0x21); // mod date (1980-01-01)
        try writeU32(&out, allocator, crc);
        try writeU32(&out, allocator, @intCast(payload.len));
        try writeU32(&out, allocator, @intCast(entry.data.len));
        try writeU16(&out, allocator, @intCast(entry.name.len));
        try writeU16(&out, allocator, 0); // extra len
        try out.appendSlice(allocator, entry.name);
        try out.appendSlice(allocator, payload);
        _ = method;

        try writeU32(&central, allocator, Constants.ZipConstants.CDFH_SIGNATURE);
        try writeU16(&central, allocator, 20); // made by
        try writeU16(&central, allocator, 20); // extract version
        try writeU16(&central, allocator, 0); // flags
        try writeU16(&central, allocator, actual_method);
        try writeU16(&central, allocator, 0); // mod time
        try writeU16(&central, allocator, 0x21); // mod date
        try writeU32(&central, allocator, crc);
        try writeU32(&central, allocator, @intCast(payload.len));
        try writeU32(&central, allocator, @intCast(entry.data.len));
        try writeU16(&central, allocator, @intCast(entry.name.len));
        try writeU16(&central, allocator, 0); // extra len
        try writeU16(&central, allocator, 0); // comment len
        try writeU16(&central, allocator, 0); // disk
        try writeU16(&central, allocator, 0); // int attrs
        try writeU32(&central, allocator, 0); // ext attrs
        try writeU32(&central, allocator, lfh_offset);
        try central.appendSlice(allocator, entry.name);
    }

    const cd_offset: u32 = @intCast(out.items.len);
    const cd_size: u32 = @intCast(central.items.len);
    try out.appendSlice(allocator, central.items);

    try writeU32(&out, allocator, Constants.ZipConstants.EOCD_SIGNATURE);
    try writeU16(&out, allocator, 0); // disk
    try writeU16(&out, allocator, 0); // cd disk
    try writeU16(&out, allocator, @intCast(entries.len));
    try writeU16(&out, allocator, @intCast(entries.len));
    try writeU32(&out, allocator, cd_size);
    try writeU32(&out, allocator, cd_offset);
    try writeU16(&out, allocator, 0); // comment len

    return out.toOwnedSlice(allocator);
}

/// Extracts every entry of a ZIP archive. The caller owns the entries;
/// release with `freeUnpacked`.
pub fn unpackAll(allocator: Allocator, data: []const u8) ![]OwnedZipEntry {
    var archive = try ZipArchive.init(allocator, data);
    defer archive.deinit();

    var out: ArrayList(OwnedZipEntry) = .empty;
    errdefer {
        for (out.items) |*e| e.deinit();
        out.deinit(allocator);
    }

    for (archive.entries.items) |entry| {
        const raw = try entry.extract(allocator, data);
        defer allocator.free(raw);
        const name = try allocator.dupe(u8, entry.name);
        errdefer allocator.free(name);
        const owned_data = try allocator.dupe(u8, raw);
        errdefer allocator.free(owned_data);
        // Verify CRC32 of the extracted payload.
        if (utils.calculateCRC32(owned_data) != entry.crc32) return error.ChecksumMismatch;
        try out.append(allocator, .{ .name = name, .data = owned_data, .allocator = allocator });
    }

    return out.toOwnedSlice(allocator);
}

/// One-shot compression: packs `data` as a single ZIP entry named
/// `default_entry_name` using deflate. The caller owns the returned bytes.
pub fn compress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    return pack(allocator, &.{.{ .name = default_entry_name, .data = data }}, options);
}

/// One-shot decompression: parses a ZIP archive and returns the payload of
/// its single entry. Archives with zero entries yield an empty slice;
/// archives with more than one entry report `error.InvalidZipArchive`
/// (use `unpackAll` for multi-entry archives).
/// The caller owns the returned bytes.
pub fn decompress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    _ = options;
    if (data.len == 0) return error.InvalidZipArchive;
    const entries = try unpackAll(allocator, data);
    defer freeUnpacked(allocator, entries);
    if (entries.len == 0) return allocator.alloc(u8, 0);
    if (entries.len != 1) return error.InvalidZipArchive;
    return allocator.dupe(u8, entries[0].data) catch error.OutOfMemory;
}

test "zip roundtrip" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const input = "Hello, World! This is a zip test.";
    const compressed = try compress(allocator, input, .{});
    defer allocator.free(compressed);
    // Must be a real ZIP archive, not a raw deflate stream.
    try testing.expect(std.mem.indexOf(u8, compressed, "payload.bin") != null);
    const decompressed = try decompress(allocator, compressed, .{});
    defer allocator.free(decompressed);
    try testing.expectEqualStrings(input, decompressed);
}

test "zip multi entry pack unpack" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const entries = [_]ZipEntryData{
        .{ .name = "a.txt", .data = "first" },
        .{ .name = "b.txt", .data = "second file contents", .method = .Store },
    };
    const archive_bytes = try pack(allocator, &entries, .{});
    defer allocator.free(archive_bytes);
    const parsed = try unpackAll(allocator, archive_bytes);
    defer freeUnpacked(allocator, parsed);
    try testing.expect(parsed.len == 2);
    try testing.expectEqualStrings("a.txt", parsed[0].name);
    try testing.expectEqualStrings("first", parsed[0].data);
    try testing.expectEqualStrings("b.txt", parsed[1].name);
    try testing.expectEqualStrings("second file contents", parsed[1].data);
    try testing.expectError(error.InvalidZipArchive, decompress(allocator, archive_bytes, .{}));
}

test "zip rejects corrupt input" {
    const testing = std.testing;
    const bad = [_]u8{ 0x50, 0x4b, 0x03, 0x04, 0x00 };
    try testing.expectError(error.InvalidZipArchive, unpackAll(testing.allocator, &bad));
}

test "zip std Iterator interop" {
    // Archives built with our `pack` must iterate and extract with
    // `std.zip.Iterator`, proving the headers are genuine ZIP records.
    const testing = std.testing;
    const allocator = testing.allocator;
    const io = testing.io;

    var tmp = testing.tmpDir(.{});
    defer tmp.cleanup();

    const entries = [_]ZipEntryData{
        .{ .name = "hello.txt", .data = "Hello, std.zip!" },
        .{ .name = "blob.bin", .data = "binary\x00payload\xffhere", .method = .Store },
    };
    const archive_bytes = try pack(allocator, &entries, .{});
    defer allocator.free(archive_bytes);

    try tmp.dir.writeFile(io, .{ .sub_path = "test.zip", .data = archive_bytes });

    var file = try tmp.dir.openFile(io, "test.zip", .{});
    defer file.close(io);
    var read_buf: [512]u8 = undefined;
    var reader = file.reader(io, &read_buf);

    var it = try std.zip.Iterator.init(&reader);
    var count: usize = 0;
    while (try it.next()) |entry| {
        try testing.expect(count < entries.len);
        var filename_buf: [256]u8 = undefined;
        const filename = try entry.getFilename(&reader, &filename_buf, .{});
        try testing.expectEqualStrings(entries[count].name, filename);
        try testing.expect(entry.uncompressed_size == entries[count].data.len);
        var out_buf: [256]u8 = undefined;
        var w: std.Io.Writer = .fixed(&out_buf);
        try entry.extractTo(&reader, &w);
        try testing.expectEqualSlices(u8, entries[count].data, w.buffered());
        count += 1;
    }
    try testing.expect(count == entries.len);
}
