# Auto-Detection Examples

This page demonstrates how to use Archive.zig's automatic format detection capabilities to work with compressed data without knowing the format in advance.

## Basic Auto-Detection

### Detecting Compression Format

```zig
const std = @import("std");
const archive = @import("archive");

pub fn basicDetectionExample(allocator: std.mem.Allocator) !void {
    // Create test data with different formats
    const test_data = "Auto-detection test data for various compression formats";
    
    const algorithms = [_]archive.Algorithm{ .gzip, .zlib, .zstd, .lz4, .brotli };
    
    for (algorithms) |algo| {
        // Compress with known algorithm
        const compressed = try archive.compress(allocator, test_data, algo);
        defer allocator.free(compressed);
        
        // Detect algorithm from compressed data
        if (archive.detectAlgorithm(compressed)) |detected| {
            std.debug.print("Original: {s}, Detected: {s} - {s}\n", 
                           .{ @tagName(algo), @tagName(detected), 
                              if (algo == detected) "CORRECT" else "INCORRECT" });
        } else {
            std.debug.print("Original: {s}, Detected: UNKNOWN\n", .{@tagName(algo)});
        }
    }
}
```

### Auto-Decompression

```zig
pub fn autoDecompressionExample(allocator: std.mem.Allocator) !void {
    const original_data = "This data will be compressed and then auto-decompressed";
    
    // Test with different algorithms
    const algorithms = [_]archive.Algorithm{ .gzip, .zstd, .lz4, .zlib, .brotli };
    
    for (algorithms) |algo| {
        std.debug.print("Testing {s}:\n", .{@tagName(algo)});
        
        // Compress with known algorithm
        const compressed = try archive.compress(allocator, original_data, algo);
        defer allocator.free(compressed);
        
        // Auto-decompress without specifying algorithm
        const decompressed = try archive.autoDecompress(allocator, compressed);
        defer allocator.free(decompressed);
        
        // Verify data integrity
        const matches = std.mem.eql(u8, original_data, decompressed);
        std.debug.print("  Compressed: {d} bytes\n", .{compressed.len});
        std.debug.print("  Decompressed: {d} bytes\n", .{decompressed.len});
        std.debug.print("  Data integrity: {s}\n", .{if (matches) "PASS" else "FAIL"});
        std.debug.print("\n", .{});
    }
}
```

## File Format Detection

### Detecting Files by Content

```zig
pub fn fileDetectionExample(allocator: std.mem.Allocator) !void {
    // Create test files with different formats
    const test_files = [_]struct { name: []const u8, algorithm: archive.Algorithm }{
        .{ .name = "test.gz", .algorithm = .gzip },
        .{ .name = "test.zst", .algorithm = .zstd },
        .{ .name = "test.lz4", .algorithm = .lz4 },
        .{ .name = "test.zlib", .algorithm = .zlib },
    };
    
    const test_data = "File detection test data with various compression formats";
    
    // Create compressed test files
    for (test_files) |file_info| {
        const compressed = try archive.compress(allocator, test_data, file_info.algorithm);
        defer allocator.free(compressed);
        
        try std.fs.cwd().writeFile(.{ .sub_path = file_info.name, .data = compressed });
    }
    
    // Detect format of each file
    for (test_files) |file_info| {
        const file_data = try std.fs.cwd().readFileAlloc(allocator, file_info.name, 1024 * 1024);
        defer allocator.free(file_data);
        
        if (archive.detectAlgorithm(file_data)) |detected| {
            std.debug.print("File: {s}\n", .{file_info.name});
            std.debug.print("  Expected: {s}\n", .{@tagName(file_info.algorithm)});
            std.debug.print("  Detected: {s}\n", .{@tagName(detected)});
            std.debug.print("  Match: {s}\n", .{if (detected == file_info.algorithm) "YES" else "NO"});
        } else {
            std.debug.print("File: {s} - Format not detected\n", .{file_info.name});
        }
        
        // Clean up test file
        std.fs.cwd().deleteFile(file_info.name) catch {};
        std.debug.print("\n", .{});
    }
}
```

### Universal File Decompressor

```zig
pub fn universalDecompressor(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8) !void {
    std.debug.print("Universal decompression: {s} -> {s}\n", .{ input_path, output_path });
    
    // Read compressed file
    const compressed_data = try std.fs.cwd().readFileAlloc(allocator, input_path, 100 * 1024 * 1024);
    defer allocator.free(compressed_data);
    
    // Detect compression format
    const algorithm = archive.detectAlgorithm(compressed_data) orelse {
        std.debug.print("Error: Cannot detect compression format\n", .{});
        return error.UnknownFormat;
    };
    
    std.debug.print("Detected format: {s}\n", .{@tagName(algorithm)});
    
    // Decompress using detected algorithm
    const decompressed = try archive.decompress(allocator, compressed_data, algorithm);
    defer allocator.free(decompressed);
    
    // Write decompressed file
    try std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = decompressed });
    
    std.debug.print("Successfully decompressed {d} bytes to {d} bytes\n", 
                   .{ compressed_data.len, decompressed.len });
}

pub fn universalDecompressorExample(allocator: std.mem.Allocator) !void {
    // Create test compressed file
    const test_data = "Universal decompressor test data " ** 50;
    const compressed = try archive.compress(allocator, test_data, .zstd);
    defer allocator.free(compressed);
    
    try std.fs.cwd().writeFile(.{ .sub_path = "test_compressed.bin", .data = compressed });
    
    // Use universal decompressor
    try universalDecompressor(allocator, "test_compressed.bin", "test_decompressed.txt");
    
    // Verify result
    const result = try std.fs.cwd().readFileAlloc(allocator, "test_decompressed.txt", 1024 * 1024);
    defer allocator.free(result);
    
    const matches = std.mem.eql(u8, test_data, result);
    std.debug.print("Verification: {s}\n", .{if (matches) "PASS" else "FAIL"});
    
    // Clean up
    std.fs.cwd().deleteFile("test_compressed.bin") catch {};
    std.fs.cwd().deleteFile("test_decompressed.txt") catch {};
}
```

## Magic Byte Analysis

### Detailed Magic Byte Detection

```zig
pub fn magicByteAnalysis(data: []const u8) void {
    std.debug.print("Magic byte analysis for {d} bytes of data:\n", .{data.len});
    
    if (data.len < 2) {
        std.debug.print("  Insufficient data for analysis\n");
        return;
    }
    
    // Show first few bytes
    const preview_len = @min(16, data.len);
    std.debug.print("  First {d} bytes: ", .{preview_len});
    for (data[0..preview_len]) |byte| {
        std.debug.print("{X:0>2} ", .{byte});
    }
    std.debug.print("\n");
    
    // Check for specific formats
    if (data.len >= 2 and data[0] == 0x1F and data[1] == 0x8B) {
        std.debug.print("  Detected: Gzip (magic: 1F 8B)\n");
    } else if (data.len >= 4 and std.mem.eql(u8, data[0..4], &[_]u8{ 0x28, 0xB5, 0x2F, 0xFD })) {
        std.debug.print("  Detected: ZSTD (magic: 28 B5 2F FD)\n");
    } else if (data.len >= 4 and std.mem.eql(u8, data[0..4], &[_]u8{ 0x04, 0x22, 0x4D, 0x18 })) {
        std.debug.print("  Detected: LZ4 (magic: 04 22 4D 18)\n");
    } else if (data[0] == 0x78) {
        std.debug.print("  Detected: Zlib (magic: 78 XX)\n");
        if (data.len >= 2) {
            const second_byte = data[1];
            std.debug.print("    Second byte: {X:0>2}\n", .{second_byte});
            if (second_byte == 0x01 or second_byte == 0x5E or second_byte == 0x9C or second_byte == 0xDA) {
                std.debug.print("    Valid zlib header\n");
            } else {
                std.debug.print("    Unusual zlib header\n");
            }
        }
    } else if (data.len >= 3 and std.mem.eql(u8, data[0..3], &[_]u8{ 0x5D, 0x00, 0x00 })) {
        std.debug.print("  Detected: LZMA (magic: 5D 00 00)\n");
    } else if (data.len >= 6 and std.mem.eql(u8, data[0..6], &[_]u8{ 0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00 })) {
        std.debug.print("  Detected: XZ (magic: FD 37 7A 58 5A 00)\n");
    } else if (data.len >= 4 and std.mem.eql(u8, data[0..4], &[_]u8{ 0x50, 0x4B, 0x03, 0x04 })) {
        std.debug.print("  Detected: ZIP (magic: 50 4B 03 04)\n");
    } else {
        std.debug.print("  Unknown or uncompressed format\n");
    }
}

pub fn magicByteExample(allocator: std.mem.Allocator) !void {
    const test_data = "Magic byte analysis test data";
    
    const algorithms = [_]archive.Algorithm{ .gzip, .zstd, .lz4, .zlib, .zip, .brotli };
    
    for (algorithms) |algo| {
        std.debug.print("\n--- {s} ---\n", .{@tagName(algo)});
        
        const compressed = try archive.compress(allocator, test_data, algo);
        defer allocator.free(compressed);
        
        magicByteAnalysis(compressed);
    }
}
```

## Batch Processing with Auto-Detection

### Processing Multiple Files

```zig
pub fn batchProcessingExample(allocator: std.mem.Allocator) !void {
    // Create test files with different formats
    const test_files = [_]struct { name: []const u8, data: []const u8, algorithm: archive.Algorithm }{
        .{ .name = "document.txt.gz", .data = "Document content for gzip compression", .algorithm = .gzip },
        .{ .name = "data.bin.zst", .data = "Binary data for zstd compression " ** 10, .algorithm = .zstd },
        .{ .name = "log.txt.lz4", .data = "Log file content for lz4 compression", .algorithm = .lz4 },
        .{ .name = "config.json.zlib", .data = "{\"config\": \"zlib compressed\"}", .algorithm = .zlib },
    };
    
    // Create compressed test files
    for (test_files) |file_info| {
        const compressed = try archive.compress(allocator, file_info.data, file_info.algorithm);
        defer allocator.free(compressed);
        
        try std.fs.cwd().writeFile(.{ .sub_path = file_info.name, .data = compressed });
    }
    
    std.debug.print("Batch processing compressed files:\n");
    
    // Process all files
    for (test_files) |file_info| {
        std.debug.print("\nProcessing: {s}\n", .{file_info.name});
        
        // Read file
        const file_data = try std.fs.cwd().readFileAlloc(allocator, file_info.name, 1024 * 1024);
        defer allocator.free(file_data);
        
        // Auto-detect and decompress
        if (archive.detectAlgorithm(file_data)) |detected| {
            std.debug.print("  Detected format: {s}\n", .{@tagName(detected)});
            
            const decompressed = try archive.decompress(allocator, file_data, detected);
            defer allocator.free(decompressed);
            
            // Create output filename
            const output_name = try std.fmt.allocPrint(allocator, "{s}.decompressed", .{file_info.name});
            defer allocator.free(output_name);
            
            // Write decompressed file
            try std.fs.cwd().writeFile(.{ .sub_path = output_name, .data = decompressed });
            
            std.debug.print("  Decompressed: {d} -> {d} bytes\n", .{ file_data.len, decompressed.len });
            std.debug.print("  Output: {s}\n", .{output_name});
            
            // Verify data integrity
            const matches = std.mem.eql(u8, file_info.data, decompressed);
            std.debug.print("  Integrity: {s}\n", .{if (matches) "PASS" else "FAIL"});
            
            // Clean up output file
            std.fs.cwd().deleteFile(output_name) catch {};
        } else {
            std.debug.print("  Error: Could not detect compression format\n");
        }
        
        // Clean up input file
        std.fs.cwd().deleteFile(file_info.name) catch {};
    }
}
```

### Smart Archive Processor

```zig
pub const SmartArchiveProcessor = struct {
    allocator: std.mem.Allocator,
    processed_count: usize,
    error_count: usize,
    
    pub fn init(allocator: std.mem.Allocator) SmartArchiveProcessor {
        return SmartArchiveProcessor{
            .allocator = allocator,
            .processed_count = 0,
            .error_count = 0,
        };
    }
    
    pub fn processFile(self: *SmartArchiveProcessor, input_path: []const u8) !void {
        std.debug.print("Processing: {s}\n", .{input_path});
        
        // Read file
        const file_data = std.fs.cwd().readFileAlloc(self.allocator, input_path, 100 * 1024 * 1024) catch |err| {
            std.debug.print("  Error reading file: {}\n", .{err});
            self.error_count += 1;
            return;
        };
        defer self.allocator.free(file_data);
        
        // Try to detect compression format
        if (archive.detectAlgorithm(file_data)) |algorithm| {
            std.debug.print("  Detected: {s}\n", .{@tagName(algorithm)});
            
            // Decompress
            const decompressed = archive.decompress(self.allocator, file_data, algorithm) catch |err| {
                std.debug.print("  Error decompressing: {}\n", .{err});
                self.error_count += 1;
                return;
            };
            defer self.allocator.free(decompressed);
            
            // Create output filename
            const output_path = try std.fmt.allocPrint(self.allocator, "{s}.decompressed", .{input_path});
            defer self.allocator.free(output_path);
            
            // Write decompressed file
            std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = decompressed }) catch |err| {
                std.debug.print("  Error writing output: {}\n", .{err});
                self.error_count += 1;
                return;
            };
            
            const ratio = @as(f64, @floatFromInt(file_data.len)) / @as(f64, @floatFromInt(decompressed.len)) * 100;
            std.debug.print("  Success: {d} -> {d} bytes ({d:.1}% of original)\n", 
                           .{ file_data.len, decompressed.len, ratio });
            
            self.processed_count += 1;
        } else {
            // Not a compressed file, just copy it
            const output_path = try std.fmt.allocPrint(self.allocator, "{s}.copy", .{input_path});
            defer self.allocator.free(output_path);
            
            std.fs.cwd().writeFile(.{ .sub_path = output_path, .data = file_data }) catch |err| {
                std.debug.print("  Error copying file: {}\n", .{err});
                self.error_count += 1;
                return;
            };
            
            std.debug.print("  Not compressed, copied as-is\n");
            self.processed_count += 1;
        }
    }
    
    pub fn getStats(self: *SmartArchiveProcessor) struct { processed: usize, errors: usize } {
        return .{ .processed = self.processed_count, .errors = self.error_count };
    }
};

pub fn smartProcessorExample(allocator: std.mem.Allocator) !void {
    var processor = SmartArchiveProcessor.init(allocator);
    
    // Create test files (compressed and uncompressed)
    const test_files = [_]struct { name: []const u8, data: []const u8, algorithm: ?archive.Algorithm }{
        .{ .name = "compressed1.bin", .data = "Compressed test data 1", .algorithm = .gzip },
        .{ .name = "compressed2.bin", .data = "Compressed test data 2", .algorithm = .zstd },
        .{ .name = "uncompressed.txt", .data = "This is uncompressed text data", .algorithm = null },
        .{ .name = "compressed3.bin", .data = "Compressed test data 3", .algorithm = .lz4 },
    };
    
    // Create test files
    for (test_files) |file_info| {
        const file_data = if (file_info.algorithm) |algo|
            try archive.compress(allocator, file_info.data, algo)
        else
            try allocator.dupe(u8, file_info.data);
        defer allocator.free(file_data);
        
        try std.fs.cwd().writeFile(.{ .sub_path = file_info.name, .data = file_data });
    }
    
    // Process all files
    std.debug.print("Smart archive processing:\n\n");
    for (test_files) |file_info| {
        try processor.processFile(file_info.name);
        std.debug.print("\n");
    }
    
    // Show statistics
    const stats = processor.getStats();
    std.debug.print("Processing complete:\n");
    std.debug.print("  Files processed: {d}\n", .{stats.processed});
    std.debug.print("  Errors: {d}\n", .{stats.errors});
    
    // Clean up test files
    for (test_files) |file_info| {
        std.fs.cwd().deleteFile(file_info.name) catch {};
        
        const output_name = try std.fmt.allocPrint(allocator, "{s}.decompressed", .{file_info.name});
        defer allocator.free(output_name);
        std.fs.cwd().deleteFile(output_name) catch {};
        
        const copy_name = try std.fmt.allocPrint(allocator, "{s}.copy", .{file_info.name});
        defer allocator.free(copy_name);
        std.fs.cwd().deleteFile(copy_name) catch {};
    }
}
```

## Error Handling with Auto-Detection

### Robust Auto-Detection

```zig
pub fn robustAutoDetection(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    // Try auto-detection first
    if (archive.detectAlgorithm(data)) |algorithm| {
        std.debug.print("Auto-detected: {s}\n", .{@tagName(algorithm)});
        
        return archive.decompress(allocator, data, algorithm) catch |err| switch (err) {
            error.CorruptedStream => {
                std.debug.print("Warning: Data appears corrupted, trying alternative algorithms\n");
                
                // Try other algorithms as fallback
                const fallback_algorithms = [_]archive.Algorithm{ .gzip, .zlib, .deflate, .lz4, .brotli };
                for (fallback_algorithms) |fallback| {
                    if (fallback == algorithm) continue;
                    
                    if (archive.decompress(allocator, data, fallback)) |result| {
                        std.debug.print("Successfully decompressed with {s} fallback\n", .{@tagName(fallback)});
                        return result;
                    } else |_| {
                        continue;
                    }
                }
                
                return err;
            },
            else => return err,
        };
    } else {
        std.debug.print("Could not auto-detect format, trying all algorithms\n");
        
        // Try all algorithms
        const all_algorithms = [_]archive.Algorithm{ .gzip, .zlib, .deflate, .zstd, .lz4, .lzma, .xz, .brotli };
        for (all_algorithms) |algo| {
            if (archive.decompress(allocator, data, algo)) |result| {
                std.debug.print("Successfully decompressed with {s}\n", .{@tagName(algo)});
                return result;
            } else |_| {
                continue;
            }
        }
        
        return error.UnknownFormat;
    }
}

pub fn robustDetectionExample(allocator: std.mem.Allocator) !void {
    const test_data = "Robust detection test data";
    
    // Test with valid compressed data
    std.debug.print("Testing with valid ZSTD data:\n");
    const valid_compressed = try archive.compress(allocator, test_data, .zstd);
    defer allocator.free(valid_compressed);
    
    const valid_result = try robustAutoDetection(allocator, valid_compressed);
    defer allocator.free(valid_result);
    
    const valid_matches = std.mem.eql(u8, test_data, valid_result);
    std.debug.print("Result: {s}\n\n", .{if (valid_matches) "SUCCESS" else "FAILED"});
    
    // Test with corrupted data (simulate by modifying a few bytes)
    std.debug.print("Testing with corrupted data:\n");
    var corrupted_data = try allocator.dupe(u8, valid_compressed);
    defer allocator.free(corrupted_data);
    
    // Corrupt some bytes (but keep magic bytes intact for detection)
    if (corrupted_data.len > 10) {
        corrupted_data[8] ^= 0xFF;
        corrupted_data[9] ^= 0xFF;
    }
    
    if (robustAutoDetection(allocator, corrupted_data)) |corrupted_result| {
        defer allocator.free(corrupted_result);
        std.debug.print("Unexpectedly succeeded with corrupted data\n");
    } else |err| {
        std.debug.print("Correctly failed with corrupted data: {}\n", .{err});
    }
    
    // Test with unknown format
    std.debug.print("\nTesting with unknown format:\n");
    const unknown_data = "This is not compressed data at all";
    
    if (robustAutoDetection(allocator, unknown_data)) |unknown_result| {
        defer allocator.free(unknown_result);
        std.debug.print("Unexpectedly succeeded with unknown format\n");
    } else |err| {
        std.debug.print("Correctly failed with unknown format: {}\n", .{err});
    }
}
```

## Next Steps

- Learn about [File Operations](./file-operations.md) for working with compressed files
- Explore [Streaming](./streaming.md) for processing large compressed files
- Check out [Builder Pattern](./builder.md) for advanced configuration
- See [Configuration](./configuration.md) for detailed configuration options