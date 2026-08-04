---
title: Errors API
---

# Errors API

The `errors.zig` module defines a single unified error set and a formatting function.

## CompressError

```zig
pub const CompressError = error{
    UnsupportedAlgorithm,
    UnsupportedAlgorithmForDirectory,
    InvalidData,
    CorruptedStream,
    OutOfMemory,
    InternalFailure,
    ChecksumMismatch,
    OutputTooLarge,
    InvalidMagic,
    InvalidOffset,
    InvalidZipArchive,
    UnsupportedZipCompressionMethod,
    InvalidTarArchive,
    InvalidLzmaHeader,
    UnsupportedLzma2Chunk,
    ZstdError,
    FileNotFound,
    PermissionDenied,
    ExcludedByPattern,
    EmptyInput,
    ReadFailed,
    WriteFailed,
    EndOfStream,
};
```

Every function in the library returns errors from this set.

## formatError

```zig
pub fn formatError(err: CompressError) []const u8
```

Returns a human-readable description string for the given error.

**Example:**
```zig
const msg = archive.errors.formatError(error.InvalidData);
std.debug.print("{s}\n", .{msg});
// Output: "Invalid or corrupted data"
```

## Error Reference

| Error | Description |
|-------|-------------|
| `UnsupportedAlgorithm` | Algorithm not available or not recognized |
| `UnsupportedAlgorithmForDirectory` | Algorithm doesn't support directory compression (e.g., not tar_gz/zip) |
| `InvalidData` | Input data is malformed |
| `CorruptedStream` | Data stream is corrupted |
| `OutOfMemory` | Allocation failure |
| `InternalFailure` | Internal compression backend error |
| `ChecksumMismatch` | Verification checksum does not match |
| `OutputTooLarge` | Output exceeds size limits |
| `InvalidMagic` | File magic bytes don't match expected format |
| `InvalidOffset` | Invalid back-reference offset in compressed data |
| `InvalidZipArchive` | ZIP format is malformed |
| `UnsupportedZipCompressionMethod` | ZIP uses an unsupported compression method |
| `InvalidTarArchive` | TAR format is malformed |
| `InvalidLzmaHeader` | LZMA header is invalid |
| `UnsupportedLzma2Chunk` | LZMA2 chunk type not supported |
| `ZstdError` | Zstandard backend error |
| `FileNotFound` | File does not exist |
| `PermissionDenied` | Insufficient permissions |
| `ExcludedByPattern` | Path was excluded by a filter pattern |
| `EmptyInput` | Input data was empty |
| `ReadFailed` | Read operation failed |
| `WriteFailed` | Write operation failed |
| `EndOfStream` | Unexpected end of stream |

## Usage Example

```zig
const compressed = archive.compress(allocator, data, .gzip) catch |err| switch (err) {
    error.OutOfMemory => {
        std.debug.print("Not enough memory\n", .{});
        return err;
    },
    error.InvalidData => {
        std.debug.print("Invalid input data\n", .{});
        return err;
    },
    else => {
        std.debug.print("Error: {s}\n", .{archive.errors.formatError(err)});
        return err;
    },
};
```
