const std = @import("std");
const config = @import("../config.zig");
const errors = @import("../errors.zig");
const flate = std.compress.flate;

fn levelToOptions(level: u8) flate.Compress.Options {
    return switch (@min(level, 9)) {
        1 => flate.Compress.Options.level_1,
        2 => flate.Compress.Options.level_2,
        3 => flate.Compress.Options.level_3,
        4 => flate.Compress.Options.level_4,
        5 => flate.Compress.Options.level_5,
        6 => flate.Compress.Options.level_6,
        7 => flate.Compress.Options.level_7,
        8 => flate.Compress.Options.level_8,
        9 => flate.Compress.Options.level_9,
        else => flate.Compress.Options.level_6,
    };
}

pub fn compress(allocator: std.mem.Allocator, data: []const u8, options: config.Options) ![]u8 {
    if (data.len == 0) return allocator.alloc(u8, 0);

    var output = std.Io.Writer.Allocating.init(allocator);
    defer output.deinit();
    try output.ensureTotalCapacity(flate.max_window_len + 16);

    var buf: [flate.max_window_len]u8 = undefined;
    var comp = flate.Compress.init(&output.writer, &buf, .gzip, levelToOptions(options.level orelse 6)) catch return errors.CompressError.InternalFailure;

    comp.writer.writeAll(data) catch return errors.CompressError.WriteFailed;
    comp.finish() catch return errors.CompressError.WriteFailed;

    return try output.toOwnedSlice();
}

pub fn decompress(allocator: std.mem.Allocator, data: []const u8, _: config.Options) ![]u8 {
    if (data.len == 0) return allocator.alloc(u8, 0);

    var output = std.Io.Writer.Allocating.init(allocator);
    defer output.deinit();

    var input = std.Io.Reader.fixed(data);
    var buf: [flate.max_window_len]u8 = undefined;
    var decomp = flate.Decompress.init(&input, .gzip, &buf);

    while (true) {
        _ = decomp.reader.stream(&output.writer, .unlimited) catch |err| switch (err) {
            error.EndOfStream => break,
            error.ReadFailed => return errors.CompressError.ReadFailed,
            error.WriteFailed => return errors.CompressError.WriteFailed,
        };
    }

    return try output.toOwnedSlice();
}

test "gzip compress and decompress" {
    const testing = std.testing;

    const data = "Hello, World! This is a test string for gzip compression.";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}

test "gzip empty data" {
    const testing = std.testing;

    const data = "";
    const compressed = try compress(testing.allocator, data, .{});
    defer testing.allocator.free(compressed);

    const decompressed = try decompress(testing.allocator, compressed, .{});
    defer testing.allocator.free(decompressed);

    try testing.expectEqualStrings(data, decompressed);
}
