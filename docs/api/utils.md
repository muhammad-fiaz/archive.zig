---
title: Utils API
---

# Utils API

The `utils.zig` module provides standalone helper functions for size parsing, hashing, glob matching, path utilities, and compression helpers.

## Size Utilities

### `parseSize`

```zig
pub fn parseSize(s: []const u8) ?u64
```

Parses a human-readable size string (e.g., `"1KB"`, `"512MB"`, `"2GB"`) into bytes. Returns `null` on failure.

### `writeSize`

```zig
pub fn writeSize(writer: anytype, bytes: u64) !void
```

Writes a byte count in human-readable form (e.g., `"1.50 KB"`) to the given writer.

### `formatSize`

```zig
pub fn formatSize(allocator: std.mem.Allocator, bytes: u64) ![]u8
```

Returns a heap-allocated human-readable size string.

## Time Utilities

### `parseDuration`

```zig
pub fn parseDuration(s: []const u8) ?i64
```

Parses a duration string (e.g., `"100ms"`, `"5s"`, `"10m"`, `"2h"`, `"1d"`) into milliseconds. Returns `null` on failure.

### `currentNanos`

```zig
pub fn currentNanos() i128
```

Returns the current timestamp in nanoseconds.

### `currentMillis`

```zig
pub fn currentMillis() i64
```

Returns the current timestamp in milliseconds.

## Atomic / Math Utilities

### `atomicLoadU64`

```zig
pub fn atomicLoadU64(atomic: anytype) u64
```

Performs a monotonic atomic load on a `u64` atomic.

### `calculateErrorRate`

```zig
pub fn calculateErrorRate(errors: u64, total: u64) f64
```

Returns `errors / total`, or `0.0` if `total` is zero.

## Hashing / Checksums

### `calculateCRC32`

```zig
pub fn calculateCRC32(data: []const u8) u32
```

Returns the CRC32 checksum of the input data.

### `lzmaHash`

```zig
pub fn lzmaHash(data: []const u8, len: usize) u32
```

Computes a simple hash used by the LZMA backend.

### `lz4Hash`

```zig
pub fn lz4Hash(data: *const [4]u8) u32
```

Computes a 4-byte hash used by the LZ4 backend.

### `calculateXXHash`

```zig
pub fn calculateXXHash(data: []const u8) u32
```

Computes a simple XXHash-like hash of the input data.

## Glob Matching

### `matchGlob`

```zig
pub fn matchGlob(name: []const u8, pattern: []const u8) bool
```

Case-sensitive glob match. Supports `*`, `**`, and `?` wildcards.

### `matchGlobIgnoreCase`

```zig
pub fn matchGlobIgnoreCase(name: []const u8, pattern: []const u8) bool
```

Case-insensitive glob match.

### `matchGlobWithCase`

```zig
pub fn matchGlobWithCase(name: []const u8, pattern: []const u8, case_sensitive: bool) bool
```

Glob match with explicit case sensitivity control.

### `globMatchAdvanced`

```zig
pub fn globMatchAdvanced(text: []const u8, pattern: []const u8, case_sensitive: bool) bool
```

Full glob matcher supporting `*`, `?`, and `**` patterns.

### `shouldIncludePath`

```zig
pub fn shouldIncludePath(path: []const u8, include_patterns: []const []const u8, exclude_patterns: []const []const u8) bool
```

Returns `true` if `path` matches include patterns and does not match exclude patterns. Case-insensitive.

### `shouldIncludePathWithCase`

```zig
pub fn shouldIncludePathWithCase(path: []const u8, include_patterns: []const []const u8, exclude_patterns: []const []const u8, case_sensitive: bool) bool
```

Same as `shouldIncludePath` with explicit case sensitivity.

## Path Utilities

### `isPathSafe`

```zig
pub fn isPathSafe(path: []const u8) bool
```

Returns `false` if the path contains directory traversal (`..`, `//`, `\\`).

### `normalizePathSeparators`

```zig
pub fn normalizePathSeparators(allocator: std.mem.Allocator, path: []const u8) ![]u8
```

Replaces backslashes with forward slashes.

### `getFileExtension`

```zig
pub fn getFileExtension(path: []const u8) []const u8
```

Returns the file extension including the dot (e.g., `".zig"`), or `""` if none.

### `hasExtension`

```zig
pub fn hasExtension(path: []const u8, extensions: []const []const u8) bool
```

Checks if the path has any of the given extensions (case-insensitive).

### `isCompressedFile`

```zig
pub fn isCompressedFile(path: []const u8) bool
```

Returns `true` if the path has a known compressed file extension (`.gz`, `.xz`, `.zst`, `.lz4`, `.zip`, `.rar`, `.7z`, etc.).

### `getBasename`

```zig
pub fn getBasename(path: []const u8) []const u8
```

Returns the filename portion of a path (after the last `/` or `\`).

### `getDirname`

```zig
pub fn getDirname(path: []const u8) []const u8
```

Returns the directory portion of a path (before the last `/` or `\`).

## Compression Helpers

### `validateCompressionLevel`

```zig
pub fn validateCompressionLevel(algorithm: u8, level: u8) bool
```

Returns `true` if the given level is valid for the algorithm.

### `getOptimalBufferSize`

```zig
pub fn getOptimalBufferSize(file_size: u64, algorithm: u8) usize
```

Returns a recommended buffer size based on file size and algorithm.

### `estimateCompressionRatio`

```zig
pub fn estimateCompressionRatio(algorithm: u8, level: u8, data_type: u8) f64
```

Estimates the compression ratio for the given algorithm, level, and data type.

### `calculateOptimalThreads`

```zig
pub fn calculateOptimalThreads(file_size: u64, available_cores: u32) u32
```

Returns the recommended thread count based on file size and available cores.

### `copyMatchData`

```zig
pub fn copyMatchData(result: *std.ArrayList(u8), allocator: std.mem.Allocator, offset: usize, length: usize) !void
```

Copies repeated match data (used in LZ backends) into the result buffer.

### `writeVariableLength`

```zig
pub fn writeVariableLength(result: *std.ArrayList(u8), allocator: std.mem.Allocator, value: usize) !void
```

Writes a variable-length encoded value.

### `readVariableLength`

```zig
pub fn readVariableLength(data: []const u8, pos: *usize) !usize
```

Reads a variable-length encoded value from `data` at position `pos`.

### `validateCompressionRatio`

```zig
pub fn validateCompressionRatio(original_size: usize, compressed_size: usize, max_ratio: f64) bool
```

Returns `true` if the ratio of compressed to original size is within `max_ratio`.

### `formatCompressionRatio`

```zig
pub fn formatCompressionRatio(original_size: usize, compressed_size: usize) f64
```

Returns the compression ratio as a percentage (compressed / original * 100).

## Examples

### Size Parsing

```zig
const size = archive.utils.parseSize("512KB");
// Returns 524288

const formatted = try archive.utils.formatSize(allocator, 1048576);
defer allocator.free(formatted);
// Returns "1.00 MB"
```

### Glob Matching

```zig
if (archive.utils.matchGlob("src/main.zig", "src/*.zig")) {
    std.debug.print("Matched!\n", .{});
}

if (archive.utils.isCompressedFile("backup.tar.gz")) {
    std.debug.print("Already compressed\n", .{});
}
```

### Path Safety

```zig
if (!archive.utils.isPathSafe("../../../etc/passwd")) {
    std.debug.print("Unsafe path detected\n", .{});
}
```
