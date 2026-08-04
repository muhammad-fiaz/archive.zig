---
title: Stream API
---

# Stream API

The Stream API provides `CompressStream` and `DecompressStream` for accumulating data in chunks and producing the final compressed/decompressed output.

## CompressStream

```zig
pub const CompressStream = struct {
    allocator: std.mem.Allocator,
    algorithm: Algorithm,
    level: Level,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator, algorithm: Algorithm, level: Level) !CompressStream
    pub fn deinit(self: *CompressStream) void
    pub fn write(self: *CompressStream, data: []const u8) !void
    pub fn finish(self: *CompressStream) ![]u8
};
```

### `init`

```zig
pub fn init(allocator: std.mem.Allocator, algorithm: Algorithm, level: Level) !CompressStream
```

Creates a new `CompressStream` that buffers data and compresses it when `finish` is called.

### `deinit`

```zig
pub fn deinit(self: *CompressStream) void
```

Frees the internal buffer.

### `write`

```zig
pub fn write(self: *CompressStream, data: []const u8) !void
```

Appends data to the internal buffer. Call multiple times to accumulate chunks.

### `finish`

```zig
pub fn finish(self: *CompressStream) ![]u8
```

Compresses all buffered data and returns the result. The caller owns the returned memory.

## DecompressStream

```zig
pub const DecompressStream = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),

    pub fn init(allocator: std.mem.Allocator) DecompressStream
    pub fn deinit(self: *DecompressStream) void
    pub fn write(self: *DecompressStream, data: []const u8) !void
    pub fn finish(self: *DecompressStream) ![]u8
};
```

### `init`

```zig
pub fn init(allocator: std.mem.Allocator) DecompressStream
```

Creates a new `DecompressStream`. The algorithm is auto-detected from the data header when `finish` is called.

### `deinit`

```zig
pub fn deinit(self: *DecompressStream) void
```

Frees the internal buffer.

### `write`

```zig
pub fn write(self: *DecompressStream, data: []const u8) !void
```

Appends compressed data to the internal buffer.

### `finish`

```zig
pub fn finish(self: *DecompressStream) ![]u8
```

Decompresses all buffered data, auto-detecting the format. Returns decompressed data.

## Examples

### Basic Stream Compression

```zig
const std = @import("std");
const archive = @import("archive");

pub fn streamExample(allocator: std.mem.Allocator) !void {
    var stream = try archive.stream.CompressStream.init(allocator, .gzip, .default);
    defer stream.deinit();

    try stream.write("First chunk of data ");
    try stream.write("Second chunk of data ");
    try stream.write("Final chunk");

    const compressed = try stream.finish();
    defer allocator.free(compressed);

    std.debug.print("Compressed: {d} bytes\n", .{compressed.len});
}
```

### Stream Decompression

```zig
pub fn decompressStreamExample(allocator: std.mem.Allocator, compressed: []const u8) !void {
    var stream = archive.stream.DecompressStream.init(allocator);
    defer stream.deinit();

    try stream.write(compressed);

    const decompressed = try stream.finish();
    defer allocator.free(decompressed);

    std.debug.print("Decompressed: {d} bytes\n", .{decompressed.len});
}
```

### Multi-Chunk Processing

```zig
pub fn multiChunkExample(allocator: std.mem.Allocator, chunks: []const []const u8) !void {
    var stream = try archive.stream.CompressStream.init(allocator, .zstd, .fast);
    defer stream.deinit();

    for (chunks) |chunk| {
        try stream.write(chunk);
    }

    const compressed = try stream.finish();
    defer allocator.free(compressed);
}
```

## Best Practices

1. **Buffer all data before finishing** – `CompressStream` accumulates input, then compresses in one pass
2. **Call `deinit`** – Always clean up to free the internal buffer
3. **Algorithm choice** – Pass the correct `Algorithm` to both `CompressStream.init` and `DecompressStream.init`
4. **Level selection** – Use `Level.default` unless you need specific tuning

## Next Steps

- [Compressor](./compressor.md) for one-shot compression
- [Archive](./archive.md) for file operations
- [Config](./config.md) for level and strategy details
