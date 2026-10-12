# Algorithms

Archive.zig supports 10 different compression algorithms, each optimized for different use cases. This guide helps you choose the right algorithm for your needs.

## Algorithm Overview

| Algorithm | Speed | Ratio | Use Case |
|-----------|-------|-------|----------|
| **LZ4** | Fastest | Low | Real-time, gaming |
| **Deflate** | Fast | Medium | Web, HTTP |
| **Gzip** | Fast | Medium | Files, archives |
| **Zlib** | Fast | Medium | PNG, protocols |
| **Zstd** | Very Fast | High | Modern applications |
| **LZMA** | Slow | Very High | Long-term storage |
| **XZ** | Slow | Very High | Distribution packages |
| **TAR.GZ** | Fast | Medium | Unix archives |
| **ZIP** | Fast | Medium | Cross-platform archives |
| **Brotli** | Fast | High | Web, general purpose |

## Detailed Algorithm Guide

### LZ4 - Ultra-Fast Compression

**Best for**: Real-time applications, gaming, temporary files

```zig
const compressed = try archive.compress(allocator, data, .lz4);
```

**Characteristics**:
- Extremely fast compression and decompression
- Low compression ratio
- Minimal CPU usage
- Great for temporary data or when speed is critical

**Configuration**:
```zig
const config = archive.CompressionConfig.init(.lz4)
    .withLevel(.fastest);  // LZ4 is already optimized for speed
```

### Deflate - Raw Compression

**Best for**: HTTP compression, when you need raw compressed data

```zig
const compressed = try archive.compress(allocator, data, .deflate);
```

**Characteristics**:
- No headers or checksums (raw compressed data)
- Fastest of the deflate family
- Used in HTTP gzip encoding
- Minimal overhead

### Gzip - GNU Zip Format

**Best for**: File compression, web content, general purpose

```zig
const compressed = try archive.compress(allocator, data, .gzip);
```

**Characteristics**:
- Includes CRC32 checksum for integrity
- Standard file compression format
- Good balance of speed and compression
- Widely supported

**Configuration**:
```zig
const config = archive.CompressionConfig.init(.gzip)
    .withLevel(.best)           // Compression level 1-9
    .withStrategy(.huffman_only) // Compression strategy
    .withChecksum();            // Enable checksum verification
```

### Zlib - Deflate with Adler32

**Best for**: PNG images, network protocols, embedded data

```zig
const compressed = try archive.compress(allocator, data, .zlib);
```

**Characteristics**:
- Deflate compression with Adler32 checksum
- Faster checksum than CRC32
- Used in PNG, PDF, and many protocols
- Compact header

### Zstd - Modern High-Performance

**Best for**: Modern applications, databases, network transmission

```zig
const compressed = try archive.compress(allocator, data, .zstd);
```

**Characteristics**:
- Excellent compression ratio and speed
- Levels 1-22 (higher = better compression)
- Dictionary support for similar data
- Modern algorithm with active development

**Configuration**:
```zig
const config = archive.CompressionConfig.init(.zstd)
    .withZstdLevel(15)          // Level 1-22
    .withChecksum()
    .withBufferSize(256 * 1024); // Larger buffers for better compression
```

### LZMA - Maximum Compression

**Best for**: Long-term archival, distribution packages, when size matters most

```zig
const compressed = try archive.compress(allocator, data, .lzma);
```

**Characteristics**:
- Very high compression ratio
- Slow compression and decompression
- Good for data that will be compressed once, decompressed many times
- Used in 7-Zip

### XZ - LZMA2 Based

**Best for**: Software distribution, system backups, archival

```zig
const compressed = try archive.compress(allocator, data, .xz);
```

**Characteristics**:
- Based on LZMA2 algorithm
- Very high compression ratio
- Better than LZMA for certain data types
- Used by many Linux distributions

### TAR.GZ - Archive Format

**Best for**: Unix/Linux file archives, directory compression

```zig
// One-shot: wraps data as a single TAR entry, then gzips it.
const compressed = try archive.compress(allocator, data, .tar_gz);
```

**Characteristics**:
- Real TAR archive (ustar headers, file names, modes, mtimes) inside the
  gzip layer; TAR construction and gzip framing are separate steps.
- Preserves file metadata and directory structure.
- Standard format for Unix systems.

**Multi-entry archives**:
```zig
const entries = [_]archive.algorithms.tar_gz.TarEntry{
    .{ .name = "hello.txt", .data = "Hello!" },
    .{ .name = "docs/readme.txt", .data = "Readme." },
};
const packed = try archive.algorithms.tar_gz.pack(allocator, &entries, .{});
defer allocator.free(packed);
const parsed = try archive.algorithms.tar_gz.unpack(allocator, packed, .{});
defer archive.algorithms.tar_gz.freeEntries(allocator, parsed);
```

### ZIP - Cross-Platform Archives

**Best for**: Cross-platform archives, Windows compatibility

```zig
// One-shot: packs data as a single ZIP entry, then parses it back.
const compressed = try archive.compress(allocator, data, .zip);
```

**Characteristics**:
- Real ZIP archive (local headers, central directory, EOCD, CRC32 per
  entry) with store or deflate per entry; never a raw deflate stream.
- Supports multiple files with entry boundaries and checksums.
- Compatible with all operating systems.

**Multi-entry archives**:
```zig
const entries = [_]archive.algorithms.zip.ZipEntryData{
    .{ .name = "hello.txt", .data = "Hello!" },
    .{ .name = "blob.bin", .data = bytes, .method = .Store },
};
const packed = try archive.algorithms.zip.pack(allocator, &entries, .{});
defer allocator.free(packed);
const parsed = try archive.algorithms.zip.unpackAll(allocator, packed);
defer archive.algorithms.zip.freeUnpacked(allocator, parsed);
```

### Brotli - Modern Web Compression

**Best for**: Web content, HTTP compression, general purpose

```zig
const compressed = try archive.compress(allocator, data, .brotli);
```

**Characteristics**:
- Developed by Google for web compression
- Excellent compression ratio with good speed
- Supports text-oriented and font-specific modes
- Widely used in HTTP (Content-Encoding: br)

**Configuration**:
```zig
const config = archive.CompressionConfig.init(.brotli)
    .withLevel(.best);  // Level 0-11 (higher = better compression)
```

## Choosing the Right Algorithm

### For Speed (Fastest to Slowest)
1. **LZ4** - Ultra-fast, minimal compression
2. **Deflate** - Fast, no overhead
3. **Gzip/Zlib** - Fast with checksums
4. **Zstd** - Very fast with good compression
5. **LZMA/XZ** - Slow but maximum compression

### For Compression Ratio (Best to Worst)
1. **LZMA/XZ** - Maximum compression
2. **Zstd (high levels)** - Excellent compression
3. **Gzip/Zlib** - Good compression
4. **Deflate** - Medium compression
5. **LZ4** - Minimal compression

### For Specific Use Cases

**Web Applications**:
```zig
// HTTP compression
const compressed = try archive.compress(allocator, html_content, .gzip);

// API responses
const compressed = try archive.compress(allocator, json_data, .zstd);
```

**Gaming**:
```zig
// Asset compression (fast loading)
const compressed = try archive.compress(allocator, texture_data, .lz4);

// Save files (balance of size and speed)
const compressed = try archive.compress(allocator, save_data, .zstd);
```

**Databases**:
```zig
// Column compression
const compressed = try archive.compress(allocator, column_data, .zstd);

// Backup compression
const compressed = try archive.compress(allocator, backup_data, .lzma);
```

**Network Protocols**:
```zig
// Real-time data
const compressed = try archive.compress(allocator, packet_data, .lz4);

// File transfer
const compressed = try archive.compress(allocator, file_data, .zstd);
```

## Performance Comparison

Here's a typical performance comparison on text data:

```zig
pub fn comparePerformance(allocator: std.mem.Allocator) !void {
    const test_data = "Lorem ipsum dolor sit amet...";
    
    const algorithms = [_]struct { algo: archive.Algorithm, name: []const u8 }{
        .{ .algo = .lz4, .name = "LZ4" },
        .{ .algo = .deflate, .name = "Deflate" },
        .{ .algo = .gzip, .name = "Gzip" },
        .{ .algo = .zlib, .name = "Zlib" },
        .{ .algo = .zstd, .name = "Zstd" },
        .{ .algo = .lzma, .name = "LZMA" },
        .{ .algo = .xz, .name = "XZ" },
        .{ .algo = .brotli, .name = "Brotli" },
    };
    
    std.debug.print("Algorithm | Size | Ratio | Time (ms)\n");
    std.debug.print("----------|------|-------|----------\n");
    
    for (algorithms) |item| {
        const start = std.time.nanoTimestamp();
        const compressed = try archive.compress(allocator, test_data, item.algo);
        defer allocator.free(compressed);
        const end = std.time.nanoTimestamp();
        
        const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(test_data.len)) * 100;
        const duration_ms = @as(f64, @floatFromInt(end - start)) / 1_000_000.0;
        
        std.debug.print("{s:>9} | {d:>4} | {d:>5.1}% | {d:>8.2}\n", 
                       .{ item.name, compressed.len, ratio, duration_ms });
    }
}
```

## Algorithm-Specific Tips

### Zstd Optimization
```zig
// For maximum compression
const config = archive.CompressionConfig.init(.zstd)
    .withZstdLevel(22)
    .withBufferSize(1024 * 1024);

// For balanced performance
const config = archive.CompressionConfig.init(.zstd)
    .withZstdLevel(10)
    .withBufferSize(256 * 1024);
```

### Gzip Strategies
```zig
// For text data
const config = archive.CompressionConfig.init(.gzip)
    .withStrategy(.huffman_only);

// For binary data
const config = archive.CompressionConfig.init(.gzip)
    .withStrategy(.default);
```

### LZ4 for Real-Time
```zig
// Minimal latency
const config = archive.CompressionConfig.init(.lz4)
    .withBufferSize(4096);  // Small buffer for low latency
```

## Next Steps

- Learn about [Configuration](./configuration.md) options for each algorithm
- Explore [Streaming](./streaming.md) for large data processing
- Check [File Operations](./file-operations.md) for working with files
- See [Examples](../examples/basic.md) for practical usage