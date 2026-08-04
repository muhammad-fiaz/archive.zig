---
title: Configuration API
---

# Configuration API

The Configuration API provides flexible, builder-style customization of compression settings through `CompressionConfig`, `Options`, and `StreamingOptions`.

## CompressionConfig

```zig
pub const CompressionConfig = struct {
    algorithm: Algorithm = .none,
    level: Level = .default,
    custom_level: ?u8 = null,
    zstd_level: ?c_int = null,
    lz4_level: ?c_int = null,
    extension: []const u8 = "",
    mode: CompressionMode = .compress,
    checksum: bool = false,
    verify_checksum: bool = true,
    keep_original: bool = false,
    overwrite_existing: bool = false,
    create_directories: bool = true,
    path_filter: PathFilter = .{},
    recursive: bool = true,
    follow_symlinks: bool = false,
    max_depth: ?u32 = null,
    min_file_size: u64 = 0,
    max_file_size: ?u64 = null,
    buffer_size: usize = ...,
    read_buffer_size: usize = ...,
    write_buffer_size: usize = ...,
    memory_level: ?u8 = null,
    window_size: ?usize = null,
    window_log: ?u8 = null,
    hash_log: ?u8 = null,
    chain_log: ?u8 = null,
    search_log: ?u8 = null,
    min_match: ?u8 = null,
    target_length: ?u32 = null,
    strategy: Strategy = .default,
    flush_mode: FlushMode = .sync,
    dictionary: ?[]const u8 = null,
    dictionary_id: ?u32 = null,
    threads: u32 = 1,
    job_size: ?usize = null,
    overlap_log: ?u8 = null,
    content_size_flag: bool = true,
    dict_id_flag: bool = true,
    enable_ldm: bool = false,
    ldm_hash_log: ?u8 = null,
    ldm_min_match: ?u8 = null,
    ldm_bucket_size_log: ?u8 = null,
    ldm_hash_rate_log: ?u8 = null,
    format_version: u8 = 1,
    magic_bytes: bool = true,
    progress_callback: ?*const fn (u64, u64) void = null,
    user_data: ?*anyopaque = null,
    // ... methods below
};
```

## Initialization

```zig
const cfg = archive.CompressionConfig.init(.zstd);
```

## Builder Methods

All `with*` methods return a new copy (builder pattern):

### Level Methods

| Method | Description |
|--------|-------------|
| `withLevel(level: Level)` | Set preset level (`.none`, `.fastest`, `.fast`, `.default`, `.best`, `.ultra`) |
| `withCustomLevel(level: u8)` | Set exact numeric level (clamped to algorithm range) |
| `withZstdLevel(level: c_int)` | Set Zstd-specific level (1–22) |
| `withLz4Level(level: c_int)` | Set LZ4-specific level (1–12) |

### Mode / Integrity Methods

| Method | Description |
|--------|-------------|
| `withMode(mode: CompressionMode)` | Set `.compress`, `.decompress`, or `.both` |
| `withChecksum()` | Enable checksum generation |
| `withVerifyChecksum(verify: bool)` | Enable/disable checksum verification |
| `withKeepOriginal()` | Keep original files after compression |
| `withOverwriteExisting()` | Overwrite existing output files |

### Buffer Methods

| Method | Description |
|--------|-------------|
| `withBufferSize(size: usize)` | Set all buffer sizes (read + write) |
| `withReadBufferSize(size: usize)` | Set read buffer size |
| `withWriteBufferSize(size: usize)` | Set write buffer size |
| `withMemoryLevel(level: u8)` | Set memory level (1–9) |

### Window / Strategy Methods

| Method | Description |
|--------|-------------|
| `withWindowSize(size: usize)` | Set compression window size |
| `withWindowLog(log: u8)` | Set window log (10–31) |
| `withHashLog(log: u8)` | Set hash log (6–26) |
| `withChainLog(log: u8)` | Set chain log (6–28) |
| `withSearchLog(log: u8)` | Set search log (1–26) |
| `withMinMatch(min: u8)` | Set minimum match length (3–7) |
| `withTargetLength(len: u32)` | Set target length |
| `withStrategy(strategy: Strategy)` | Set compression strategy |
| `withFlushMode(mode: FlushMode)` | Set flush mode |

### Dictionary Methods

| Method | Description |
|--------|-------------|
| `withDictionary(dict: []const u8)` | Set compression dictionary |
| `withDictionaryId(id: u32)` | Set dictionary ID |

### Threading Methods

| Method | Description |
|--------|-------------|
| `withThreads(threads: u32)` | Set thread count (1–128) |
| `withJobSize(size: usize)` | Set per-job size |
| `withOverlapLog(log: u8)` | Set overlap log (0–9) |

### Zstd LDM Methods

| Method | Description |
|--------|-------------|
| `withLongDistanceMatching()` | Enable long-distance matching |
| `withLdmHashLog(log: u8)` | Set LDM hash log (6–26) |
| `withLdmMinMatch(min: u8)` | Set LDM minimum match (4–4096) |
| `withLdmBucketSizeLog(log: u8)` | Set LDM bucket size log (1–8) |
| `withLdmHashRateLog(log: u8)` | Set LDM hash rate log |

### Format / Metadata Methods

| Method | Description |
|--------|-------------|
| `withContentSizeFlag(flag: bool)` | Set content size flag |
| `withDictIdFlag(flag: bool)` | Set dictionary ID flag |
| `withFormatVersion(version: u8)` | Set format version |
| `withMagicBytes(magic: bool)` | Enable/disable magic bytes |
| `withProgressCallback(cb)` | Set progress callback |
| `withUserData(data: *anyopaque)` | Set user data pointer |

### Directory / Traversal Methods

| Method | Description |
|--------|-------------|
| `withRecursive(recursive: bool)` | Enable/disable recursive traversal |
| `withFollowSymlinks()` | Follow symbolic links |
| `withMaxDepth(depth: u32)` | Limit traversal depth |
| `withSizeRange(min: u64, max: ?u64)` | Set file size range |
| `withCreateDirectories(create: bool)` | Auto-create output directories |
| `withPathFilter(filter: PathFilter)` | Set a `PathFilter` directly |

### Query Methods

| Method | Description |
|--------|-------------|
| `getEffectiveLevel() u8` | Returns the numeric level in effect |
| `getEffectiveZstdLevel() c_int` | Returns the effective Zstd level |
| `getEffectiveLz4Level() c_int` | Returns the effective LZ4 level |
| `shouldIncludePath(path, is_directory) bool` | Check if path passes filters |
| `isValidForAlgorithm() bool` | Validate config for the chosen algorithm |
| `optimize() CompressionConfig` | Auto-optimize settings (e.g., thread job sizes for Zstd) |

## Supported Types

### Level

```zig
pub const Level = enum {
    none,      // 0
    fastest,   // 1
    fast,      // 3
    default,   // 6
    best,      // 9
    ultra,     // 12
};
```

### Strategy

```zig
pub const Strategy = enum {
    default,
    filtered,
    huffman_only,
    rle,
    fixed,
    fast,
    dfast,
    greedy,
    lazy,
    lazy2,
    btlazy2,
    btopt,
    btultra,
    btultra2,
};
```

### CompressionMode

```zig
pub const CompressionMode = enum { compress, decompress, both };
```

### FlushMode

```zig
pub const FlushMode = enum { none, sync, full, finish, block };
```

### FilterRule

```zig
pub const FilterRule = struct {
    pattern: []const u8,
    is_directory: bool = false,
    is_recursive: bool = true,
    case_sensitive: bool = false,
    negate: bool = false,
};
```

### PathFilter

```zig
pub const PathFilter = struct {
    include_rules: []const FilterRule = &[_]FilterRule{},
    exclude_rules: []const FilterRule = &[_]FilterRule{},
    default_action: bool = true,

    pub fn shouldInclude(self: PathFilter, path: []const u8, is_directory: bool) bool
};
```

## Options

An internal representation used by algorithm backends. Can be created from a `CompressionConfig`:

```zig
pub const Options = struct {
    pub fn fromConfig(cfg: CompressionConfig) Options
    // ... with* static factory methods
};
```

## StreamingOptions

```zig
pub const StreamingOptions = struct {
    pub fn withBufferSize(size: usize) StreamingOptions
    pub fn withFlushMode(mode: FlushMode) StreamingOptions
    pub fn withAutoFlush() StreamingOptions
    pub fn withSyncFlush() StreamingOptions
};
```

## Examples

### Development Configuration

```zig
const cfg = archive.CompressionConfig.init(.lz4)
    .withLevel(.fastest)
    .withBufferSize(64 * 1024)
    .withRecursive(true)
    .withMaxDepth(10);
```

### Production Configuration

```zig
const cfg = archive.CompressionConfig.init(.zstd)
    .withZstdLevel(15)
    .withChecksum()
    .withKeepOriginal()
    .withThreads(4)
    .withBufferSize(512 * 1024);
```

### File Filtering with PathFilter

```zig
const cfg = archive.CompressionConfig.init(.gzip)
    .withPathFilter(.{
        .include_rules = &[_]archive.FilterRule{
            .{ .pattern = "*.zig" },
            .{ .pattern = "*.md" },
        },
        .exclude_rules = &[_]archive.FilterRule{
            .{ .pattern = "*.tmp" },
            .{ .pattern = "*.log" },
        },
    });
```
