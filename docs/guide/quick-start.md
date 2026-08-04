# Quick Start

Get up and running with Archive.zig in minutes. This guide covers the most common usage patterns.

## Basic Compression

The simplest way to compress data:

```zig
const std = @import("std");
const archive = @import("archive");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    const input = "Hello, Archive.zig!";
    
    // Compress
    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);
    
    // Decompress
    const decompressed = try archive.decompress(allocator, compressed, .gzip);
    defer allocator.free(decompressed);
    
    std.debug.print("Success: {}\n", .{std.mem.eql(u8, input, decompressed)});
}
```

## Algorithm Comparison

Try different algorithms to see which works best for your data:

```zig
const algorithms = [_]archive.Algorithm{ .gzip, .zlib, .zstd, .lz4 };
const input = "Your data here " ** 10;

for (algorithms) |algo| {
    const compressed = try archive.compress(allocator, input, algo);
    defer allocator.free(compressed);
    
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;
    std.debug.print("{s}: {d:.1}% of original size\n", .{ @tagName(algo), ratio });
}
```

## Explicit Algorithm Selection

Always specify your algorithm explicitly:

```zig
// Compress with explicit algorithm
const compressed = try archive.compress(allocator, input, .zstd);
defer allocator.free(compressed);

// Decompress with same algorithm
const decompressed = try archive.decompress(allocator, compressed, .zstd);
defer allocator.free(decompressed);
```

## File Operations

Work directly with files:

```zig
const std = @import("std");
const archive = @import("archive");

pub fn compressFile(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, io: std.Io) !void {
    // Read input file
    const input_data = try std.Io.Dir.cwd().readFileAlloc(io, input_path, allocator, .limited(1024 * 1024 * 10)); // 10MB max
    defer allocator.free(input_data);
    
    // Compress
    const compressed = try archive.compress(allocator, input_data, .gzip);
    defer allocator.free(compressed);
    
    // Write compressed file
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_path, .data = compressed });
    
    std.debug.print("Compressed {s} -> {s}\n", .{ input_path, output_path });
}
```

## Configuration

Use custom compression settings:

```zig
// High compression
const config = archive.CompressionConfig.init(.zstd)
    .withZstdLevel(19)
    .withChecksum();

const compressed = try archive.compressWithConfig(allocator, input, config);
defer allocator.free(compressed);
```

## Error Handling

Handle compression errors gracefully:

```zig
const compressed = archive.compress(allocator, input, .gzip) catch |err| switch (err) {
    error.OutOfMemory => {
        std.debug.print("Not enough memory for compression\n", .{});
        return;
    },
    error.InvalidData => {
        std.debug.print("Input data is invalid\n", .{});
        return;
    },
    else => return err,
};
defer allocator.free(compressed);
```

## Memory Management

Use arena allocators for temporary operations:

```zig
pub fn processData(allocator: std.mem.Allocator, data: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit(); // Cleans up all allocations
    
    const arena_allocator = arena.allocator();
    
    // All allocations use arena - no need for individual free() calls
    const compressed = try archive.compress(arena_allocator, data, .lz4);
    const decompressed = try archive.decompress(arena_allocator, compressed, .lz4);
    
    // Process the data...
    std.debug.print("Processed {d} bytes\n", .{decompressed.len});
    
    // arena.deinit() automatically frees everything
}
```

## Common Patterns

### Compress Multiple Files

```zig
const files = [_][]const u8{ "file1.txt", "file2.txt", "file3.txt" };

for (files) |filename| {
    const input_data = try std.Io.Dir.cwd().readFileAlloc(io, filename, allocator, .limited(1024 * 1024));
    defer allocator.free(input_data);
    
    const compressed = try archive.compress(allocator, input_data, .gzip);
    defer allocator.free(compressed);
    
    const output_name = try std.fmt.allocPrint(allocator, "{s}.gz", .{filename});
    defer allocator.free(output_name);
    
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_name, .data = compressed });
}
```

### Streaming Large Files

```zig
pub fn compressLargeFile(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, io: std.Io) !void {
    const input_file = try std.Io.Dir.cwd().openFile(io, input_path, .{});
    defer input_file.close();
    
    const output_file = try std.Io.Dir.cwd().createFile(io, output_path, .{});
    defer output_file.close();
    
    var buffer: [8192]u8 = undefined;
    var total_compressed: usize = 0;
    
    while (true) {
        const bytes_read = try input_file.readAll(&buffer);
        if (bytes_read == 0) break;
        
        const compressed = try archive.compress(allocator, buffer[0..bytes_read], .lz4);
        defer allocator.free(compressed);
        
        _ = try output_file.writeAll(compressed);
        total_compressed += compressed.len;
    }
    
    std.debug.print("Compressed to {d} bytes\n", .{total_compressed});
}
```

### Benchmark Algorithms

```zig
pub fn benchmarkAlgorithms(allocator: std.mem.Allocator, data: []const u8) !void {
    const algorithms = [_]archive.Algorithm{ .lz4, .gzip, .zstd, .lzma };
    
    std.debug.print("Algorithm | Size | Time (ms)\n");
    std.debug.print("----------|------|----------\n");
    
    for (algorithms) |algo| {
        const start = std.time.nanoTimestamp();
        const compressed = try archive.compress(allocator, data, algo);
        defer allocator.free(compressed);
        const end = std.time.nanoTimestamp();
        
        const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
        std.debug.print("{s:>9} | {d:>4} | {d:>8.2}\n", .{ @tagName(algo), compressed.len, duration_ms });
    }
}
```

## Next Steps

Now that you know the basics:

- Learn about [Algorithms](./algorithms.md) in detail
- Explore [Configuration](./configuration.md) options
- Try [File Operations](./file-operations.md)
- Check out [Streaming](./streaming.md) for large files
- See more [Examples](../examples/basic.md)