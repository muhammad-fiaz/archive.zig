---
layout: home

hero:
  name: "Archive.zig"
  text: "All in One archive/compression library for Zig."
  tagline: "Comprehensive compression and archive support for Zig with multiple algorithms and streaming capabilities"
  image:
    src: /logo.png
    alt: Archive.zig
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
    - theme: alt
      text: View on GitHub
      link: https://github.com/muhammad-fiaz/archive.zig

features:
  - icon: ⚡
    title: High Performance
    details: Optimized implementations of compression algorithms with minimal overhead and efficient memory usage.
  - icon: 🔧
    title: Multiple Algorithms
    details: Support for 10 compression formats - gzip, zlib, deflate, zstd, lz4, lzma, xz, tar.gz, zip, and brotli.
  - icon: 🌊
    title: Streaming Support
    details: Memory-efficient streaming compression and decompression for large files and real-time data.
  - icon: 🎯
    title: Simple API
    details: Clean, intuitive API with builder pattern support and automatic algorithm detection.
  - icon: 🔍
    title: Auto-Detection
    details: Automatically detect compression algorithms from file headers and magic bytes.
  - icon: 🛠️
    title: Configuration
    details: Flexible configuration with presets for different use cases - fast, balanced, best compression.
  - icon: 📁
    title: File Operations
    details: Direct file compression and decompression with proper error handling and cleanup.
  - icon: 🌐
    title: Cross-Platform
    details: Works on Windows, Linux, macOS, and bare metal targets with consistent behavior.
  - icon: 🧵
    title: Thread-Safe
    details: Safe concurrent compression from multiple threads with proper synchronization.
---

## Quick Example

```zig
const std = @import("std");
const archive = @import("archive");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    // Compress data
    const input = "Hello, Archive.zig!";
    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);

    // Decompress data
    const decompressed = try archive.decompress(allocator, compressed, .gzip);
    defer allocator.free(decompressed);

    std.debug.print("Original: {s}\n", .{input});
    std.debug.print("Compressed: {d} bytes\n", .{compressed.len});
    std.debug.print("Decompressed: {s}\n", .{decompressed});
}
```

## Supported Algorithms

| Algorithm | Extension | Description | Performance |
|-----------|-----------|-------------|-------------|
| **gzip** | `.gz` | GNU zip with CRC32 | Fast |
| **zlib** | `.zlib` | Deflate with Adler32 | Fast |
| **deflate** | `.deflate` | Raw deflate | Fastest |
| **zstd** | `.zst` | Modern compression | Very Fast |
| **lz4** | `.lz4` | Ultra-fast compression | Fastest |
| **lzma** | `.lzma` | High compression ratio | Slow |
| **xz** | `.xz` | LZMA2-based | Slow |
| **tar.gz** | `.tar.gz` | TAR + gzip | Fast |
| **zip** | `.zip` | ZIP archive format | Fast |
| **brotli** | `.br` | Brotli compression | Fast |

## Installation

Add Archive.zig to your project with Zig's package manager:

```bash
zig fetch --save https://github.com/muhammad-fiaz/archive.zig/archive/refs/tags/0.0.2.tar.gz
```

Then add to your `build.zig`:

```zig
const archive = b.dependency("archive", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("archive", archive.module("archive"));
```

## Why Archive.zig?

- **🚀 Performance**: Optimized implementations with minimal allocations
- **🔧 Flexibility**: Multiple algorithms and configuration options
- **📚 Simple**: Clean API that's easy to learn and use
- **🛡️ Reliable**: Comprehensive error handling and memory safety
- **🌍 Portable**: Cross-platform support including bare metal
- **📖 Documented**: Extensive documentation and examples