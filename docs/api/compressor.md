---
title: Compressor API
---

# Compressor API

The `Compressor` struct provides a builder-style interface for quick compression and decompression operations without managing `Archive` lifecycle.

## Compressor Struct

```zig
pub const Compressor = struct {
    allocator: std.mem.Allocator,
    algorithm: Algorithm,
    level: ?u8 = null,
    zstd_level: ?c_int = null,
    checksum: bool = false,

    pub fn init(allocator: std.mem.Allocator, algorithm: Algorithm) Compressor
    pub fn withLevel(self: Compressor, level: u8) Compressor
    pub fn withZstdLevel(self: Compressor, level: c_int) Compressor
    pub fn withChecksum(self: Compressor) Compressor
    pub fn compress_data(self: Compressor, data: []const u8) ![]u8
    pub fn decompress_data(self: Compressor, data: []const u8) ![]u8
};
```

## Methods

### `init`

```zig
pub fn init(allocator: std.mem.Allocator, algorithm: Algorithm) Compressor
```

Creates a new `Compressor` with the given allocator and algorithm. Level, zstd_level, and checksum use their defaults.

### `withLevel`

```zig
pub fn withLevel(self: Compressor, level: u8) Compressor
```

Returns a copy with the compression level set. The level is clamped to the algorithm's valid range.

### `withZstdLevel`

```zig
pub fn withZstdLevel(self: Compressor, level: c_int) Compressor
```

Returns a copy with the Zstandard-specific level set (1–22).

### `withChecksum`

```zig
pub fn withChecksum(self: Compressor) Compressor
```

Returns a copy with checksum verification enabled.

### `compress_data`

```zig
pub fn compress_data(self: Compressor, data: []const u8) ![]u8
```

Compresses the input data. Internally builds a `CompressionConfig` from the stored settings and delegates to `compressWithConfig`.

### `decompress_data`

```zig
pub fn decompress_data(self: Compressor, data: []const u8) ![]u8
```

Decompresses data by auto-detecting the format from the data header.

## Examples

### Basic Compression

```zig
const archive = @import("archive");

pub fn basicExample(allocator: std.mem.Allocator) !void {
    const compressor = archive.Compressor.init(allocator, .gzip)
        .withLevel(9);

    const compressed = try compressor.compress_data("Hello, World!");
    defer allocator.free(compressed);

    const decompressed = try compressor.decompress_data(compressed);
    defer allocator.free(decompressed);
}
```

### Zstd with Custom Level

```zig
pub fn zstdExample(allocator: std.mem.Allocator) !void {
    const compressor = archive.Compressor.init(allocator, .zstd)
        .withZstdLevel(15)
        .withChecksum();

    const data = "Repetitive data for high compression " ** 100;

    const compressed = try compressor.compress_data(data);
    defer allocator.free(compressed);

    const decompressed = try compressor.decompress_data(compressed);
    defer allocator.free(decompressed);
}
```

### Comparing Algorithms

```zig
pub fn compareAlgorithms(allocator: std.mem.Allocator, data: []const u8) !void {
    const algorithms = [_]archive.Algorithm{ .lz4, .gzip, .zstd, .lzma };

    for (algorithms) |algo| {
        const compressor = archive.Compressor.init(allocator, algo);
        const compressed = try compressor.compress_data(data);
        defer allocator.free(compressed);

        std.debug.print("{s}: {d} -> {d} bytes\n", .{
            @tagName(algo),
            data.len,
            compressed.len,
        });
    }
}
```

## Error Handling

Both `compress_data` and `decompress_data` return `CompressError`. Common errors:

- `OutOfMemory` – allocation failure
- `UnsupportedAlgorithm` – algorithm not available
- `InvalidData` – corrupt or invalid input
- `CompressionFailed` / `DecompressionFailed` – backend error

```zig
const compressed = compressor.compress_data(data) catch |err| switch (err) {
    error.OutOfMemory => {
        std.debug.print("Out of memory\n", .{});
        return err;
    },
    else => return err,
};
```

## Best Practices

1. **Reuse compressors** – Create once, call `compress_data`/`decompress_data` multiple times
2. **Use `withChecksum`** when data integrity matters
3. **Use `withZstdLevel`** for Zstd-specific tuning instead of `withLevel`
4. For file operations or repeated use with the same config, prefer [Archive](./archive.md)
5. For streaming large data, see [Stream](./stream.md)

## Next Steps

- [Archive](./archive.md) – File operations and `Archive` struct
- [Stream](./stream.md) – Streaming compression/decompression
- [Config](./config.md) – Full configuration options
- [Algorithm](./algorithm.md) – Algorithm selection guide
