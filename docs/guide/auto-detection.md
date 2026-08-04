# Auto-Detection

Archive.zig can automatically detect compression formats from file headers and magic bytes, making it easy to work with compressed data without knowing the format in advance.

## Basic Auto-Detection

### Detect Algorithm

```zig
const compressed_data = // ... some compressed data
if (archive.detectAlgorithm(compressed_data)) |algorithm| {
    std.debug.print("Detected format: {s}\n", .{@tagName(algorithm)});
} else {
    std.debug.print("Unknown or uncompressed format\n", .{});
}
```

### Auto-Decompress

```zig
// Automatically detect format and decompress
const decompressed = try archive.autoDecompress(allocator, compressed_data);
defer allocator.free(decompressed);
```

## Magic Bytes Detection

Archive.zig recognizes these magic byte signatures:

| Format | Magic Bytes | Description |
|--------|-------------|-------------|
| **Gzip** | `1F 8B` | Standard gzip header |
| **Zlib** | `78 XX` | Zlib header (XX varies) |
| **Zstd** | `28 B5 2F FD` | Zstandard magic number |
| **LZ4** | `04 22 4D 18` | LZ4 frame format |
| **LZMA** | `5D 00 00` | LZMA header |
| **XZ** | `FD 37 7A 58 5A 00` | XZ file format |
| **ZIP** | `50 4B 03 04` | ZIP local file header |
| **TAR.GZ** | `1F 8B` + TAR | Gzip + TAR structure |
| **Brotli** | `CE B2 CF 81` | Brotli magic number |

## Detection Examples

### File Format Detection

```zig
pub fn detectFileFormat(allocator: std.mem.Allocator, file_path: []const u8) !void {
    const file_data = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024); // Read first 1KB
    defer allocator.free(file_data);
    
    if (archive.detectAlgorithm(file_data)) |algorithm| {
        std.debug.print("File {s} is compressed with: {s}\n", .{ file_path, @tagName(algorithm) });
        
        // Auto-decompress
        const full_data = try std.fs.cwd().readFileAlloc(allocator, file_path, 10 * 1024 * 1024);
        defer allocator.free(full_data);
        
        const decompressed = try archive.autoDecompress(allocator, full_data);
        defer allocator.free(decompressed);
        
        std.debug.print("Decompressed size: {d} bytes\n", .{decompressed.len});
    } else {
        std.debug.print("File {s} is not compressed or format not recognized\n", .{file_path});
    }
}
```

### Batch Processing

```zig
pub fn processCompressedFiles(allocator: std.mem.Allocator, directory: []const u8) !void {
    var dir = try std.fs.cwd().openDir(directory, .{ .iterate = true });
    defer dir.close();
    
    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        if (entry.kind != .file) continue;
        
        const file_path = try std.fs.path.join(allocator, &[_][]const u8{ directory, entry.name });
        defer allocator.free(file_path);
        
        const file_data = std.fs.cwd().readFileAlloc(allocator, file_path, 1024) catch continue;
        defer allocator.free(file_data);
        
        if (archive.detectAlgorithm(file_data)) |algorithm| {
            std.debug.print("Processing {s} ({s})\n", .{ entry.name, @tagName(algorithm) });
            
            // Process the compressed file...
            const full_data = try std.fs.cwd().readFileAlloc(allocator, file_path, 100 * 1024 * 1024);
            defer allocator.free(full_data);
            
            const decompressed = try archive.autoDecompress(allocator, full_data);
            defer allocator.free(decompressed);
            
            // Save decompressed version
            const output_path = try std.fmt.allocPrint(allocator, "{s}.decompressed", .{file_path});
            defer allocator.free(output_path);
            
            try std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = decompressed });
        }
    }
}
```

## Advanced Detection

### Custom Detection Logic

```zig
pub fn advancedDetection(data: []const u8) ?archive.Algorithm {
    // First try built-in detection
    if (archive.detectAlgorithm(data)) |algo| {
        return algo;
    }
    
    // Custom detection for special cases
    if (data.len >= 4) {
        // Check for custom format
        if (std.mem.eql(u8, data[0..4], "CUST")) {
            return .gzip; // Treat as gzip for this example
        }
    }
    
    // Check file extension patterns in filename (if available)
    // This would require additional context
    
    return null;
}
```

### Detection with Confidence

```zig
pub const DetectionResult = struct {
    algorithm: archive.Algorithm,
    confidence: f32, // 0.0 to 1.0
};

pub fn detectWithConfidence(data: []const u8) ?DetectionResult {
    if (data.len < 4) return null;
    
    // Gzip detection
    if (data.len >= 2 and data[0] == 0x1F and data[1] == 0x8B) {
        return DetectionResult{ .algorithm = .gzip, .confidence = 1.0 };
    }
    
    // Zstd detection
    if (data.len >= 4 and std.mem.eql(u8, data[0..4], &[_]u8{ 0x28, 0xB5, 0x2F, 0xFD })) {
        return DetectionResult{ .algorithm = .zstd, .confidence = 1.0 };
    }
    
    // Zlib detection (less certain due to variable second byte)
    if (data[0] == 0x78) {
        const second_byte = data[1];
        if (second_byte == 0x01 or second_byte == 0x5E or second_byte == 0x9C or second_byte == 0xDA) {
            return DetectionResult{ .algorithm = .zlib, .confidence = 0.9 };
        }
    }
    
    return null;
}
```

## Error Handling

### Safe Auto-Decompression

```zig
pub fn safeAutoDecompress(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    const algorithm = archive.detectAlgorithm(data) orelse {
        return error.UnknownFormat;
    };
    
    return archive.decompress(allocator, data, algorithm) catch |err| switch (err) {
        error.CorruptedStream => {
            std.debug.print("Warning: Data appears corrupted, trying alternative algorithms\n", .{});
            
            // Try other algorithms as fallback
            const fallback_algorithms = [_]archive.Algorithm{ .gzip, .zlib, .deflate };
            for (fallback_algorithms) |fallback| {
                if (fallback == algorithm) continue;
                
                if (archive.decompress(allocator, data, fallback)) |result| {
                    std.debug.print("Successfully decompressed with {s}\n", .{@tagName(fallback)});
                    return result;
                } else |_| {
                    continue;
                }
            }
            
            return err;
        },
        else => return err,
    };
}
```

## File Extension Mapping

### Extension-Based Detection

```zig
pub fn detectFromExtension(filename: []const u8) ?archive.Algorithm {
    if (std.mem.endsWith(u8, filename, ".gz")) return .gzip;
    if (std.mem.endsWith(u8, filename, ".zst")) return .zstd;
    if (std.mem.endsWith(u8, filename, ".lz4")) return .lz4;
    if (std.mem.endsWith(u8, filename, ".xz")) return .xz;
    if (std.mem.endsWith(u8, filename, ".lzma")) return .lzma;
    if (std.mem.endsWith(u8, filename, ".zip")) return .zip;
    if (std.mem.endsWith(u8, filename, ".tar.gz")) return .tar_gz;
    if (std.mem.endsWith(u8, filename, ".tgz")) return .tar_gz;
    if (std.mem.endsWith(u8, filename, ".br")) return .brotli;
    
    return null;
}

pub fn smartDetection(data: []const u8, filename: ?[]const u8) ?archive.Algorithm {
    // Try magic byte detection first (most reliable)
    if (archive.detectAlgorithm(data)) |algo| {
        return algo;
    }
    
    // Fall back to extension-based detection
    if (filename) |name| {
        return detectFromExtension(name);
    }
    
    return null;
}
```

## Practical Examples

### Universal Decompressor

```zig
pub fn universalDecompress(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8) !void {
    const compressed_data = try std.fs.cwd().readFileAlloc(allocator, input_path, 100 * 1024 * 1024);
    defer allocator.free(compressed_data);
    
    const algorithm = archive.detectAlgorithm(compressed_data) orelse {
        // Try extension-based detection
        detectFromExtension(input_path) orelse {
            std.debug.print("Error: Cannot detect compression format\n", .{});
            return error.UnknownFormat;
        }
    };
    
    std.debug.print("Detected format: {s}\n", .{@tagName(algorithm)});
    
    const decompressed = try archive.decompress(allocator, compressed_data, algorithm);
    defer allocator.free(decompressed);
    
    try std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = decompressed });
    std.debug.print("Decompressed {s} -> {s}\n", .{ input_path, output_path });
}
```

### Archive Inspector

```zig
pub fn inspectArchive(allocator: std.mem.Allocator, file_path: []const u8) !void {
    const file_data = try std.fs.cwd().readFileAlloc(allocator, file_path, 1024);
    defer allocator.free(file_data);
    
    std.debug.print("Inspecting: {s}\n", .{file_path});
    std.debug.print("File size: {d} bytes\n", .{file_data.len});
    
    if (archive.detectAlgorithm(file_data)) |algorithm| {
        std.debug.print("Format: {s}\n", .{@tagName(algorithm)});
        
        // Show magic bytes
        const magic_bytes = file_data[0..@min(8, file_data.len)];
        std.debug.print("Magic bytes: ");
        for (magic_bytes) |byte| {
            std.debug.print("{X:0>2} ", .{byte});
        }
        std.debug.print("\n");
        
        // Try to get uncompressed size estimate
        const full_data = try std.fs.cwd().readFileAlloc(allocator, file_path, 100 * 1024 * 1024);
        defer allocator.free(full_data);
        
        if (archive.decompress(allocator, full_data, algorithm)) |decompressed| {
            defer allocator.free(decompressed);
            const ratio = @as(f64, @floatFromInt(full_data.len)) / @as(f64, @floatFromInt(decompressed.len)) * 100;
            std.debug.print("Uncompressed size: {d} bytes\n", .{decompressed.len});
            std.debug.print("Compression ratio: {d:.1}%\n", .{ratio});
        } else |err| {
            std.debug.print("Error decompressing: {}\n", .{err});
        }
    } else {
        std.debug.print("Format: Unknown or uncompressed\n");
        
        // Show first few bytes anyway
        const preview_bytes = file_data[0..@min(16, file_data.len)];
        std.debug.print("First bytes: ");
        for (preview_bytes) |byte| {
            std.debug.print("{X:0>2} ", .{byte});
        }
        std.debug.print("\n");
    }
}
```

## Limitations

### Detection Limitations

- **Deflate**: No magic bytes (raw compressed data)
- **Custom formats**: May not be detected
- **Corrupted files**: May give false positives
- **Small files**: May not have enough data for reliable detection

### Workarounds

```zig
pub fn robustDetection(data: []const u8, filename: ?[]const u8, hint: ?archive.Algorithm) ?archive.Algorithm {
    // Use hint if provided
    if (hint) |h| return h;
    
    // Try magic byte detection
    if (archive.detectAlgorithm(data)) |algo| return algo;
    
    // Try extension-based detection
    if (filename) |name| {
        if (detectFromExtension(name)) |algo| return algo;
    }
    
    // For deflate, try decompression test
    if (data.len > 10) {
        if (archive.decompress(std.testing.allocator, data, .deflate)) |result| {
            std.testing.allocator.free(result);
            return .deflate;
        } else |_| {}
    }
    
    return null;
}
```

## Next Steps

- Learn about [File Operations](./file-operations.md) for working with files
- Explore [Streaming](./streaming.md) for large data processing
- Check out [Error Handling](./errors.md) for robust applications
- See [Examples](../examples/auto-detection.md) for practical usage