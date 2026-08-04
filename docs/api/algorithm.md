---
title: Algorithm API
---

# Algorithm API

The `Algorithm` enum defines all supported compression algorithms in Archive.zig.

## Algorithm Enum

```zig
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
};
```

## Methods

### `extension`

```zig
pub fn extension(self: Algorithm) []const u8
```

Returns the standard file extension (e.g., `".gz"`, `".zst"`).

### `supportsDirectory`

```zig
pub fn supportsDirectory(self: Algorithm) bool
```

Returns `true` only for `.tar_gz` and `.zip`.

### `getDefaultLevel`

```zig
pub fn getDefaultLevel(self: Algorithm) u8
```

Returns the default compression level for the algorithm.

### `getMaxLevel`

```zig
pub fn getMaxLevel(self: Algorithm) u8
```

Returns the maximum compression level.

### `getMinLevel`

```zig
pub fn getMinLevel(self: Algorithm) u8
```

Returns the minimum compression level.

## Algorithm Details

### `none`

Passthrough — copies data unchanged. Level 0.

### `deflate`

Raw DEFLATE compression (no headers/checksums).

- **Extension:** `.deflate`
- **Levels:** 1–9 (default 6)
- **Best for:** Embedded in other formats, HTTP compression

### `zlib`

DEFLATE with zlib wrapper and Adler32 checksum.

- **Extension:** `.zlib`
- **Magic Bytes:** `78 9C`
- **Levels:** 1–9 (default 6)
- **Best for:** PNG, protocols

### `raw_deflate`

Alias for `deflate` — raw DEFLATE stream.

- **Extension:** `.deflate`
- **Levels:** 1–9 (default 6)

### `gzip`

GNU zip format with CRC32 checksum.

- **Extension:** `.gz`
- **Magic Bytes:** `1F 8B`
- **Levels:** 1–9 (default 6)
- **Best for:** General purpose, web

### `zstd`

Zstandard — modern algorithm with excellent speed/ratio.

- **Extension:** `.zst`
- **Magic Bytes:** `28 B5 2F FD`
- **Levels:** 1–22 (default 3, ultra 20–22)
- **Best for:** General purpose, real-time, archival

### `lzma`

LZMA compression with high ratio.

- **Extension:** `.lzma`
- **Magic Bytes:** `5D 00 00`
- **Levels:** 1–9 (default 6)
- **Best for:** Archival storage

### `lzma2`

LZMA2 compression (used internally by XZ and some ZIP variants).

- **Extension:** `.lzma2`
- **Levels:** 1–9 (default 6)

### `xz`

XZ format using LZMA2.

- **Extension:** `.xz`
- **Magic Bytes:** `FD 37 7A 58 5A 00`
- **Levels:** 1–9 (default 6)
- **Best for:** Linux distribution packaging

### `tar_gz`

TAR archive with gzip compression.

- **Extension:** `.tar.gz`
- **Levels:** 1–9 (default 6)
- **Best for:** Multi-file archives

### `zip`

ZIP archive format.

- **Extension:** `.zip`
- **Magic Bytes:** `50 4B 03 04`
- **Levels:** 1–9 (default 6)
- **Best for:** Cross-platform archives

### `lz4`

LZ4 frame format — extremely fast.

- **Extension:** `.lz4`
- **Magic Bytes:** `04 22 4D 18`
- **Levels:** 1–12 (default 1)
- **Best for:** Real-time, low latency

### `brotli`

Brotli compression — modern algorithm optimized for web content.

- **Extension:** `.br`
- **Magic Bytes:** `CE B2 CF 81`
- **Levels:** 0–11 (default 6)
- **Best for:** Web content, HTTP compression

## Comparison Table

| Algorithm | Speed | Ratio | Levels | Use Case |
|-----------|-------|-------|--------|----------|
| `lz4` | Fastest | Low | 1–12 | Real-time |
| `deflate` | Fast | Medium | 1–9 | Web/HTTP |
| `gzip` | Fast | Medium | 1–9 | General |
| `zlib` | Fast | Medium | 1–9 | Protocols |
| `zstd` | Very Fast | High | 1–22 | Modern apps |
| `lzma` | Slow | Very High | 1–9 | Archival |
| `xz` | Slow | Very High | 1–9 | Distribution |
| `tar_gz` | Fast | Medium | 1–9 | Unix archives |
| `zip` | Fast | Medium | 1–9 | Cross-platform |
| `brotli` | Fast | High | 0–11 | Web/HTTP |

## Error Handling

```zig
const compressed = archive.compress(allocator, data, .zstd) catch |err| switch (err) {
    error.ZstdError => {
        std.debug.print("ZSTD-specific error\n", .{});
        return err;
    },
    error.UnsupportedAlgorithm => {
        std.debug.print("Algorithm not supported\n", .{});
        return err;
    },
    else => return err,
};
```

## Next Steps

- [Config](./config.md) – Algorithm-specific settings
- [Compressor](./compressor.md) – Builder-style compression
- [Constants](./constants.md) – Algorithm-specific constants
