# Builder Pattern

Archive.zig uses the builder pattern for flexible configuration. This allows you to chain method calls to create exactly the configuration you need.

## Basic Builder Usage

The builder pattern starts with `CompressionConfig.init(.zstd)` and chains configuration methods:

```zig
const config = archive.CompressionConfig.init(.zstd)
    .withZstdLevel(15)
    .withChecksum()
    .withRecursive(true);
```

## Configuration Methods

### Algorithm and Level

```zig
// Initialize with algorithm
var config = archive.CompressionConfig.init(.gzip);

// Set compression level
config = config.withLevel(.best);           // Preset level
config = config.withCustomLevel(9);        // Custom level (0-9)
config = config.withZstdLevel(19);         // ZSTD level (1-22)
config = config.withLz4Level(8);           // LZ4 level (1-12)
```

### File Filtering

Filtering is configured via `PathFilter` containing `FilterRule` structs:

```zig
const filter = archive.PathFilter{
    .include_rules = &[_]archive.FilterRule{
        .{ .pattern = "*.zig", .is_directory = false },
        .{ .pattern = "*.md", .is_directory = false },
    },
    .exclude_rules = &[_]archive.FilterRule{
        .{ .pattern = "*.tmp", .is_directory = false },
        .{ .pattern = "*.log", .is_directory = false },
        .{ .pattern = ".git/**", .is_directory = true, .is_recursive = true },
        .{ .pattern = "node_modules/**", .is_directory = true, .is_recursive = true },
    },
};

config = config.withPathFilter(filter);
```

Each `FilterRule` supports these fields:

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `pattern` | `[]const u8` | (required) | Glob pattern to match |
| `is_directory` | `bool` | `false` | Match directories instead of files |
| `is_recursive` | `bool` | `true` | Match recursively in subdirectories |
| `case_sensitive` | `bool` | `false` | Case-sensitive matching |
| `negate` | `bool` | `false` | Negate the match (exclude matched items from the rule set) |

### Directory Traversal

```zig
config = config
    .withRecursive(true)           // Enable recursive traversal
    .withFollowSymlinks()          // Follow symbolic links
    .withMaxDepth(5)               // Limit traversal depth
    .withSizeRange(1024, 10 * 1024 * 1024); // File size range
```

### Performance Options

```zig
config = config
    .withBufferSize(256 * 1024)    // Buffer size
    .withMemoryLevel(8)            // Memory usage level
    .withWindowSize(32768)         // Compression window
    .withStrategy(.huffman_only);  // Compression strategy
```

### Quality Options

```zig
config = config
    .withChecksum()                // Enable checksum verification
    .withKeepOriginal()            // Keep original files
    .withDictionary(dict_data);    // Use compression dictionary
```

## Chaining Examples

### Development Configuration

```zig
const dev_config = archive.CompressionConfig.init(.lz4)
    .withLevel(.fastest)
    .withPathFilter(.{
        .exclude_rules = &[_]archive.FilterRule{
            .{ .pattern = "*.tmp", .is_directory = false },
            .{ .pattern = "*.log", .is_directory = false },
            .{ .pattern = "*.obj", .is_directory = false },
            .{ .pattern = ".git/**", .is_directory = true, .is_recursive = true },
            .{ .pattern = "zig-cache/**", .is_directory = true, .is_recursive = true },
        },
    })
    .withRecursive(true)
    .withMaxDepth(10)
    .withBufferSize(64 * 1024);
```

### Production Configuration

```zig
const prod_config = archive.CompressionConfig.init(.zstd)
    .withZstdLevel(15)
    .withChecksum()
    .withKeepOriginal()
    .withPathFilter(.{
        .exclude_rules = &[_]archive.FilterRule{
            .{ .pattern = ".git/**", .is_directory = true, .is_recursive = true },
            .{ .pattern = "node_modules/**", .is_directory = true, .is_recursive = true },
        },
    })
    .withSizeRange(1, null)
    .withRecursive(true)
    .withBufferSize(512 * 1024)
    .withMemoryLevel(9);
```

### Archive Configuration

```zig
const archive_config = archive.CompressionConfig.init(.xz)
    .withLevel(.best)
    .withChecksum()
    .withFollowSymlinks()
    .withSizeRange(0, null)
    .withMaxDepth(null)
    .withBufferSize(1024 * 1024)
    .withMemoryLevel(9);
```

## Conditional Configuration

Build configurations based on runtime conditions:

```zig
pub fn createConfig(fast_mode: bool, include_logs: bool) archive.CompressionConfig {
    var config = if (fast_mode)
        archive.CompressionConfig.init(.lz4).withLevel(.fastest)
    else
        archive.CompressionConfig.init(.zstd).withZstdLevel(15);
    
    if (!include_logs) {
        config = config.withPathFilter(.{
            .exclude_rules = &[_]archive.FilterRule{
                .{ .pattern = "*.log", .is_directory = false },
                .{ .pattern = "*.tmp", .is_directory = false },
            },
        });
    }
    
    return config.withRecursive(true).withChecksum();
}
```

## Method Reference

### Core Methods

| Method | Description | Example |
|--------|-------------|---------|
| `init(algorithm)` | Initialize with algorithm | `init(.zstd)` |
| `withLevel(level)` | Set preset level | `withLevel(.best)` |
| `withCustomLevel(n)` | Set custom level | `withCustomLevel(7)` |
| `withZstdLevel(n)` | Set ZSTD level (1-22) | `withZstdLevel(19)` |
| `withLz4Level(n)` | Set LZ4 level (1-12) | `withLz4Level(8)` |
| `withPathFilter(filter)` | Set path filter with include/exclude rules | `withPathFilter(.{ .exclude_rules = &rules })` |

### Traversal Methods

| Method | Description | Example |
|--------|-------------|---------|
| `withRecursive(bool)` | Enable/disable recursion | `withRecursive(true)` |
| `withFollowSymlinks()` | Follow symbolic links | `withFollowSymlinks()` |
| `withMaxDepth(n)` | Set max traversal depth | `withMaxDepth(5)` |
| `withSizeRange(min, max)` | Filter by file size | `withSizeRange(1024, null)` |

### Performance Methods

| Method | Description | Example |
|--------|-------------|---------|
| `withBufferSize(size)` | Set buffer size | `withBufferSize(256 * 1024)` |
| `withMemoryLevel(level)` | Set memory usage | `withMemoryLevel(8)` |
| `withWindowSize(size)` | Set compression window | `withWindowSize(32768)` |
| `withStrategy(strategy)` | Set compression strategy | `withStrategy(.huffman_only)` |

### Quality Methods

| Method | Description | Example |
|--------|-------------|---------|
| `withChecksum()` | Enable checksum | `withChecksum()` |
| `withKeepOriginal()` | Keep original files | `withKeepOriginal()` |
| `withDictionary(data)` | Use compression dictionary | `withDictionary(dict)` |

## Advanced Patterns

### Configuration Validation

```zig
pub fn validateConfig(config: archive.CompressionConfig) !archive.CompressionConfig {
    // Validate buffer size
    if (config.buffer_size < 1024) {
        return error.BufferTooSmall;
    }
    
    // Validate ZSTD level
    if (config.algorithm == .zstd and config.zstd_level > 22) {
        return error.InvalidZstdLevel;
    }
    
    return config;
}
```

### Configuration Serialization

```zig
pub fn configToJson(allocator: std.mem.Allocator, config: archive.CompressionConfig) ![]u8 {
    return std.json.stringifyAlloc(allocator, config, .{});
}

pub fn configFromJson(allocator: std.mem.Allocator, json: []const u8) !archive.CompressionConfig {
    return std.json.parseFromSlice(archive.CompressionConfig, allocator, json, .{});
}
```

### Configuration Merging

```zig
pub fn mergeConfigs(base: archive.CompressionConfig, override: archive.CompressionConfig) archive.CompressionConfig {
    var result = base;
    
    if (override.level != .default) result.level = override.level;
    if (override.buffer_size != 0) result.buffer_size = override.buffer_size;
    if (override.checksum) result.checksum = true;
    
    return result;
}
```

## Next Steps

- Explore [File Operations](./file-operations.md) for working with files
- Check out [Configuration Examples](../examples/configuration.md)
- See [Streaming](./streaming.md) for large data processing