# File Operations

Archive.zig provides convenient functions for working directly with files, handling the reading, compression, and writing operations for you.

## Basic File Compression

### Compress Files

```zig
const std = @import("std");
const archive = @import("archive");

pub fn compressFile(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, algorithm: archive.Algorithm, io: std.Io) !void {
    // Read input file
    const input_data = try std.Io.Dir.cwd().readFileAlloc(io, input_path, allocator, .limited(100 * 1024 * 1024)); // 100MB max
    defer allocator.free(input_data);
    
    // Compress data
    const compressed = try archive.compress(allocator, input_data, algorithm);
    defer allocator.free(compressed);
    
    // Write compressed file
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_path, .data = compressed });
    
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input_data.len)) * 100;
    std.debug.print("Compressed {s} -> {s} ({d:.1}%)\n", .{ input_path, output_path, ratio });
}
```

### Decompress Files

```zig
pub fn decompressFile(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, io: std.Io) !void {
    // Read compressed file
    const compressed_data = try std.Io.Dir.cwd().readFileAlloc(io, input_path, allocator, .limited(100 * 1024 * 1024));
    defer allocator.free(compressed_data);
    
    // Decompress
    const decompressed = try archive.decompress(allocator, compressed_data, .zstd);
    defer allocator.free(decompressed);
    
    // Write decompressed file
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_path, .data = decompressed });
    
    std.debug.print("Decompressed {s} -> {s}\n", .{ input_path, output_path });
}
```

## Directory Operations

### Compress Directory

```zig
pub fn compressDirectory(allocator: std.mem.Allocator, dir_path: []const u8, output_path: []const u8, io: std.Io) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    
    var files = .empty;
    var data = std.ArrayList(u8).empty;
    
    // Collect all files in directory
    try collectFiles(arena_allocator, dir_path, &files, io);
    
    // Combine all file data
    for (files.items) |file_path| {
        const file_data = try std.Io.Dir.cwd().readFileAlloc(io, file_path, arena_allocator, .limited(10 * 1024 * 1024));
        
        // Add file header (simple format: path_length + path + data_length + data)
        const path_len = @as(u32, @intCast(file_path.len));
        const data_len = @as(u32, @intCast(file_data.len));
        
        try data.appendSlice(std.mem.asBytes(&path_len));
        try data.appendSlice(file_path);
        try data.appendSlice(std.mem.asBytes(&data_len));
        try data.appendSlice(file_data);
    }
    
    // Compress combined data
    const compressed = try archive.compress(allocator, data.items, .zstd);
    defer allocator.free(compressed);
    
    // Write compressed archive
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_path, .data = compressed });
    
    std.debug.print("Compressed directory {s} -> {s} ({d} files)\n", .{ dir_path, output_path, files.items.len });
}

fn collectFiles(allocator: std.mem.Allocator, dir_path: []const u8, files: *std.ArrayList([]const u8), io: std.Io) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close();
    
    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name });
        
        switch (entry.kind) {
            .file => try files.append(full_path),
            .directory => try collectFiles(allocator, full_path, files, io),
            else => {},
        }
    }
}
```

## Streaming File Operations

### Stream Compress Large Files

```zig
pub fn streamCompressFile(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, io: std.Io) !void {
    const input_file = try std.Io.Dir.cwd().openFile(io, input_path, .{});
    defer input_file.close();
    
    const output_file = try std.Io.Dir.cwd().createFile(io, output_path, .{});
    defer output_file.close();
    
    var buffer: [64 * 1024]u8 = undefined; // 64KB buffer
    
    while (true) {
        const bytes_read = try input_file.readAll(&buffer);
        if (bytes_read == 0) break;
        
        // Compress chunk
        const compressed_chunk = try archive.compress(allocator, buffer[0..bytes_read], .lz4);
        defer allocator.free(compressed_chunk);
        
        // Write chunk size and data
        const chunk_size = @as(u32, @intCast(compressed_chunk.len));
        try output_file.writeAll(std.mem.asBytes(&chunk_size));
        try output_file.writeAll(compressed_chunk);
    }
    
    // Write end marker
    const end_marker: u32 = 0;
    try output_file.writeAll(std.mem.asBytes(&end_marker));
    
    std.debug.print("Stream compressed {s} -> {s}\n", .{ input_path, output_path });
}
```

### Stream Decompress Large Files

```zig
pub fn streamDecompressFile(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, io: std.Io) !void {
    const input_file = try std.Io.Dir.cwd().openFile(io, input_path, .{});
    defer input_file.close();
    
    const output_file = try std.Io.Dir.cwd().createFile(io, output_path, .{});
    defer output_file.close();
    
    while (true) {
        // Read chunk size
        var chunk_size_bytes: [4]u8 = undefined;
        const bytes_read = try input_file.readAll(&chunk_size_bytes);
        if (bytes_read != 4) break;
        
        const chunk_size = std.mem.readInt(u32, &chunk_size_bytes, .little);
        if (chunk_size == 0) break; // End marker
        
        // Read compressed chunk
        const compressed_chunk = try allocator.alloc(u8, chunk_size);
        defer allocator.free(compressed_chunk);
        _ = try input_file.readAll(compressed_chunk);
        
        // Decompress chunk
        const decompressed_chunk = try archive.decompress(allocator, compressed_chunk, .lz4);
        defer allocator.free(decompressed_chunk);
        
        // Write decompressed data
        try output_file.writeAll(decompressed_chunk);
    }
    
    std.debug.print("Stream decompressed {s} -> {s}\n", .{ input_path, output_path });
}
```

## File Utilities

### File Information

```zig
pub fn getFileInfo(allocator: std.mem.Allocator, file_path: []const u8, io: std.Io) !void {
    const file_stat = try std.Io.Dir.cwd().statFile(io, file_path, .{});
    const file_data = try std.Io.Dir.cwd().readFileAlloc(io, file_path, allocator, .limited(1024)); // Read first 1KB
    defer allocator.free(file_data);
    
    std.debug.print("File: {s}\n", .{file_path});
    std.debug.print("Size: {d} bytes\n", .{file_stat.size});
    std.debug.print("Modified: {d}\n", .{file_stat.mtime});
    
    // Decompress to get size
    const full_data = try std.Io.Dir.cwd().readFileAlloc(io, file_path, allocator, .limited(@intCast(file_stat.size)));
    defer allocator.free(full_data);
    
    if (archive.decompress(allocator, full_data, .zstd)) |decompressed| {
        defer allocator.free(decompressed);
        const ratio = @as(f64, @floatFromInt(full_data.len)) / @as(f64, @floatFromInt(decompressed.len)) * 100;
        std.debug.print("Uncompressed size: {d} bytes\n", .{decompressed.len});
        std.debug.print("Compression ratio: {d:.1}%\n", .{ratio});
    } else |_| {
        std.debug.print("Could not decompress for size calculation\n", .{});
    }
}
```

### Batch Operations

```zig
pub fn batchCompress(allocator: std.mem.Allocator, pattern: []const u8, algorithm: archive.Algorithm, io: std.Io) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, ".", .{ .iterate = true });
    defer dir.close();
    
    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind != .file) continue;
        
        // Simple pattern matching (ends with)
        if (!std.mem.endsWith(u8, entry.name, pattern)) continue;
        
        const input_path = entry.name;
        const output_path = try std.fmt.allocPrint(allocator, "{s}.{s}", .{ input_path, @tagName(algorithm) });
        defer allocator.free(output_path);
        
        compressFile(allocator, input_path, output_path, algorithm, io) catch |err| {
            std.debug.print("Error compressing {s}: {}\n", .{ input_path, err });
            continue;
        };
    }
}
```

## Advanced File Operations

### Atomic File Operations

```zig
pub fn atomicCompressFile(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, algorithm: archive.Algorithm, io: std.Io) !void {
    const temp_path = try std.fmt.allocPrint(allocator, "{s}.tmp", .{output_path});
    defer allocator.free(temp_path);
    
    // Compress to temporary file first
    compressFile(allocator, input_path, temp_path, algorithm, io) catch |err| {
        // Clean up temp file on error
        std.Io.Dir.cwd().deleteFile(io, temp_path) catch {};
        return err;
    };
    
    // Atomically rename temp file to final name
    try std.Io.Dir.cwd().rename(io, temp_path, output_path);
    
    std.debug.print("Atomically compressed {s} -> {s}\n", .{ input_path, output_path });
}
```

### File Backup and Compression

```zig
pub fn backupAndCompress(allocator: std.mem.Allocator, file_path: []const u8, io: std.Io) !void {
    const backup_path = try std.fmt.allocPrint(allocator, "{s}.backup", .{file_path});
    defer allocator.free(backup_path);
    
    const compressed_path = try std.fmt.allocPrint(allocator, "{s}.gz", .{file_path});
    defer allocator.free(compressed_path);
    
    // Create backup
    try std.Io.Dir.cwd().copyFile(io, file_path, std.Io.Dir.cwd(), backup_path, .{});
    
    // Compress original
    compressFile(allocator, file_path, compressed_path, .gzip, io) catch |err| {
        // Restore from backup on error
        std.Io.Dir.cwd().copyFile(io, backup_path, std.Io.Dir.cwd(), file_path, .{}) catch {};
        std.Io.Dir.cwd().deleteFile(io, backup_path) catch {};
        return err;
    };
    
    // Remove backup on success
    try std.Io.Dir.cwd().deleteFile(io, backup_path);
    
    std.debug.print("Backed up and compressed {s}\n", .{file_path});
}
```

### File Integrity Verification

```zig
pub fn verifyCompressedFile(allocator: std.mem.Allocator, compressed_path: []const u8, original_path: ?[]const u8, io: std.Io) !bool {
    const compressed_data = try std.Io.Dir.cwd().readFileAlloc(io, compressed_path, allocator, .limited(100 * 1024 * 1024));
    defer allocator.free(compressed_data);
    
    // Decompress
    const decompressed = archive.decompress(allocator, compressed_data, .zstd) catch |err| {
        std.debug.print("Decompression failed: {}\n", .{err});
        return false;
    };
    defer allocator.free(decompressed);
    
    // Compare with original if provided
    if (original_path) |orig_path| {
        const original_data = try std.Io.Dir.cwd().readFileAlloc(io, orig_path, allocator, .limited(100 * 1024 * 1024));
        defer allocator.free(original_data);
        
        if (std.mem.eql(u8, original_data, decompressed)) {
            std.debug.print("Verification successful: files match\n", .{});
            return true;
        } else {
            std.debug.print("Verification failed: files do not match\n", .{});
            return false;
        }
    }
    
    std.debug.print("Decompression successful (no original to compare)\n", .{});
    return true;
}
```

## Configuration-Based File Operations

### Using Compression Configurations

```zig
pub fn compressWithConfig(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, config: archive.CompressionConfig, io: std.Io) !void {
    const input_data = try std.Io.Dir.cwd().readFileAlloc(io, input_path, allocator, .limited(100 * 1024 * 1024));
    defer allocator.free(input_data);
    
    const compressed = try archive.compressWithConfig(allocator, input_data, config);
    defer allocator.free(compressed);
    
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_path, .data = compressed });
    
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input_data.len)) * 100;
    std.debug.print("Compressed {s} -> {s} ({d:.1}%) using {s}\n", .{ input_path, output_path, ratio, @tagName(config.algorithm) });
}
```

### Directory Filtering

```zig
pub fn compressFilteredDirectory(allocator: std.mem.Allocator, dir_path: []const u8, output_path: []const u8, io: std.Io) !void {
    const exclude_rules = [_]archive.FilterRule{
        .{ .pattern = "*.tmp", .is_directory = false },
        .{ .pattern = "*.log", .is_directory = false },
        .{ .pattern = "*.cache", .is_directory = false },
        .{ .pattern = ".git/**", .is_directory = true },
        .{ .pattern = "node_modules/**", .is_directory = true },
    };
    
    const config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(15)
        .withPathFilter(.{ .exclude_rules = &exclude_rules })
        .withRecursive(true);
    
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    
    var files = .empty;
    try collectFilteredFiles(arena_allocator, dir_path, &files, config, io);
    
    var data = std.ArrayList(u8).empty;
    for (files.items) |file_path| {
        const file_data = try std.Io.Dir.cwd().readFileAlloc(io, file_path, arena_allocator, .limited(10 * 1024 * 1024));
        
        const path_len = @as(u32, @intCast(file_path.len));
        const data_len = @as(u32, @intCast(file_data.len));
        
        try data.appendSlice(std.mem.asBytes(&path_len));
        try data.appendSlice(file_path);
        try data.appendSlice(std.mem.asBytes(&data_len));
        try data.appendSlice(file_data);
    }
    
    const compressed = try archive.compressWithConfig(allocator, data.items, config);
    defer allocator.free(compressed);
    
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_path, .data = compressed });
    
    std.debug.print("Compressed filtered directory {s} -> {s} ({d} files)\n", .{ dir_path, output_path, files.items.len });
}

fn collectFilteredFiles(allocator: std.mem.Allocator, dir_path: []const u8, files: *std.ArrayList([]const u8), config: archive.CompressionConfig, io: std.Io) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close();
    
    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name });
        
        switch (entry.kind) {
            .file => {
                if (config.path_filter.shouldInclude(full_path, false)) {
                    try files.append(full_path);
                }
            },
            .directory => {
                if (config.path_filter.shouldInclude(full_path, true) and config.recursive) {
                    try collectFilteredFiles(allocator, full_path, files, config, io);
                }
            },
            else => {},
        }
    }
}
```

## Error Handling

### Robust File Operations

```zig
pub fn robustCompressFile(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, algorithm: archive.Algorithm, io: std.Io) !void {
    // Check if input file exists and is readable
    const input_stat = std.Io.Dir.cwd().statFile(io, input_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Error: Input file '{s}' not found\n", .{input_path});
            return err;
        },
        error.AccessDenied => {
            std.debug.print("Error: Cannot read input file '{s}' (access denied)\n", .{input_path});
            return err;
        },
        else => return err,
    };
    
    // Check file size
    if (input_stat.size > 1024 * 1024 * 1024) { // 1GB limit
        std.debug.print("Warning: File is very large ({d} bytes), this may take a while\n", .{input_stat.size});
    }
    
    // Read input file
    const input_data = std.Io.Dir.cwd().readFileAlloc(io, input_path, allocator, .limited(@intCast(input_stat.size))) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("Error: Not enough memory to read file ({d} bytes)\n", .{input_stat.size});
            return err;
        },
        else => return err,
    };
    defer allocator.free(input_data);
    
    // Compress data
    const compressed = archive.compress(allocator, input_data, algorithm) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("Error: Not enough memory for compression\n", .{});
            return err;
        },
        error.InvalidData => {
            std.debug.print("Error: Input data is invalid for compression\n", .{});
            return err;
        },
        else => return err,
    };
    defer allocator.free(compressed);
    
    // Write output file
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_path, .data = compressed }) catch |err| switch (err) {
        error.AccessDenied => {
            std.debug.print("Error: Cannot write to output file '{s}' (access denied)\n", .{output_path});
            return err;
        },
        error.NoSpaceLeft => {
            std.debug.print("Error: No space left on device for output file '{s}'\n", .{output_path});
            return err;
        },
        else => return err,
    };
    
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input_data.len)) * 100;
    std.debug.print("Successfully compressed {s} -> {s} ({d:.1}%)\n", .{ input_path, output_path, ratio });
}
```

## Next Steps

- Learn about [Streaming](./streaming.md) for memory-efficient processing
- Explore [Error Handling](./errors.md) for robust applications
- Check out [Memory Management](./memory.md) for optimization
- See [Examples](../examples/file-operations.md) for practical usage