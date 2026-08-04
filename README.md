
<div align="center">
  <h1> Archive.zig</h1> 

  <a href="https://muhammad-fiaz.github.io/archive.zig/"><img src="https://img.shields.io/badge/docs-muhammad--fiaz.github.io-blue" alt="Documentation"></a>
  <a href="https://ziglang.org/"><img src="https://img.shields.io/badge/Zig-0.16.0-orange.svg?logo=zig" alt="Zig Version"></a>
  <a href="https://github.com/muhammad-fiaz/archive.zig"><img src="https://img.shields.io/github/stars/muhammad-fiaz/archive.zig" alt="GitHub stars"></a>
  <a href="https://github.com/muhammad-fiaz/archive.zig/issues"><img src="https://img.shields.io/github/issues/muhammad-fiaz/archive.zig" alt="GitHub issues"></a>
  <a href="https://github.com/muhammad-fiaz/archive.zig/pulls"><img src="https://img.shields.io/github/issues-pr/muhammad-fiaz/archive.zig" alt="GitHub pull requests"></a>
  <a href="https://github.com/muhammad-fiaz/archive.zig"><img src="https://img.shields.io/github/last-commit/muhammad-fiaz/archive.zig" alt="GitHub last commit"></a>
  <a href="https://github.com/muhammad-fiaz/archive.zig"><img src="https://img.shields.io/github/license/muhammad-fiaz/archive.zig" alt="License"></a>
  <a href="https://github.com/muhammad-fiaz/archive.zig/actions/workflows/ci.yml"><img src="https://github.com/muhammad-fiaz/archive.zig/actions/workflows/ci.yml/badge.svg" alt="CI"></a>
  <img src="https://img.shields.io/badge/platforms-linux%20%7C%20windows%20%7C%20macos-blue" alt="Supported Platforms">
  <a href="https://github.com/muhammad-fiaz/archive.zig/actions/workflows/github-code-scanning/codeql"><img src="https://github.com/muhammad-fiaz/archive.zig/actions/workflows/github-code-scanning/codeql/badge.svg" alt="CodeQL"></a>
  <a href="https://github.com/muhammad-fiaz/archive.zig/actions/workflows/release.yml"><img src="https://github.com/muhammad-fiaz/archive.zig/actions/workflows/release.yml/badge.svg" alt="Release"></a>
  <a href="https://github.com/muhammad-fiaz/archive.zig/releases/latest"><img src="https://img.shields.io/github/v/release/muhammad-fiaz/archive.zig?label=Latest%20Release&style=flat-square" alt="Latest Release"></a>
  <a href="https://pay.muhammadfiaz.com"><img src="https://img.shields.io/badge/Sponsor-pay.muhammadfiaz.com-ff69b4?style=flat&logo=heart" alt="Sponsor"></a>
  <a href="https://github.com/sponsors/muhammad-fiaz"><img src="https://img.shields.io/badge/Sponsor-💖-pink?style=social&logo=github" alt="GitHub Sponsors"></a>
  <a href="https://hits.sh/muhammad-fiaz/archive.zig/"><img src="https://hits.sh/muhammad-fiaz/archive.zig.svg?label=Visitors&extraCount=0&color=green" alt="Repo Visitors"></a>

  <p><em>A comprehensive, high-performance archive and compression library for Zig.</em></p>

  <b>
    <a href="https://muhammad-fiaz.github.io/archive.zig/">Documentation</a> |
    <a href="https://muhammad-fiaz.github.io/archive.zig/api/archive">API Reference</a> |
    <a href="https://muhammad-fiaz.github.io/archive.zig/guide/quick-start">Quick Start</a> |
    <a href="CONTRIBUTING.md">Contributing</a>
  </b>
</div>

All-in-One archive and compression library for Zig, supporting multiple compression algorithms and archive formats with a clean, explicit API.

**⭐️ If you love `archive.zig`, make sure to give it a star! ⭐️**

---

<details>
<summary><strong>Table of Contents</strong> (click to expand)</summary>

- [Prerequisites](#prerequisites)
- [Supported Platforms](#supported-platforms)
- [Supported Algorithms](#supported-algorithms)
- [Installation](#installation)
  - [Method 1: Zig Fetch (Recommended)](#method-1-zig-fetch-recommended)
  - [Method 2: Manual Configuration](#method-2-manual-configuration)
  - [Method 3: Building from Source](#method-3-building-from-source)
- [Quick Start](#quick-start)
- [Usage Examples](#usage-examples)
  - [Basic Compression](#basic-compression)
  - [Configuration Presets](#configuration-presets)
  - [Builder Pattern](#builder-pattern)
  - [File Operations](#file-operations)
  - [Streaming Interface](#streaming-interface)
- [Configuration](#configuration)
- [API Reference](#api-reference)
- [Building](#building)
- [Documentation](#documentation)
- [Contributing](#contributing)
- [License](#license)
- [Links](#links)

</details>

---

<details>
<summary><strong>Features of Archive.zig</strong> (click to expand)</summary>

| Feature | Description | Documentation |
|---------|-------------|---------------|
| **Multiple Algorithms** | Support for 10 compression algorithms: gzip, zlib, deflate, zstd, lz4, lzma, xz, tar.gz, zip, brotli | [Docs](https://muhammad-fiaz.github.io/archive.zig/guide/algorithms) |
| **Explicit API** | Always specify the algorithm - no magic, no guessing | [Docs](https://muhammad-fiaz.github.io/archive.zig/guide/getting-started) |
| **Configuration Presets** | Pre-configured settings for fast, balanced, best compression, and production use | [Docs](https://muhammad-fiaz.github.io/archive.zig/guide/configuration) |
| **Builder Pattern** | Fluent API for configuring compression with method chaining | [Docs](https://muhammad-fiaz.github.io/archive.zig/guide/builder) |
| **Streaming Interface** | Memory-efficient streaming compression and decompression | [Docs](https://muhammad-fiaz.github.io/archive.zig/guide/streaming) |
| **Full Customization** | Every algorithm exposes all options: levels, checksums, dictionary, window size, threads | [Docs](https://muhammad-fiaz.github.io/archive.zig/api/config) |
| **Cross-Platform** | Works on Windows, Linux, macOS, and bare metal targets | [Docs](https://muhammad-fiaz.github.io/archive.zig/guide/platforms) |
| **Thread-Safe** | Safe concurrent compression from multiple threads | [Docs](https://muhammad-fiaz.github.io/archive.zig/guide/threading) |
| **Memory Efficient** | Optimized memory usage with configurable buffer sizes | [Docs](https://muhammad-fiaz.github.io/archive.zig/guide/memory) |
| **Error Handling** | Comprehensive error types and proper error propagation | [Docs](https://muhammad-fiaz.github.io/archive.zig/guide/errors) |

</details>

---

<details>
<summary><strong>Prerequisites & Supported Platforms</strong> (click to expand)</summary>

## Prerequisites

Before installing Archive.zig, ensure you have the following:

| Requirement | Version | Notes |
|-------------|---------|-------|
| **Zig** | 0.16.0+ | Download from [ziglang.org](https://ziglang.org/download/) |
| **Operating System** | Windows 10+, Linux, macOS | Cross-platform support |
| **Memory** | 64MB+ available | For compression operations |

> Verify your Zig installation by running `zig version` in your terminal.

---

## Supported Platforms

Archive.zig supports a wide range of platforms and architectures:

| Platform | Architectures | Status |
|----------|---------------|--------|
| **Windows** | x86_64, x86 | Full support |
| **Linux** | x86_64, x86, aarch64 | Full support |
| **macOS** | x86_64, aarch64 (Apple Silicon) | Full support |
| **Bare Metal / Freestanding** | x86_64, aarch64, arm, riscv64 | Full support |

---

## Supported Algorithms

| Algorithm | Extension | Description | Performance |
|-----------|-----------|-------------|-------------|
| **gzip** | `.gz` | GNU zip compression with CRC32 | Fast |
| **zlib** | `.zlib` | Deflate with Adler32 checksum | Fast |
| **deflate** | `.deflate` | Raw deflate compression | Fastest |
| **zstd** | `.zst` | Zstandard - modern, fast compression | Very Fast |
| **lz4** | `.lz4` | Ultra-fast compression | Fastest |
| **lzma** | `.lzma` | High compression ratio | Slow |
| **xz** | `.xz` | LZMA2-based compression | Slow |
| **tar.gz** | `.tar.gz` | TAR archive with gzip compression | Fast |
| **zip** | `.zip` | ZIP archive format | Fast |
| **brotli** | `.br` | Brotli - high compression ratio | Moderate |

</details>

---

## Installation

### Method 1: Zig Fetch (Recommended)

The easiest way to add Archive.zig to your project:

```bash
zig fetch --save https://github.com/muhammad-fiaz/archive.zig/archive/refs/tags/0.0.2.tar.gz
```

This automatically adds the dependency with the correct hash to your `build.zig.zon`.

### Method 2: Manual Configuration

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

### Method 3: Building from Source

Clone the repository and build Archive.zig:

```bash
git clone https://github.com/muhammad-fiaz/archive.zig.git
cd archive.zig
zig build
```

## Quick Start

```zig
const std = @import("std");
const archive = @import("archive");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const input = "Hello, World! This is a test of the archive library.";
    
    // Compress with explicit algorithm
    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);
    
    // Decompress with same algorithm
    const decompressed = try archive.decompress(allocator, compressed, .gzip);
    defer allocator.free(decompressed);
    
    std.debug.print("Original: {s}\n", .{input});
    std.debug.print("Decompressed: {s}\n", .{decompressed});
    std.debug.print("Compression ratio: {d:.1}%\n", .{
        @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100
    });
}
```

## Usage Examples

### Basic Compression

```zig
const std = @import("std");
const archive = @import("archive");

pub fn basicCompression(allocator: std.mem.Allocator) !void {
    const input = "Hello, World! This is a test of compression.";
    
    // Try different algorithms
    const algorithms = [_]archive.Algorithm{
        .gzip, .zlib, .deflate, .zstd, .lz4, .lzma, .xz, .tar_gz, .zip, .brotli
    };
    
    for (algorithms) |algo| {
        const compressed = try archive.compress(allocator, input, algo);
        defer allocator.free(compressed);
        
        const decompressed = try archive.decompress(allocator, compressed, algo);
        defer allocator.free(decompressed);
        
        const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100;
        std.debug.print("{s}: {d} bytes ({d:.1}%)\n", .{ @tagName(algo), compressed.len, ratio });
    }
}
```

### Configuration Presets

```zig
pub fn configurationPresets(allocator: std.mem.Allocator) !void {
    const input = "Configuration preset test data for compression.";
    
    // Builder pattern for configuration
    const presets = [_]archive.CompressionConfig{
        archive.CompressionConfig.init(.gzip).withLevel(.fastest),
        archive.CompressionConfig.init(.gzip).withLevel(.default),
        archive.CompressionConfig.init(.gzip).withLevel(.best),
        archive.CompressionConfig.init(.zstd).withZstdLevel(3),
        archive.CompressionConfig.init(.zstd).withZstdLevel(19),
    };
    
    for (presets) |preset| {
        const compressed = try archive.compressWithConfig(allocator, input, preset);
        defer allocator.free(compressed);
        
        std.debug.print("Preset: {d} bytes\n", .{compressed.len});
    }
}
```

### Builder Pattern

```zig
pub fn builderPattern(allocator: std.mem.Allocator) !void {
    const input = "Builder pattern example data.";
    
    // Configure compression with builder pattern
    const compressor = archive.Compressor.init(allocator, .gzip)
        .withLevel(6)
        .withChecksum();
    
    const compressed = try compressor.compress_data(input);
    defer allocator.free(compressed);
    
    const decompressed = try compressor.decompress_data(compressed);
    defer allocator.free(decompressed);
    
    std.debug.print("Builder pattern: {d} bytes\n", .{compressed.len});
}
```

### File Operations

File I/O uses `std.Io.Dir.cwd()` with the `io` handle from `std.process.Init`:

```zig
pub fn fileOperations(allocator: std.mem.Allocator, io: std.Io) !void {
    const input = "This is test data for file compression.";
    
    // Read file
    const file_data = try std.Io.Dir.cwd().readFileAlloc(io, "input.txt", allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(file_data);
    
    // Compress with explicit algorithm
    const compressed = try archive.compress(allocator, file_data, .zstd);
    defer allocator.free(compressed);
    
    // Write compressed file
    const out_file = try std.Io.Dir.cwd().createFile(io, "output.zst", .{});
    defer out_file.close();
    try out_file.writeAll(compressed);
    
    // Read compressed file back
    const read_data = try std.Io.Dir.cwd().readFileAlloc(io, "output.zst", allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(read_data);
    
    // Decompress with same algorithm
    const decompressed = try archive.decompress(allocator, read_data, .zstd);
    defer allocator.free(decompressed);
    
    std.debug.print("Verified: {}\n", .{std.mem.eql(u8, file_data, decompressed)});
    
    // Cleanup
    std.fs.cwd().deleteFile("output.zst") catch {};
}
```

### Streaming Interface

```zig
const stream = archive.stream;

pub fn streamingInterface(allocator: std.mem.Allocator) !void {
    const input = "Large data for streaming compression...";
    
    // Create streaming compressor
    var compressor = try stream.CompressStream.init(allocator, .gzip, .default);
    defer compressor.deinit();
    
    // Compress in chunks
    try compressor.write(input[0..10]);
    try compressor.write(input[10..]);
    const compressed = try compressor.finish();
    defer allocator.free(compressed);
    
    // Create streaming decompressor (must specify algorithm)
    var decompressor = stream.DecompressStream.init(allocator, .gzip);
    defer decompressor.deinit();
    
    // Write compressed data and finish
    try decompressor.write(compressed);
    const decompressed = try decompressor.finish();
    defer allocator.free(decompressed);
    
    std.debug.print("Streaming: {s}\n", .{decompressed});
}
```

## Configuration

```zig
// Basic configuration from algorithm
const cfg = archive.CompressionConfig.init(.zstd);

// Builder pattern with method chaining
const cfg = archive.CompressionConfig.init(.zstd)
    .withLevel(.best)                // Set level enum
    .withCustomLevel(15)             // Or numeric level (clamped)
    .withChecksum()                  // Enable checksum
    .withMode(.compress)             // Set mode
    .withDictionary(dict_data)       // Set dictionary
    .withWindowSize(1 << 22)         // Window size
    .withMemoryLevel(8)              // Memory level (1-9)
    .withStrategy(.filtered)         // Strategy
    .withThreads(4)                  // Thread count
    .withKeepOriginal()              // Keep original
    .withOverwriteExisting()         // Overwrite
    .withRecursive(false)            // Disable recursion
    .withFollowSymlinks()            // Follow symlinks
    .withMaxDepth(3)                 // Max depth
    .withSizeRange(100, 1000000);    // Min/max file size

// Use configuration
const compressed = try archive.compressWithConfig(allocator, data, cfg);

// Zstd-specific level
const zstd_cfg = archive.CompressionConfig.init(.zstd).withZstdLevel(15);

// LZ4-specific level
const lz4_cfg = archive.CompressionConfig.init(.lz4).withLz4Level(9);
```

## API Reference

### Core Functions

```zig
// Basic compression/decompression (algorithm is required)
pub fn compress(allocator: Allocator, data: []const u8, algorithm: Algorithm) ![]u8
pub fn decompress(allocator: Allocator, data: []const u8, algorithm: Algorithm) ![]u8

// With full configuration
pub fn compressWithConfig(allocator: Allocator, data: []const u8, config: CompressionConfig) ![]u8
pub fn decompressWithConfig(allocator: Allocator, data: []const u8, config: CompressionConfig) ![]u8
```

### Algorithms

```zig
pub const Algorithm = enum {
    none,
    raw_deflate,
    deflate,
    gzip,
    zlib,
    zstd,
    lz4,
    lzma,
    lzma2,
    xz,
    tar_gz,
    zip,
    brotli,

    pub fn extension(self: Algorithm) []const u8
    pub fn getDefaultLevel(self: Algorithm) u8
    pub fn getMinLevel(self: Algorithm) u8
    pub fn getMaxLevel(self: Algorithm) u8
};
```

### Configuration

```zig
pub const CompressionConfig = struct {
    algorithm: Algorithm,
    level: Level,
    custom_level: ?u8,
    zstd_level: ?c_int,
    lz4_level: ?c_int,
    checksum: bool,
    mode: CompressionMode,
    path_filter: PathFilter,
    recursive: bool,
    follow_symlinks: bool,
    max_depth: ?u32,
    min_file_size: u64,
    max_file_size: ?u64,
    buffer_size: usize,
    dictionary: ?[]const u8,
    threads: u32,

    pub fn init(algorithm: Algorithm) CompressionConfig
    pub fn withLevel(self: CompressionConfig, level: Level) CompressionConfig
    pub fn withCustomLevel(self: CompressionConfig, level: u8) CompressionConfig
    pub fn withZstdLevel(self: CompressionConfig, level: c_int) CompressionConfig
    pub fn withLz4Level(self: CompressionConfig, level: c_int) CompressionConfig
    pub fn withChecksum(self: CompressionConfig) CompressionConfig
    pub fn withMode(self: CompressionConfig, mode: CompressionMode) CompressionConfig
    pub fn withDictionary(self: CompressionConfig, dict: []const u8) CompressionConfig
    pub fn withWindowSize(self: CompressionConfig, size: usize) CompressionConfig
    pub fn withMemoryLevel(self: CompressionConfig, level: u8) CompressionConfig
    pub fn withStrategy(self: CompressionConfig, strategy: Strategy) CompressionConfig
    pub fn withThreads(self: CompressionConfig, threads: u32) CompressionConfig
    pub fn withKeepOriginal(self: CompressionConfig) CompressionConfig
    pub fn withOverwriteExisting(self: CompressionConfig) CompressionConfig
    pub fn withRecursive(self: CompressionConfig, recursive: bool) CompressionConfig
    pub fn withFollowSymlinks(self: CompressionConfig) CompressionConfig
    pub fn withMaxDepth(self: CompressionConfig, depth: u32) CompressionConfig
    pub fn withSizeRange(self: CompressionConfig, min_size: u64, max_size: ?u64) CompressionConfig
};
```

## Building

```bash
# Run tests
zig build test

# Build library
zig build

# Run examples
zig build run

# Build documentation
zig build docs
```

## Documentation

### Online Documentation

Full documentation is available at: https://muhammad-fiaz.github.io/archive.zig

### Generating Local Documentation

To generate documentation locally:

```bash
zig build docs
```

This will generate HTML documentation in the `zig-out/docs/` directory.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License. See the [LICENSE](https://github.com/muhammad-fiaz/archive.zig/blob/main/LICENSE) file for details.

## Links

- **Documentation**: https://muhammad-fiaz.github.io/archive.zig
- **Repository**: https://github.com/muhammad-fiaz/archive.zig
- **Issues**: https://github.com/muhammad-fiaz/archive.zig/issues
- **Releases**: https://github.com/muhammad-fiaz/archive.zig/releases
