---
title: Archive API
---

# Archive API

The main `archive.zig` module provides free functions, an `Archive` struct, and a `Compressor` struct for compression and decompression.

## Free Functions

### `detectFormat`

```zig
pub fn detectFormat(data: []const u8) Algorithm
```

Detects the compression algorithm from data magic bytes. Returns `.none` if the format cannot be identified.

**Parameters:**
- `data`: Input data to inspect

**Returns:** Detected `Algorithm` variant

**Example:**
```zig
const algo = archive.detectFormat(compressed_data);
switch (algo) {
    .gzip => std.debug.print("Gzip\n", .{}),
    .zstd => std.debug.print("Zstd\n", .{}),
    else => {},
}
```

### `compress`

```zig
pub fn compress(allocator: std.mem.Allocator, data: []const u8, algorithm: Algorithm) ![]u8
```

Compresses data using the specified algorithm with default settings.

**Parameters:**
- `allocator`: Memory allocator
- `data`: Input data to compress
- `algorithm`: Compression algorithm to use

**Returns:** Compressed data (caller owns memory)

**Example:**
```zig
const compressed = try archive.compress(allocator, "Hello, World!", .gzip);
defer allocator.free(compressed);
```

### `decompress`

```zig
pub fn decompress(allocator: std.mem.Allocator, data: []const u8, algorithm: Algorithm) ![]u8
```

Decompresses data using the specified algorithm.

**Parameters:**
- `allocator`: Memory allocator
- `data`: Compressed data to decompress
- `algorithm`: Algorithm used for compression

**Returns:** Decompressed data (caller owns memory)

**Example:**
```zig
const decompressed = try archive.decompress(allocator, compressed_data, .gzip);
defer allocator.free(decompressed);
```

### `compressWithConfig`

```zig
pub fn compressWithConfig(allocator: std.mem.Allocator, data: []const u8, cfg: CompressionConfig) ![]u8
```

Compresses data with custom configuration.

**Parameters:**
- `allocator`: Memory allocator
- `data`: Input data to compress
- `cfg`: Compression configuration

**Returns:** Compressed data (caller owns memory)

**Example:**
```zig
const cfg = archive.CompressionConfig.init(.zstd).withZstdLevel(10);
const compressed = try archive.compressWithConfig(allocator, data, cfg);
defer allocator.free(compressed);
```

### `detectAlgorithm`

```zig
pub fn detectAlgorithm(data: []const u8) ?Algorithm
```

Automatically detects the compression algorithm from data headers. Returns `null` if the algorithm is `.none` or unknown.

**Parameters:**
- `data`: Compressed data

**Returns:** Detected algorithm or `null`

**Example:**
```zig
if (archive.detectAlgorithm(compressed_data)) |algo| {
    std.debug.print("Detected: {s}\n", .{@tagName(algo)});
}
```

### `autoDecompress`

```zig
pub fn autoDecompress(allocator: std.mem.Allocator, data: []const u8) ![]u8
```

Automatically detects algorithm and decompresses data.

**Parameters:**
- `allocator`: Memory allocator
- `data`: Compressed data

**Returns:** Decompressed data (caller owns memory)

**Example:**
```zig
const decompressed = try archive.autoDecompress(allocator, compressed_data);
defer allocator.free(decompressed);
```

## Archive Struct

```zig
pub const Archive = struct {
    allocator: std.mem.Allocator,
    cfg: CompressionConfig,

    pub fn init(allocator: std.mem.Allocator, cfg: CompressionConfig) Archive
    pub fn deinit(self: *Archive) void
    pub fn compress(self: *Archive, data: []const u8) ![]u8
    pub fn decompress(self: *Archive, data: []const u8) ![]u8
};
```

### `init`

```zig
pub fn init(allocator: std.mem.Allocator, cfg: CompressionConfig) Archive
```

Creates a new `Archive` with the given allocator and configuration.

### `deinit`

```zig
pub fn deinit(self: *Archive) void
```

Cleans up the archive (currently a no-op, but should be called for forward compatibility).

### `compress`

```zig
pub fn compress(self: *Archive, data: []const u8) ![]u8
```

Compresses data using the archive's configured algorithm and settings.

### `decompress`

```zig
pub fn decompress(self: *Archive, data: []const u8) ![]u8
```

Decompresses data by auto-detecting the format from the data header.

### Usage Example

```zig
const std = @import("std");
const archive = @import("archive");

pub fn archiveExample(allocator: std.mem.Allocator) !void {
    const cfg = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(10)
        .withChecksum();

    var arch = archive.Archive.init(allocator, cfg);
    defer arch.deinit();

    const compressed = try arch.compress("Data to compress");
    defer allocator.free(compressed);

    const decompressed = try arch.decompress(compressed);
    defer allocator.free(decompressed);
}
```

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

A builder-style interface for one-off compress/decompress operations.

### `init`

```zig
pub fn init(allocator: std.mem.Allocator, algorithm: Algorithm) Compressor
```

Creates a new `Compressor` for the given algorithm.

### `withLevel`

```zig
pub fn withLevel(self: Compressor, level: u8) Compressor
```

Sets the compression level (0–9 for most algorithms).

### `withZstdLevel`

```zig
pub fn withZstdLevel(self: Compressor, level: c_int) Compressor
```

Sets the Zstandard-specific compression level (1–22).

### `withChecksum`

```zig
pub fn withChecksum(self: Compressor) Compressor
```

Enables checksum verification.

### `compress_data`

```zig
pub fn compress_data(self: Compressor, data: []const u8) ![]u8
```

Compresses data using the configured settings.

### `decompress_data`

```zig
pub fn decompress_data(self: Compressor, data: []const u8) ![]u8
```

Decompresses data by auto-detecting the format.

### Compressor Example

```zig
const compressor = archive.Compressor.init(allocator, .zstd)
    .withZstdLevel(15)
    .withChecksum();

const compressed = try compressor.compress_data("Hello, World!");
defer allocator.free(compressed);

const decompressed = try compressor.decompress_data(compressed);
defer allocator.free(decompressed);
```

## Error Handling

All functions return `CompressError` for various failure conditions. See [Errors](./errors.md) for the full error set.
