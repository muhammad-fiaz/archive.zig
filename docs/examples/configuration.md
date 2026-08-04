# Configuration Examples

This page demonstrates various configuration options and customization patterns.

## Basic Configuration

### Simple Algorithm Configuration

```zig
const std = @import("std");
const archive = @import("archive");

pub fn basicConfig(allocator: std.mem.Allocator) !void {
    const input = "Configuration example data";
    
    // Basic configurations for different algorithms
    const configs = [_]struct { config: archive.CompressionConfig, name: []const u8 }{
        .{ .config = archive.CompressionConfig.init(.gzip), .name = "Gzip Default" },
        .{ .config = archive.CompressionConfig.init(.zstd), .name = "Zstd Default" },
        .{ .config = archive.CompressionConfig.init(.lz4), .name = "LZ4 Default" },
    };
    
    for (configs) |c| {
        const compressed = try archive.compressWithConfig(allocator, input, c.config);
        defer allocator.free(compressed);
        std.debug.print("{s}: {d} bytes\n", .{ c.name, compressed.len });
    }
}
```

## ZSTD Level Customization

### Custom ZSTD Compression Levels

```zig
pub fn zstdLevels(allocator: std.mem.Allocator) !void {
    const input = "ZSTD level testing data " ** 10;
    
    // Test different ZSTD compression levels
    const levels = [_]c_int{ 1, 3, 6, 10, 15, 19, 22 };
    
    std.debug.print("ZSTD Compression Levels:\n");
    for (levels) |level| {
        const config = archive.CompressionConfig.init(.zstd)
            .withZstdLevel(level);
        
        const compressed = try archive.compressWithConfig(allocator, input, config);
        defer allocator.free(compressed);
        
        const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;
        std.debug.print("  Level {d:2}: {d} bytes ({d:.1}%)\n", .{ level, compressed.len, ratio });
    }
}
```

## File Filtering

### Using PathFilter with FilterRule

```zig
pub fn fileFiltering(allocator: std.mem.Allocator) !void {
    _ = allocator;

    // Create a PathFilter with include and exclude rules
    const filter = archive.PathFilter{
        .include_rules = &[_]archive.FilterRule{
            .{ .pattern = "*.zig", .is_directory = false },
            .{ .pattern = "*.md", .is_directory = false },
            .{ .pattern = "*.json", .is_directory = false },
        },
        .exclude_rules = &[_]archive.FilterRule{
            .{ .pattern = "*.tmp", .is_directory = false },
            .{ .pattern = "*.log", .is_directory = false },
            .{ .pattern = "*.cache", .is_directory = false },
            .{ .pattern = "node_modules/**", .is_directory = true, .is_recursive = true },
            .{ .pattern = ".git/**", .is_directory = true, .is_recursive = true },
        },
    };

    const config = archive.CompressionConfig.init(.gzip)
        .withPathFilter(filter);
    
    // Test path filtering
    const test_paths = [_]struct { path: []const u8, is_dir: bool }{
        .{ .path = "src/main.zig", .is_dir = false },
        .{ .path = "temp.tmp", .is_dir = false },
        .{ .path = "README.md", .is_dir = false },
        .{ .path = "node_modules/package", .is_dir = true },
        .{ .path = "docs/guide.md", .is_dir = false },
    };
    
    std.debug.print("File Filtering Results:\n");
    for (test_paths) |test_path| {
        const included = config.shouldIncludePath(test_path.path, test_path.is_dir);
        std.debug.print("  {s}: {s}\n", .{ test_path.path, if (included) "INCLUDED" else "EXCLUDED" });
    }
}
```

### Advanced Filter Rules

```zig
pub fn advancedFiltering(allocator: std.mem.Allocator) !void {
    _ = allocator;

    // Create a PathFilter with detailed FilterRule options
    const filter = archive.PathFilter{
        .include_rules = &[_]archive.FilterRule{
            .{ .pattern = "src/**", .is_directory = true, .is_recursive = true },
            .{ .pattern = "*.zig", .is_directory = false, .case_sensitive = true },
        },
        .exclude_rules = &[_]archive.FilterRule{
            .{ .pattern = "*.tmp", .is_directory = false, .case_sensitive = false },
            .{ .pattern = "build/**", .is_directory = true, .is_recursive = true },
            .{ .pattern = "*.LOG", .is_directory = false, .case_sensitive = false },
        },
    };
    
    const config = archive.CompressionConfig.init(.zstd)
        .withPathFilter(filter);
    
    std.debug.print("Advanced filtering configuration created\n");
}
```

## Directory Traversal

### Recursive and Depth Control

```zig
pub fn directoryTraversal(allocator: std.mem.Allocator) !void {
    // Configuration with directory traversal options
    const configs = [_]struct { config: archive.CompressionConfig, name: []const u8 }{
        .{ 
            .config = archive.CompressionConfig.init(.gzip)
                .withRecursive(true)
                .withMaxDepth(3), 
            .name = "Recursive (max depth 3)" 
        },
        .{ 
            .config = archive.CompressionConfig.init(.gzip)
                .withRecursive(false), 
            .name = "Non-recursive" 
        },
        .{ 
            .config = archive.CompressionConfig.init(.gzip)
                .withRecursive(true)
                .withFollowSymlinks(), 
            .name = "Recursive + Follow symlinks" 
        },
    };
    
    for (configs) |c| {
        std.debug.print("Config: {s}\n", .{c.name});
        std.debug.print("  Recursive: {}\n", .{c.config.recursive});
        std.debug.print("  Follow symlinks: {}\n", .{c.config.follow_symlinks});
        if (c.config.max_depth) |depth| {
            std.debug.print("  Max depth: {d}\n", .{depth});
        }
    }
}
```

## Performance Tuning

### Buffer and Memory Settings

```zig
pub fn performanceTuning(allocator: std.mem.Allocator) !void {
    const input = "Performance tuning test data " ** 100;
    
    // Different performance configurations
    const configs = [_]struct { config: archive.CompressionConfig, name: []const u8 }{
        .{ 
            .config = archive.CompressionConfig.init(.gzip)
                .withBufferSize(64 * 1024)
                .withMemoryLevel(6), 
            .name = "Standard (64KB buffer, mem level 6)" 
        },
        .{ 
            .config = archive.CompressionConfig.init(.gzip)
                .withBufferSize(256 * 1024)
                .withMemoryLevel(9), 
            .name = "High memory (256KB buffer, mem level 9)" 
        },
        .{ 
            .config = archive.CompressionConfig.init(.gzip)
                .withBufferSize(16 * 1024)
                .withMemoryLevel(1), 
            .name = "Low memory (16KB buffer, mem level 1)" 
        },
    };
    
    for (configs) |c| {
        const start = std.time.nanoTimestamp();
        const compressed = try archive.compressWithConfig(allocator, input, c.config);
        defer allocator.free(compressed);
        const end = std.time.nanoTimestamp();
        
        const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
        std.debug.print("{s}: {d} bytes in {d:.2}ms\n", .{ c.name, compressed.len, duration_ms });
    }
}
```

## Algorithm-Specific Options

### Compression Strategies

```zig
pub fn compressionStrategies(allocator: std.mem.Allocator) !void {
    const input = "Strategy testing data with various patterns and repetitions " ** 5;
    
    // Test different compression strategies
    const strategies = [_]struct { strategy: archive.Strategy, name: []const u8 }{
        .{ .strategy = .default, .name = "Default" },
        .{ .strategy = .filtered, .name = "Filtered" },
        .{ .strategy = .huffman_only, .name = "Huffman Only" },
        .{ .strategy = .rle, .name = "RLE" },
        .{ .strategy = .fixed, .name = "Fixed" },
    };
    
    for (strategies) |s| {
        const config = archive.CompressionConfig.init(.gzip)
            .withStrategy(s.strategy)
            .withLevel(.best);
        
        const compressed = try archive.compressWithConfig(allocator, input, config);
        defer allocator.free(compressed);
        
        const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;
        std.debug.print("{s} strategy: {d} bytes ({d:.1}%)\n", .{ s.name, compressed.len, ratio });
    }
}
```

## Real-World Configurations

### Development Environment

```zig
pub fn developmentConfig(allocator: std.mem.Allocator) !void {
    // Fast compression for development
    const filter = archive.PathFilter{
        .exclude_rules = &[_]archive.FilterRule{
            .{ .pattern = "*.tmp", .is_directory = false },
            .{ .pattern = "*.log", .is_directory = false },
            .{ .pattern = "*.obj", .is_directory = false },
            .{ .pattern = "*.exe", .is_directory = false },
            .{ .pattern = ".git/**", .is_directory = true, .is_recursive = true },
            .{ .pattern = "zig-cache/**", .is_directory = true, .is_recursive = true },
            .{ .pattern = "zig-out/**", .is_directory = true, .is_recursive = true },
        },
    };

    const dev_config = archive.CompressionConfig.init(.lz4)
        .withLevel(.fastest)
        .withPathFilter(filter)
        .withRecursive(true)
        .withMaxDepth(10);
    
    const input = "Development build artifacts and source code";
    const compressed = try archive.compressWithConfig(allocator, input, dev_config);
    defer allocator.free(compressed);
    
    std.debug.print("Development config: {d} bytes\n", .{compressed.len});
}
```

### Production Archive

```zig
pub fn productionConfig(allocator: std.mem.Allocator) !void {
    // High compression for production archives
    const filter = archive.PathFilter{
        .exclude_rules = &[_]archive.FilterRule{
            .{ .pattern = ".git/**", .is_directory = true, .is_recursive = true },
            .{ .pattern = "node_modules/**", .is_directory = true, .is_recursive = true },
            .{ .pattern = "target/**", .is_directory = true, .is_recursive = true },
        },
    };

    const prod_config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(19)
        .withChecksum()
        .withKeepOriginal()
        .withPathFilter(filter)
        .withSizeRange(1, null)  // Exclude empty files
        .withRecursive(true);
    
    const input = "Production release package with documentation and binaries";
    const compressed = try archive.compressWithConfig(allocator, input, prod_config);
    defer allocator.free(compressed);
    
    std.debug.print("Production config: {d} bytes\n", .{compressed.len});
}
```

### Backup Configuration

```zig
pub fn backupConfig(allocator: std.mem.Allocator) !void {
    // Balanced compression for backups
    const filter = archive.PathFilter{
        .exclude_rules = &[_]archive.FilterRule{
            .{ .pattern = "*.tmp", .is_directory = false },
            .{ .pattern = "*.swp", .is_directory = false },
            .{ .pattern = "*.bak", .is_directory = false },
        },
    };

    const backup_config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(10)
        .withChecksum()
        .withFollowSymlinks()
        .withPathFilter(filter)
        .withSizeRange(0, 100 * 1024 * 1024)  // Skip files > 100MB
        .withRecursive(true);
    
    const input = "System backup with user data and configuration files";
    const compressed = try archive.compressWithConfig(allocator, input, backup_config);
    defer allocator.free(compressed);
    
    std.debug.print("Backup config: {d} bytes\n", .{compressed.len});
}
```