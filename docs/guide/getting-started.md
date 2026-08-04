# Getting Started

Welcome to Archive.zig! This guide will help you get up and running with the library quickly.

## Installation

### Using Zig Package Manager (Recommended)

The easiest way to add Archive.zig to your project:

```bash
zig fetch --save https://github.com/muhammad-fiaz/archive.zig/archive/refs/tags/0.0.2.tar.gz
```

This automatically adds the dependency with the correct hash to your `build.zig.zon`.

### Manual Configuration

Add to your `build.zig.zon`:

```zig
.dependencies = .{
    .archive = .{
        .url = "https://github.com/muhammad-fiaz/archive.zig/archive/refs/tags/0.0.2.tar.gz",
        .hash = "...", // Run zig fetch to get the hash
    },
},
```

Then in your `build.zig`:

```zig
const archive = b.dependency("archive", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("archive", archive.module("archive"));
```

## Your First Program

Create a simple program that compresses and decompresses data:

```zig
const std = @import("std");
const archive = @import("archive");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    // Original data
    const input = "Hello, Archive.zig! This is a compression test.";
    std.debug.print("Original: {s} ({d} bytes)\n", .{ input, input.len });

    // Compress with gzip
    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);
    std.debug.print("Compressed: {d} bytes\n", .{compressed.len});

    // Decompress
    const decompressed = try archive.decompress(allocator, compressed, .gzip);
    defer allocator.free(decompressed);
    std.debug.print("Decompressed: {s}\n", .{decompressed});

    // Verify
    const success = std.mem.eql(u8, input, decompressed);
    std.debug.print("Success: {}\n", .{success});
}
```

## Trying Different Algorithms

Archive.zig supports multiple compression algorithms:

```zig
const algorithms = [_]archive.Algorithm{
    .gzip,    // GNU zip format
    .zlib,    // zlib format
    .deflate, // Raw deflate
    .zstd,    // Zstandard
    .lz4,     // LZ4
    .lzma,    // LZMA
    .xz,      // XZ format
    .tar_gz,  // TAR + gzip
    .zip,     // ZIP format
    .brotli,  // Brotli compression
};

for (algorithms) |algo| {
    const compressed = try archive.compress(allocator, input, algo);
    defer allocator.free(compressed);
    
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;
    std.debug.print("{s}: {d} bytes ({d:.1}%)\n", .{ @tagName(algo), compressed.len, ratio });
}
```

## Next Steps

- Learn about [Configuration](./configuration.md) options
- Explore [File Operations](./file-operations.md)
- Try the [Builder Pattern](./builder.md)
- Check out [Auto-Detection](./auto-detection.md)
- See more [Examples](../examples/basic.md)