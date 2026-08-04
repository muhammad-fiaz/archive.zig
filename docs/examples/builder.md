# Builder Pattern Examples

This page demonstrates how to use the builder pattern for flexible configuration in Archive.zig.

## Basic Builder Usage

### Simple Configuration Chain

```zig
const std = @import("std");
const archive = @import("archive");

pub fn basicBuilderExample(allocator: std.mem.Allocator) !void {
    // Chain configuration methods for clean, readable code
    const config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(15)
        .withChecksum()
        .withBufferSize(256 * 1024);
    
    const input = "Builder pattern example data";
    const compressed = try archive.compressWithConfig(allocator, input, config);
    defer allocator.free(compressed);
    
    std.debug.print("Builder pattern compression: {d} bytes\n", .{compressed.len});
}
```

### Step-by-Step Building

```zig
pub fn stepByStepBuilder(allocator: std.mem.Allocator) !void {
    // Start with base configuration
    var config = archive.CompressionConfig.init(.gzip);
    
    // Add compression level
    config = config.withLevel(.best);
    
    // Add buffer configuration
    config = config.withBufferSize(128 * 1024);
    
    // Add quality options
    config = config.withChecksum();
    config = config.withKeepOriginal();
    
    const input = "Step-by-step builder example";
    const compressed = try archive.compressWithConfig(allocator, input, config);
    defer allocator.free(compressed);
    
    std.debug.print("Step-by-step configuration: {d} bytes\n", .{compressed.len});
}
```

## Algorithm-Specific Builders

### ZSTD Builder

```zig
pub fn zstdBuilderExample(allocator: std.mem.Allocator) !void {
    const input = "ZSTD builder pattern example " ** 50;
    
    // Fast ZSTD configuration
    const fast_config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(3)
        .withBufferSize(64 * 1024)
        .withMemoryLevel(6);
    
    // Balanced ZSTD configuration
    const balanced_config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(10)
        .withBufferSize(256 * 1024)
        .withMemoryLevel(8)
        .withChecksum();
    
    // Maximum ZSTD configuration
    const max_config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(22)
        .withBufferSize(1024 * 1024)
        .withMemoryLevel(9)
        .withChecksum()
        .withKeepOriginal();
    
    // Test all configurations
    const configs = [_]struct { config: archive.CompressionConfig, name: []const u8 }{
        .{ .config = fast_config, .name = "Fast ZSTD" },
        .{ .config = balanced_config, .name = "Balanced ZSTD" },
        .{ .config = max_config, .name = "Maximum ZSTD" },
    };
    
    for (configs) |c| {
        const compressed = try archive.compressWithConfig(allocator, input, c.config);
        defer allocator.free(compressed);
        
        const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;
        std.debug.print("{s}: {d} bytes ({d:.1}%)\n", .{ c.name, compressed.len, ratio });
    }
}
```

### LZ4 Builder

```zig
pub fn lz4BuilderExample(allocator: std.mem.Allocator) !void {
    const input = "LZ4 builder pattern example " ** 30;
    
    // Ultra-fast LZ4 configuration
    const ultra_fast = archive.CompressionConfig.init(.lz4)
        .withLevel(.fastest)
        .withBufferSize(32 * 1024);
    
    // Balanced LZ4 configuration
    const balanced = archive.CompressionConfig.init(.lz4)
        .withLz4Level(6)
        .withBufferSize(128 * 1024)
        .withChecksum();
    
    // High compression LZ4 configuration
    const high_compression = archive.CompressionConfig.init(.lz4)
        .withLz4Level(12)
        .withBufferSize(256 * 1024)
        .withChecksum()
        .withMemoryLevel(8);
    
    const configs = [_]struct { config: archive.CompressionConfig, name: []const u8 }{
        .{ .config = ultra_fast, .name = "Ultra-fast LZ4" },
        .{ .config = balanced, .name = "Balanced LZ4" },
        .{ .config = high_compression, .name = "High compression LZ4" },
    };
    
    for (configs) |c| {
        const start_time = std.time.nanoTimestamp();
        const compressed = try archive.compressWithConfig(allocator, input, c.config);
        defer allocator.free(compressed);
        const end_time = std.time.nanoTimestamp();
        
        const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
        const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;
        
        std.debug.print("{s}: {d} bytes ({d:.1}%) in {d:.2}ms\n", 
                       .{ c.name, compressed.len, ratio, duration_ms });
    }
}
```

## File Filtering Builders

### Basic File Filtering

```zig
pub fn fileFilteringBuilder(allocator: std.mem.Allocator) !void {
    // Configuration with file filtering using PathFilter
    const include_rules = [_]archive.FilterRule{
        .{ .pattern = "*.zig" },
        .{ .pattern = "*.md" },
        .{ .pattern = "*.json" },
    };
    const exclude_rules = [_]archive.FilterRule{
        .{ .pattern = "*.tmp" },
        .{ .pattern = "*.log" },
        .{ .pattern = "*.cache" },
    };
    
    const config = archive.CompressionConfig.init(.gzip)
        .withPathFilter(.{
            .include_rules = &include_rules,
            .exclude_rules = &exclude_rules,
        });
    
    // Test paths
    const test_paths = [_]struct { path: []const u8, is_dir: bool }{
        .{ .path = "src/main.zig", .is_dir = false },
        .{ .path = "README.md", .is_dir = false },
        .{ .path = "config.json", .is_dir = false },
        .{ .path = "temp.tmp", .is_dir = false },
        .{ .path = "debug.log", .is_dir = false },
        .{ .path = "data.cache", .is_dir = false },
        .{ .path = "script.py", .is_dir = false },
    };
    
    std.debug.print("File filtering results:\n");
    for (test_paths) |test_path| {
        const included = config.path_filter.shouldInclude(test_path.path, test_path.is_dir);
        const status = if (included) "INCLUDED" else "EXCLUDED";
        std.debug.print("  {s}: {s}\n", .{ test_path.path, status });
    }
}
```

### Advanced Directory Filtering

```zig
pub fn directoryFilteringBuilder(allocator: std.mem.Allocator) !void {
    // Configuration with directory filtering using PathFilter
    const include_rules = [_]archive.FilterRule{
        .{ .pattern = "src/**", .is_directory = true, .is_recursive = true },
        .{ .pattern = "docs/**", .is_directory = true, .is_recursive = true },
        .{ .pattern = "examples/**", .is_directory = true, .is_recursive = true },
    };
    const exclude_rules = [_]archive.FilterRule{
        .{ .pattern = ".git/**", .is_directory = true, .is_recursive = true },
        .{ .pattern = "node_modules/**", .is_directory = true, .is_recursive = true },
        .{ .pattern = "zig-cache/**", .is_directory = true, .is_recursive = true },
    };
    
    const config = archive.CompressionConfig.init(.zstd)
        .withPathFilter(.{
            .include_rules = &include_rules,
            .exclude_rules = &exclude_rules,
        });
    
    // Test directory paths
    const test_dirs = [_][]const u8{
        "src/algorithms",
        "docs/guide",
        "examples/basic",
        ".git/objects",
        "node_modules/package",
        "zig-cache/build",
        "tests/unit",
        "build/output",
    };
    
    std.debug.print("Directory filtering results:\n");
    for (test_dirs) |dir_path| {
        const included = config.path_filter.shouldInclude(dir_path, true);
        const status = if (included) "INCLUDED" else "EXCLUDED";
        std.debug.print("  {s}/: {s}\n", .{ dir_path, status });
    }
}
```

### Custom Filter Rules

```zig
pub fn customFilterRulesBuilder(allocator: std.mem.Allocator) !void {
    // Create custom filter rules
    const include_rules = [_]archive.FilterRule{
        .{ .pattern = "src/**", .is_directory = true, .case_sensitive = true, .is_recursive = true },
        .{ .pattern = "*.zig", .is_directory = false, .case_sensitive = true, .is_recursive = false },
        .{ .pattern = "*.md", .is_directory = false, .case_sensitive = false, .is_recursive = false },
    };
    
    const exclude_rules = [_]archive.FilterRule{
        .{ .pattern = "*.tmp", .is_directory = false, .case_sensitive = false, .is_recursive = false },
        .{ .pattern = "build/**", .is_directory = true, .case_sensitive = true, .is_recursive = true },
        .{ .pattern = "*.LOG", .is_directory = false, .case_sensitive = false, .is_recursive = false },
    };
    
    // Build configuration with custom rules
    const config = archive.CompressionConfig.init(.lz4)
        .withPathFilter(.{
            .include_rules = &include_rules,
            .exclude_rules = &exclude_rules,
        });
    
    // Test various paths
    const test_paths = [_]struct { path: []const u8, is_dir: bool }{
        .{ .path = "src/main.zig", .is_dir = false },
        .{ .path = "README.md", .is_dir = false },
        .{ .path = "readme.MD", .is_dir = false },
        .{ .path = "temp.tmp", .is_dir = false },
        .{ .path = "TEMP.TMP", .is_dir = false },
        .{ .path = "build/output", .is_dir = true },
        .{ .path = "debug.log", .is_dir = false },
        .{ .path = "DEBUG.LOG", .is_dir = false },
    };
    
    std.debug.print("Custom filter rules results:\n");
    for (test_paths) |test_path| {
        const included = config.path_filter.shouldInclude(test_path.path, test_path.is_dir);
        const status = if (included) "INCLUDED" else "EXCLUDED";
        const type_str = if (test_path.is_dir) "DIR" else "FILE";
        std.debug.print("  {s} ({s}): {s}\n", .{ test_path.path, type_str, status });
    }
}
```

## Performance-Oriented Builders

### Speed-Optimized Builder

```zig
pub fn speedOptimizedBuilder(allocator: std.mem.Allocator) !void {
    const input = "Speed optimization test data " ** 100;
    
    // Ultra-fast configuration
    const speed_config = archive.CompressionConfig.init(.lz4)
        .withLevel(.fastest)
        .withBufferSize(256 * 1024)  // Large buffer for throughput
        .withMemoryLevel(1);         // Minimal memory usage
    
    const start_time = std.time.nanoTimestamp();
    const compressed = try archive.compressWithConfig(allocator, input, speed_config);
    defer allocator.free(compressed);
    const end_time = std.time.nanoTimestamp();
    
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    const throughput_mb = @as(f64, @floatFromInt(input.len)) / (1024.0 * 1024.0) / (duration_ms / 1000.0);
    
    std.debug.print("Speed-optimized compression:\n");
    std.debug.print("  Input: {d} bytes\n", .{input.len});
    std.debug.print("  Output: {d} bytes\n", .{compressed.len});
    std.debug.print("  Time: {d:.2}ms\n", .{duration_ms});
    std.debug.print("  Throughput: {d:.2} MB/s\n", .{throughput_mb});
}
```

### Size-Optimized Builder

```zig
pub fn sizeOptimizedBuilder(allocator: std.mem.Allocator) !void {
    const input = "Size optimization test data with repetitive patterns " ** 50;
    
    // Maximum compression configuration
    const size_config = archive.CompressionConfig.init(.lzma)
        .withLevel(.best)
        .withBufferSize(1024 * 1024)  // Large buffer for better compression
        .withMemoryLevel(9)           // Maximum memory usage
        .withChecksum();              // Ensure integrity
    
    const start_time = std.time.nanoTimestamp();
    const compressed = try archive.compressWithConfig(allocator, input, size_config);
    defer allocator.free(compressed);
    const end_time = std.time.nanoTimestamp();
    
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;
    
    std.debug.print("Size-optimized compression:\n");
    std.debug.print("  Input: {d} bytes\n", .{input.len});
    std.debug.print("  Output: {d} bytes\n", .{compressed.len});
    std.debug.print("  Ratio: {d:.1}%\n", .{ratio});
    std.debug.print("  Time: {d:.2}ms\n", .{duration_ms});
}
```

### Balanced Builder

```zig
pub fn balancedBuilder(allocator: std.mem.Allocator) !void {
    const input = "Balanced optimization test data " ** 75;
    
    // Balanced configuration
    const balanced_config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(10)           // Good compression
        .withBufferSize(256 * 1024)  // Reasonable buffer
        .withMemoryLevel(7)          // Moderate memory usage
        .withChecksum();             // Integrity checking
    
    const start_time = std.time.nanoTimestamp();
    const compressed = try archive.compressWithConfig(allocator, input, balanced_config);
    defer allocator.free(compressed);
    const end_time = std.time.nanoTimestamp();
    
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;
    const throughput_mb = @as(f64, @floatFromInt(input.len)) / (1024.0 * 1024.0) / (duration_ms / 1000.0);
    
    std.debug.print("Balanced compression:\n");
    std.debug.print("  Input: {d} bytes\n", .{input.len});
    std.debug.print("  Output: {d} bytes ({d:.1}%)\n", .{ compressed.len, ratio });
    std.debug.print("  Time: {d:.2}ms\n", .{duration_ms});
    std.debug.print("  Throughput: {d:.2} MB/s\n", .{throughput_mb});
}
```

## Conditional Builders

### Environment-Based Builder

```zig
pub fn environmentBasedBuilder(allocator: std.mem.Allocator, is_production: bool, memory_limited: bool) !archive.CompressionConfig {
    // Start with base algorithm choice
    var config = if (memory_limited)
        archive.CompressionConfig.init(.lz4)
    else
        archive.CompressionConfig.init(.zstd);
    
    // Configure based on environment
    if (is_production) {
        // Production: prioritize compression ratio and integrity
        config = config
            .withLevel(.best)
            .withChecksum()
            .withKeepOriginal();
        
        if (!memory_limited) {
            config = config
                .withZstdLevel(15)
                .withBufferSize(512 * 1024)
                .withMemoryLevel(8);
        }
    } else {
        // Development: prioritize speed
        config = config
            .withLevel(.fastest)
            .withBufferSize(64 * 1024);
        
        if (!memory_limited) {
            config = config.withZstdLevel(3);
        }
    }
    
    // Add common settings
    const exclude_rules = [_]archive.FilterRule{
        .{ .pattern = "*.tmp" },
        .{ .pattern = "*.log" },
    };
    config = config.withPathFilter(.{
        .exclude_rules = &exclude_rules,
    });
    
    return config;
}

pub fn conditionalBuilderExample(allocator: std.mem.Allocator) !void {
    const test_data = "Conditional builder test data";
    
    // Test different environment configurations
    const scenarios = [_]struct { prod: bool, mem_limited: bool, name: []const u8 }{
        .{ .prod = false, .mem_limited = false, .name = "Development (high memory)" },
        .{ .prod = false, .mem_limited = true, .name = "Development (low memory)" },
        .{ .prod = true, .mem_limited = false, .name = "Production (high memory)" },
        .{ .prod = true, .mem_limited = true, .name = "Production (low memory)" },
    };
    
    for (scenarios) |scenario| {
        const config = try environmentBasedBuilder(allocator, scenario.prod, scenario.mem_limited);
        const compressed = try archive.compressWithConfig(allocator, test_data, config);
        defer allocator.free(compressed);
        
        std.debug.print("{s}: {s} algorithm, {d} bytes\n", 
                       .{ scenario.name, @tagName(config.algorithm), compressed.len });
    }
}
```

### Data-Driven Builder

```zig
pub fn dataDrivenBuilder(allocator: std.mem.Allocator, data: []const u8) !archive.CompressionConfig {
    // Analyze data characteristics
    const entropy = calculateEntropy(data);
    const repetition_ratio = calculateRepetitionRatio(data);
    const size_mb = @as(f64, @floatFromInt(data.len)) / (1024.0 * 1024.0);
    
    var config: archive.CompressionConfig = undefined;
    
    // Choose algorithm based on data characteristics
    if (entropy < 0.5 and repetition_ratio > 0.7) {
        // Highly repetitive data - use high compression
        config = archive.CompressionConfig.init(.lzma)
            .withLevel(.best);
    } else if (entropy > 0.9) {
        // Random/encrypted data - use fast algorithm
        config = archive.CompressionConfig.init(.lz4)
            .withLevel(.fastest);
    } else {
        // Normal data - use balanced algorithm
        config = archive.CompressionConfig.init(.zstd)
            .withZstdLevel(10);
    }
    
    // Configure buffer size based on data size
    const buffer_size = if (size_mb < 1.0)
        32 * 1024   // Small data: 32KB buffer
    else if (size_mb < 10.0)
        128 * 1024  // Medium data: 128KB buffer
    else
        512 * 1024; // Large data: 512KB buffer
    
    config = config.withBufferSize(buffer_size);
    
    // Add checksum for important data (low entropy suggests structured data)
    if (entropy < 0.7) {
        config = config.withChecksum();
    }
    
    return config;
}

// Helper functions for data analysis
fn calculateEntropy(data: []const u8) f64 {
    var counts: [256]usize = [_]usize{0} ** 256;
    for (data) |byte| {
        counts[byte] += 1;
    }
    
    var entropy: f64 = 0.0;
    const len_f = @as(f64, @floatFromInt(data.len));
    
    for (counts) |count| {
        if (count > 0) {
            const p = @as(f64, @floatFromInt(count)) / len_f;
            entropy -= p * std.math.log2(p);
        }
    }
    
    return entropy / 8.0; // Normalize to 0-1 range
}

fn calculateRepetitionRatio(data: []const u8) f64 {
    if (data.len < 2) return 0.0;
    
    var repetitions: usize = 0;
    for (data[1..], 1..) |byte, i| {
        if (byte == data[i - 1]) {
            repetitions += 1;
        }
    }
    
    return @as(f64, @floatFromInt(repetitions)) / @as(f64, @floatFromInt(data.len - 1));
}

pub fn dataDrivenBuilderExample(allocator: std.mem.Allocator) !void {
    const test_cases = [_]struct { name: []const u8, data: []const u8 }{
        .{ .name = "Repetitive", .data = "AAAAAAAAAA" ** 1000 },
        .{ .name = "Text", .data = "The quick brown fox jumps over the lazy dog. " ** 100 },
        .{ .name = "Random", .data = &[_]u8{0x12, 0x34, 0x56, 0x78, 0x9A, 0xBC, 0xDE, 0xF0} ** 1000 },
    };
    
    for (test_cases) |test_case| {
        const config = try dataDrivenBuilder(allocator, test_case.data);
        const compressed = try archive.compressWithConfig(allocator, test_case.data, config);
        defer allocator.free(compressed);
        
        const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(test_case.data.len)) * 100;
        
        std.debug.print("{s} data:\n", .{test_case.name});
        std.debug.print("  Algorithm: {s}\n", .{@tagName(config.algorithm)});
        std.debug.print("  Buffer size: {d} KB\n", .{config.buffer_size / 1024});
        std.debug.print("  Checksum: {}\n", .{config.checksum});
        std.debug.print("  Compression: {d} -> {d} bytes ({d:.1}%)\n", 
                       .{ test_case.data.len, compressed.len, ratio });
        std.debug.print("\n", .{});
    }
}
```

## Builder Validation

### Configuration Validation

```zig
pub fn validateConfiguration(config: archive.CompressionConfig) !void {
    // Validate buffer size
    if (config.buffer_size < 1024) {
        return error.BufferTooSmall;
    }
    if (config.buffer_size > 16 * 1024 * 1024) {
        return error.BufferTooLarge;
    }
    
    // Validate memory level
    if (config.memory_level < 1 or config.memory_level > 9) {
        return error.InvalidMemoryLevel;
    }
    
    // Validate algorithm-specific settings
    switch (config.algorithm) {
        .zstd => {
            if (config.zstd_level) |level| {
                if (level < 1 or level > 22) {
                    return error.InvalidZstdLevel;
                }
            }
        },
        .lz4 => {
            if (config.lz4_level) |level| {
                if (level < 1 or level > 12) {
                    return error.InvalidLz4Level;
                }
            }
        },
        else => {},
    }
    
    // Validate conflicting options
    if (config.keep_original and !config.checksum) {
        std.debug.print("Warning: keep_original without checksum may not detect corruption\n", .{});
    }
}

pub fn validationExample(allocator: std.mem.Allocator) !void {
    // Test valid configuration
    const valid_config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(15)
        .withBufferSize(256 * 1024)
        .withMemoryLevel(8)
        .withChecksum();
    
    validateConfiguration(valid_config) catch |err| {
        std.debug.print("Valid config failed validation: {}\n", .{err});
        return;
    };
    std.debug.print("Valid configuration passed validation\n", .{});
    
    // Test invalid configuration
    const invalid_config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(25)  // Invalid: max is 22
        .withBufferSize(512); // Invalid: too small
    
    validateConfiguration(invalid_config) catch |err| {
        std.debug.print("Invalid config correctly rejected: {}\n", .{err});
        return;
    };
    std.debug.print("Invalid configuration incorrectly passed validation\n", .{});
}
```

## Next Steps

- Learn about [Auto-Detection](./auto-detection.md) for automatic format detection
- Explore [File Operations](./file-operations.md) for working with files
- Check out [Streaming](./streaming.md) for large data processing
- See [Configuration](./configuration.md) for more configuration examples