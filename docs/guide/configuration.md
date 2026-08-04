# Configuration

Archive.zig provides a flexible configuration system that allows full client-side customization of compression settings, file filtering, and advanced options.

## Basic Configuration

### Creating Configurations

```zig
// Initialize with algorithm
var config = archive.CompressionConfig.init(.zstd);

// Chain configuration methods
config = config
    .withZstdLevel(15)
    .withChecksum()
    .withRecursive(true);
```

### Compression Levels

```zig
// Standard levels
config.withLevel(.fastest)  // Level 1
config.withLevel(.fast)     // Level 3  
config.withLevel(.default)  // Level 6
config.withLevel(.best)     // Level 9

// Custom levels (0-9 for most algorithms)
config.withCustomLevel(7)

// ZSTD-specific levels (1-22)
config.withZstdLevel(19)
```

## Advanced Configuration

### File Filtering

```zig
// Build a PathFilter with FilterRule structs
const filter = archive.PathFilter{
    .include_rules = &[_]archive.FilterRule{
        .{ .pattern = "*.zig", .is_directory = false },
        .{ .pattern = "*.md", .is_directory = false },
        .{ .pattern = "src/**", .is_directory = true, .is_recursive = true },
    },
    .exclude_rules = &[_]archive.FilterRule{
        .{ .pattern = "*.tmp", .is_directory = false, .case_sensitive = false },
        .{ .pattern = "*.log", .is_directory = false },
        .{ .pattern = "*.cache", .is_directory = false },
        .{ .pattern = "node_modules/**", .is_directory = true, .is_recursive = true },
        .{ .pattern = ".git/**", .is_directory = true, .is_recursive = true },
    },
};
config = config.withPathFilter(filter);
```

### Directory Traversal

```zig
// Control directory traversal
config.withRecursive(true)           // Traverse subdirectories
config.withFollowSymlinks()          // Follow symbolic links
config.withMaxDepth(5)               // Limit traversal depth

// File size filtering
config.withSizeRange(1024, 10 * 1024 * 1024)  // 1KB to 10MB
```

### Performance Options

```zig
// Buffer and memory settings
config.withBufferSize(128 * 1024)    // 128KB buffer
config.withMemoryLevel(8)            // Memory usage level (1-9)
config.withWindowSize(32768)         // Compression window size

// Compression strategy
config.withStrategy(.huffman_only)   // Huffman-only compression
config.withStrategy(.rle)            // Run-length encoding
```

### Advanced Features

```zig
// Dictionary compression
const dict = "common words and phrases";
config.withDictionary(dict)

// Keep original files
config.withKeepOriginal()

// Checksum verification
config.withChecksum()
```

## Algorithm-Specific Configuration

### ZSTD Configuration

```zig
// ZSTD supports levels 1-22
var zstd_config = archive.CompressionConfig.init(.zstd)
    .withZstdLevel(15)      // High compression
    .withChecksum()
    .withBufferSize(256 * 1024);

// Ultra compression
var ultra_config = archive.CompressionConfig.init(.zstd)
    .withZstdLevel(22)      // Maximum compression
    .withMemoryLevel(9);
```

### Gzip Configuration

```zig
var gzip_config = archive.CompressionConfig.init(.gzip)
    .withCustomLevel(9)     // Maximum gzip compression
    .withStrategy(.huffman_only)
    .withWindowSize(32768);
```

### LZ4 Configuration

```zig
var lz4_config = archive.CompressionConfig.init(.lz4)
    .withLevel(.fastest)    // LZ4 optimized for speed
    .withChecksum();
```

## Configuration Examples

### Development Configuration

```zig
var dev_config = archive.CompressionConfig.init(.lz4)
    .withLevel(.fastest)
    .withPathFilter(.{
        .exclude_rules = &[_]archive.FilterRule{
            .{ .pattern = "*.tmp", .is_directory = false },
            .{ .pattern = "*.log", .is_directory = false },
        },
    })
    .withRecursive(true);
```

### Production Configuration

```zig
var prod_config = archive.CompressionConfig.init(.zstd)
    .withZstdLevel(10)
    .withChecksum()
    .withKeepOriginal()
    .withPathFilter(.{
        .exclude_rules = &[_]archive.FilterRule{
            .{ .pattern = ".git/**", .is_directory = true, .is_recursive = true },
            .{ .pattern = "node_modules/**", .is_directory = true, .is_recursive = true },
        },
    });
```

### Archive Configuration

```zig
var archive_config = archive.CompressionConfig.init(.xz)
    .withLevel(.best)
    .withChecksum()
    .withSizeRange(0, null);  // No max size limit
```

## Pattern Matching

Archive.zig supports various pattern matching formats:

- `*` - Match all files
- `*.ext` - Match files with specific extension
- `**/pattern` - Match pattern in any subdirectory
- `pattern/**` - Match all files under pattern directory
- Exact matches for specific files/directories

### Case Sensitivity

```zig
const rules = [_]archive.FilterRule{
    .{ .pattern = "*.TMP", .case_sensitive = false },  // Matches *.tmp, *.TMP, *.Tmp
    .{ .pattern = "README", .case_sensitive = true },  // Matches only "README"
};
```

## Using Configurations

```zig
// With compressWithConfig
const compressed = try archive.compressWithConfig(allocator, data, config);

// With Archive struct
var arch = archive.Archive.init(allocator, config);
const compressed = try arch.compress(data);
```