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

            offset += Constants.ZipConstants.CDHF_SIZE_NOV + cdfh.base.name_len + cdfh.base.extra_len + cdfh.base.comment_len;

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
        const data_offset = cd.base.lfh_offset + Constants.ZipConstants.LFH_SIZE_NOV + lfh.base.name_len + lfh.base.extra_len;

        return ZipEntry{
            .name = try allocator.dupe(u8, cd.name),
            .compression = @enumFromInt(cd.base.compression),
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

pub fn compress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    return deflate.compress(allocator, data, options);
}

pub fn decompress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    return deflate.decompress(allocator, data, options);
}

test "zip roundtrip" {
    const testing = std.testing;
    const allocator = testing.allocator;
    const input = "Hello, World! This is a zip test.";
    const compressed = try compress(allocator, input, .{});
    defer allocator.free(compressed);
    const decompressed = try decompress(allocator, compressed, .{});
    defer allocator.free(decompressed);
    try testing.expectEqualStrings(input, decompressed);
}
