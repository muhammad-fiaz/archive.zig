# Basic Usage Examples

This page shows basic usage patterns for Archive.zig.

## Simple Compression

The most basic usage - compress and decompress data:

```zig
const std = @import("std");
const archive = @import("archive");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const input = "Hello, Archive.zig!";
    
    // Compress
    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);
    
    // Decompress
    const decompressed = try archive.decompress(allocator, compressed, .gzip);
    defer allocator.free(decompressed);
    
    std.debug.print("Original: {s}\n", .{input});
    std.debug.print("Compressed: {d} bytes\n", .{compressed.len});
    std.debug.print("Decompressed: {s}\n", .{decompressed});
}
```

## Algorithm Comparison

Compare different algorithms on the same data:

```zig
pub fn compareAlgorithms(allocator: std.mem.Allocator) !void {
    const input = "This is a test string for compression comparison. " ** 10;
    
    const algorithms = [_]struct { algo: archive.Algorithm, name: []const u8 }{
        .{ .algo = .gzip, .name = "gzip" },
        .{ .algo = .zlib, .name = "zlib" },
        .{ .algo = .deflate, .name = "deflate" },
        .{ .algo = .zstd, .name = "zstd" },
        .{ .algo = .lz4, .name = "lz4" },
        .{ .algo = .brotli, .name = "brotli" },
    };
    
    std.debug.print("Original size: {d} bytes\n", .{input.len});
    std.debug.print("Algorithm | Compressed | Ratio\n");
    std.debug.print("----------|------------|------\n");
    
    for (algorithms) |item| {
        const compressed = try archive.compress(allocator, input, item.algo);
        defer allocator.free(compressed);
        
        const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;
        std.debug.print("{s:>9} | {d:>10} | {d:>5.1}%\n", .{ item.name, compressed.len, ratio });
    }
}
```

## Error Handling

Proper error handling for compression operations:

```zig
pub fn safeCompression(allocator: std.mem.Allocator, data: []const u8) !void {
    const compressed = archive.compress(allocator, data, .gzip) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("Error: Not enough memory for compression\n", .{});
            return;
        },
        error.InvalidData => {
            std.debug.print("Error: Invalid input data\n", .{});
            return;
        },
        else => {
            std.debug.print("Error: Compression failed: {}\n", .{err});
            return err;
        },
    };
    defer allocator.free(compressed);
    
    const decompressed = archive.decompress(allocator, compressed, .gzip) catch |err| switch (err) {
        error.CorruptedStream => {
            std.debug.print("Error: Compressed data is corrupted\n", .{});
            return;
        },
        error.ChecksumMismatch => {
            std.debug.print("Error: Checksum verification failed\n", .{});
            return;
        },
        else => {
            std.debug.print("Error: Decompression failed: {}\n", .{err});
            return err;
        },
    };
    defer allocator.free(decompressed);
    
    std.debug.print("Compression successful!\n", .{});
}
```

## Memory Management

Proper memory management patterns:

```zig
pub fn memoryManagement(allocator: std.mem.Allocator) !void {
    const input = "Data to compress";
    
    // Method 1: Manual cleanup
    {
        const compressed = try archive.compress(allocator, input, .gzip);
        defer allocator.free(compressed); // Always free compressed data
        
        const decompressed = try archive.decompress(allocator, compressed, .gzip);
        defer allocator.free(decompressed); // Always free decompressed data
        
        // Use the data...
    }
    
    // Method 2: Arena allocator for temporary operations
    {
        var arena = std.heap.ArenaAllocator.init(allocator);
        defer arena.deinit(); // Frees all arena memory at once
        
        const arena_allocator = arena.allocator();
        
        const compressed = try archive.compress(arena_allocator, input, .gzip);
        const decompressed = try archive.decompress(arena_allocator, compressed, .gzip);
        
        // No need for individual free() calls - arena.deinit() handles it
    }
}
```

## Working with Different Data Types

Examples of compressing different types of data:

```zig
pub fn differentDataTypes(allocator: std.mem.Allocator) !void {
    // String data
    const text = "Hello, World!";
    const text_compressed = try archive.compress(allocator, text, .gzip);
    defer allocator.free(text_compressed);
    
    // Binary data
    const binary_data = [_]u8{ 0x00, 0x01, 0x02, 0x03, 0xFF, 0xFE, 0xFD };
    const binary_compressed = try archive.compress(allocator, &binary_data, .lz4);
    defer allocator.free(binary_compressed);
    
    // Struct data (serialized)
    const Point = struct { x: f32, y: f32 };
    const point = Point{ .x = 1.5, .y = 2.5 };
    const point_bytes = std.mem.asBytes(&point);
    const point_compressed = try archive.compress(allocator, point_bytes, .zstd);
    defer allocator.free(point_compressed);
    
    std.debug.print("Text compressed: {d} bytes\n", .{text_compressed.len});
    std.debug.print("Binary compressed: {d} bytes\n", .{binary_compressed.len});
    std.debug.print("Struct compressed: {d} bytes\n", .{point_compressed.len});
}
```