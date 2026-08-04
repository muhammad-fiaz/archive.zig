# Error Handling

Archive.zig provides comprehensive error handling to help you build robust compression applications. This guide covers error types, handling strategies, and recovery techniques.

## Error Types

### Core Compression Errors

```zig
pub const CompressError = error{
    OutOfMemory,
    InvalidData,
    InvalidMagic,
    UnsupportedAlgorithm,
    CorruptedStream,
    ChecksumMismatch,
    InvalidOffset,
    InvalidTarArchive,
    ZstdError,
    UnsupportedCompressionMethod,
    ZipUncompressSizeMismatch,
    InvalidZipArchive,
};
```

### Error Descriptions

| Error | Description | Common Causes |
|-------|-------------|---------------|
| `OutOfMemory` | Not enough memory for operation | Large files, insufficient RAM |
| `InvalidData` | Input data is malformed | Corrupted input, wrong format |
| `InvalidMagic` | Magic bytes don't match format | Wrong algorithm, corrupted header |
| `UnsupportedAlgorithm` | Algorithm not supported | Unsupported compression method |
| `CorruptedStream` | Compressed data is corrupted | Network errors, disk corruption |
| `ChecksumMismatch` | Checksum verification failed | Data corruption, transmission errors |
| `InvalidOffset` | Invalid offset in archive | Corrupted archive structure |
| `InvalidTarArchive` | TAR archive structure invalid | Malformed TAR file |
| `ZstdError` | ZSTD-specific error | ZSTD library error |
| `UnsupportedCompressionMethod` | Compression method not supported | Unsupported ZIP method |
| `ZipUncompressSizeMismatch` | ZIP size mismatch | Corrupted ZIP entry |
| `InvalidZipArchive` | ZIP archive structure invalid | Malformed ZIP file |

## Basic Error Handling

### Simple Error Handling

```zig
const std = @import("std");
const archive = @import("archive");

pub fn basicErrorHandling(allocator: std.mem.Allocator, data: []const u8) void {
    const compressed = archive.compress(allocator, data, .gzip) catch |err| {
        std.debug.print("Compression failed: {}\n", .{err});
        return;
    };
    defer allocator.free(compressed);
    
    const decompressed = archive.decompress(allocator, compressed, .gzip) catch |err| {
        std.debug.print("Decompression failed: {}\n", .{err});
        return;
    };
    defer allocator.free(decompressed);
    
    std.debug.print("Success!\n", .{});
}
```

### Specific Error Handling

```zig
pub fn specificErrorHandling(allocator: std.mem.Allocator, data: []const u8) !void {
    const compressed = archive.compress(allocator, data, .gzip) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("Error: Not enough memory for compression\n", .{});
            std.debug.print("Try using streaming compression for large data\n", .{});
            return error.OutOfMemory;
        },
        error.InvalidData => {
            std.debug.print("Error: Input data is invalid\n", .{});
            std.debug.print("Check that input data is not empty or corrupted\n", .{});
            return error.InvalidData;
        },
        else => {
            std.debug.print("Unexpected compression error: {}\n", .{err});
            return err;
        },
    };
    defer allocator.free(compressed);
    
    const decompressed = archive.decompress(allocator, compressed, .gzip) catch |err| switch (err) {
        error.CorruptedStream => {
            std.debug.print("Error: Compressed data is corrupted\n", .{});
            std.debug.print("The compressed data may have been damaged\n", .{});
            return error.CorruptedStream;
        },
        error.ChecksumMismatch => {
            std.debug.print("Error: Checksum verification failed\n", .{});
            std.debug.print("Data integrity check failed - data may be corrupted\n", .{});
            return error.ChecksumMismatch;
        },
        error.InvalidMagic => {
            std.debug.print("Error: Invalid magic bytes\n", .{});
            std.debug.print("Data may not be compressed with the specified algorithm\n", .{});
            return error.InvalidMagic;
        },
        else => {
            std.debug.print("Unexpected decompression error: {}\n", .{err});
            return err;
        },
    };
    defer allocator.free(decompressed);
    
    std.debug.print("Compression and decompression successful\n", .{});
}
```

## Advanced Error Handling

### Error Recovery

```zig
pub fn errorRecovery(allocator: std.mem.Allocator, data: []const u8) ![]u8 {
    // Try primary algorithm
    if (archive.compress(allocator, data, .zstd)) |compressed| {
        return compressed;
    } else |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("ZSTD failed due to memory, trying LZ4...\n", .{});
            // Try faster, less memory-intensive algorithm
            return archive.compress(allocator, data, .lz4) catch |lz4_err| {
                std.debug.print("LZ4 also failed: {}\n", .{lz4_err});
                return lz4_err;
            };
        },
        error.InvalidData => {
            std.debug.print("Data invalid for ZSTD, trying deflate...\n", .{});
            // Try simpler algorithm
            return archive.compress(allocator, data, .deflate) catch |deflate_err| {
                std.debug.print("Deflate also failed: {}\n", .{deflate_err});
                return deflate_err;
            };
        },
        else => return err,
    }
}
```

### Retry Logic

```zig
pub fn retryCompress(allocator: std.mem.Allocator, data: []const u8, algorithm: archive.Algorithm, max_retries: u32) ![]u8 {
    var retries: u32 = 0;
    
    while (retries < max_retries) {
        if (archive.compress(allocator, data, algorithm)) |compressed| {
            if (retries > 0) {
                std.debug.print("Compression succeeded after {d} retries\n", .{retries});
            }
            return compressed;
        } else |err| switch (err) {
            error.OutOfMemory => {
                retries += 1;
                std.debug.print("Retry {d}/{d} due to memory error\n", .{ retries, max_retries });
                
                // Force garbage collection
                if (std.builtin.mode == .Debug) {
                    std.debug.print("Attempting garbage collection...\n", .{});
                }
                
                // Wait a bit before retrying
                std.time.sleep(100 * std.time.ns_per_ms);
                continue;
            },
            else => return err, // Don't retry for other errors
        }
    }
    
    return error.OutOfMemory; // All retries exhausted
}
```

## File Operation Error Handling

### Robust File Compression

```zig
pub fn robustFileCompress(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, io: std.Io) !void {
    // Check input file
    const input_stat = std.Io.Dir.cwd().statFile(io, input_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("Error: Input file '{s}' not found\n", .{input_path});
            std.debug.print("Please check the file path and try again\n", .{});
            return err;
        },
        error.AccessDenied => {
            std.debug.print("Error: Cannot access input file '{s}'\n", .{input_path});
            std.debug.print("Check file permissions\n", .{});
            return err;
        },
        else => {
            std.debug.print("Error accessing input file: {}\n", .{err});
            return err;
        },
    };
    
    // Check file size
    if (input_stat.size == 0) {
        std.debug.print("Warning: Input file is empty\n", .{});
        return error.InvalidData;
    }
    
    if (input_stat.size > 1024 * 1024 * 1024) { // 1GB
        std.debug.print("Warning: File is very large ({d} bytes)\n", .{input_stat.size});
        std.debug.print("Consider using streaming compression\n", .{});
    }
    
    // Read input file
    const input_data = std.Io.Dir.cwd().readFileAlloc(io, input_path, allocator, .limited(@intCast(input_stat.size))) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("Error: Not enough memory to read file ({d} bytes)\n", .{input_stat.size});
            std.debug.print("Try using streaming compression or increase available memory\n", .{});
            return err;
        },
        error.AccessDenied => {
            std.debug.print("Error: Cannot read input file (access denied)\n", .{});
            return err;
        },
        else => {
            std.debug.print("Error reading input file: {}\n", .{err});
            return err;
        },
    };
    defer allocator.free(input_data);
    
    // Compress data
    const compressed = archive.compress(allocator, input_data, .gzip) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("Error: Not enough memory for compression\n", .{});
            std.debug.print("Try a faster algorithm like LZ4 or use streaming\n", .{});
            
            // Try fallback algorithm
            return archive.compress(allocator, input_data, .lz4) catch |lz4_err| {
                std.debug.print("Fallback LZ4 compression also failed: {}\n", .{lz4_err});
                return lz4_err;
            };
        },
        error.InvalidData => {
            std.debug.print("Error: Input data cannot be compressed\n", .{});
            std.debug.print("File may be corrupted or in an unsupported format\n", .{});
            return err;
        },
        else => {
            std.debug.print("Compression error: {}\n", .{err});
            return err;
        },
    };
    defer allocator.free(compressed);
    
    // Write output file
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_path, .data = compressed }) catch |err| switch (err) {
        error.AccessDenied => {
            std.debug.print("Error: Cannot write to output file '{s}'\n", .{output_path});
            std.debug.print("Check directory permissions\n", .{});
            return err;
        },
        error.NoSpaceLeft => {
            std.debug.print("Error: No space left on device\n", .{});
            std.debug.print("Free up disk space and try again\n", .{});
            return err;
        },
        error.FileTooBig => {
            std.debug.print("Error: Output file would be too large\n", .{});
            return err;
        },
        else => {
            std.debug.print("Error writing output file: {}\n", .{err});
            return err;
        },
    };
    
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input_data.len)) * 100;
    std.debug.print("Successfully compressed {s} -> {s} ({d:.1}%)\n", .{ input_path, output_path, ratio });
}
```

## Validation and Verification

### Data Validation

```zig
pub fn validateAndCompress(allocator: std.mem.Allocator, data: []const u8, algorithm: archive.Algorithm) ![]u8 {
    // Validate input data
    if (data.len == 0) {
        std.debug.print("Error: Input data is empty\n", .{});
        return error.InvalidData;
    }
    
    if (data.len > 100 * 1024 * 1024) { // 100MB
        std.debug.print("Warning: Input data is very large ({d} bytes)\n", .{data.len});
    }
    
    // Check for obviously uncompressible data
    if (isRandomData(data)) {
        std.debug.print("Warning: Data appears to be random/encrypted - compression may not be effective\n", .{});
    }
    
    // Compress data
    const compressed = try archive.compress(allocator, data, algorithm);
    
    // Verify compression worked
    if (compressed.len >= data.len) {
        std.debug.print("Warning: Compressed data is not smaller than original\n", .{});
        std.debug.print("Original: {d} bytes, Compressed: {d} bytes\n", .{ data.len, compressed.len });
    }
    
    // Verify decompression works
    const decompressed = archive.decompress(allocator, compressed, algorithm) catch |err| {
        std.debug.print("Error: Compressed data cannot be decompressed: {}\n", .{err});
        allocator.free(compressed);
        return err;
    };
    defer allocator.free(decompressed);
    
    // Verify data integrity
    if (!std.mem.eql(u8, data, decompressed)) {
        std.debug.print("Error: Decompressed data does not match original\n", .{});
        allocator.free(compressed);
        return error.ChecksumMismatch;
    }
    
    return compressed;
}

fn isRandomData(data: []const u8) bool {
    if (data.len < 256) return false;
    
    // Simple entropy check - count unique bytes
    var byte_counts: [256]u32 = [_]u32{0} ** 256;
    for (data[0..@min(256, data.len)]) |byte| {
        byte_counts[byte] += 1;
    }
    
    var unique_bytes: u32 = 0;
    for (byte_counts) |count| {
        if (count > 0) unique_bytes += 1;
    }
    
    // If more than 200 unique bytes in first 256, likely random
    return unique_bytes > 200;
}
```

## Error Logging and Reporting

### Comprehensive Error Logging

```zig
pub const ErrorLogger = struct {
    allocator: std.mem.Allocator,
    log_file: ?std.fs.File,
    
    pub fn init(allocator: std.mem.Allocator, log_path: ?[]const u8, io: std.Io) !ErrorLogger {
        const log_file = if (log_path) |path|
            try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = false })
        else
            null;
        
        return ErrorLogger{
            .allocator = allocator,
            .log_file = log_file,
        };
    }
    
    pub fn deinit(self: *ErrorLogger) void {
        if (self.log_file) |file| {
            file.close();
        }
    }
    
    pub fn logError(self: *ErrorLogger, operation: []const u8, err: anyerror, context: []const u8) void {
        const timestamp = std.time.timestamp();
        const log_message = std.fmt.allocPrint(self.allocator, 
            "[{d}] ERROR in {s}: {} - {s}\n", 
            .{ timestamp, operation, err, context }
        ) catch return;
        defer self.allocator.free(log_message);
        
        // Log to stderr
        std.debug.print("{s}", .{log_message});
        
        // Log to file if available
        if (self.log_file) |file| {
            file.writeAll(log_message) catch {};
        }
    }
    
    pub fn logWarning(self: *ErrorLogger, operation: []const u8, message: []const u8) void {
        const timestamp = std.time.timestamp();
        const log_message = std.fmt.allocPrint(self.allocator, 
            "[{d}] WARNING in {s}: {s}\n", 
            .{ timestamp, operation, message }
        ) catch return;
        defer self.allocator.free(log_message);
        
        std.debug.print("{s}", .{log_message});
        
        if (self.log_file) |file| {
            file.writeAll(log_message) catch {};
        }
    }
};

pub fn compressWithLogging(allocator: std.mem.Allocator, data: []const u8, algorithm: archive.Algorithm) ![]u8 {
    var logger = try ErrorLogger.init(allocator, "compression.log", io);
    defer logger.deinit();
    
    const compressed = archive.compress(allocator, data, algorithm) catch |err| {
        const context = std.fmt.allocPrint(allocator, 
            "Algorithm: {s}, Data size: {d} bytes", 
            .{ @tagName(algorithm), data.len }
        ) catch "Unknown context";
        defer allocator.free(context);
        
        logger.logError("compress", err, context);
        return err;
    };
    
    // Log success
    const success_msg = std.fmt.allocPrint(allocator, 
        "Compressed {d} bytes to {d} bytes with {s}", 
        .{ data.len, compressed.len, @tagName(algorithm) }
    ) catch return compressed;
    defer allocator.free(success_msg);
    
    logger.logWarning("compress", success_msg); // Using warning level for info
    
    return compressed;
}
```

## Testing Error Conditions

### Error Simulation

```zig
pub fn testErrorConditions(allocator: std.mem.Allocator) !void {
    std.debug.print("Testing error conditions...\n", .{});
    
    // Test empty data
    {
        const empty_data: []const u8 = "";
        const result = archive.compress(allocator, empty_data, .gzip);
        if (result) |compressed| {
            allocator.free(compressed);
            std.debug.print("Empty data compression unexpectedly succeeded\n", .{});
        } else |err| {
            std.debug.print("Empty data correctly failed: {}\n", .{err});
        }
    }
    
    // Test invalid compressed data
    {
        const invalid_data = [_]u8{ 0xFF, 0xFF, 0xFF, 0xFF };
        const result = archive.decompress(allocator, &invalid_data, .gzip);
        if (result) |decompressed| {
            allocator.free(decompressed);
            std.debug.print("Invalid data decompression unexpectedly succeeded\n", .{});
        } else |err| {
            std.debug.print("Invalid data correctly failed: {}\n", .{err});
        }
    }
    
    // Test wrong algorithm
    {
        const data = "Test data";
        const gzip_compressed = try archive.compress(allocator, data, .gzip);
        defer allocator.free(gzip_compressed);
        
        const result = archive.decompress(allocator, gzip_compressed, .zlib);
        if (result) |decompressed| {
            allocator.free(decompressed);
            std.debug.print("Wrong algorithm decompression unexpectedly succeeded\n", .{});
        } else |err| {
            std.debug.print("Wrong algorithm correctly failed: {}\n", .{err});
        }
    }
    
    std.debug.print("Error condition testing completed\n", .{});
}
```

## Best Practices

### Error Handling Guidelines

1. **Always handle errors explicitly** - Don't ignore potential failures
2. **Provide meaningful error messages** - Help users understand what went wrong
3. **Log errors for debugging** - Keep records of failures for analysis
4. **Implement fallback strategies** - Try alternative approaches when possible
5. **Validate inputs early** - Catch problems before they cause failures
6. **Clean up resources** - Ensure proper cleanup even when errors occur
7. **Test error conditions** - Verify your error handling works correctly

### Example: Production-Ready Error Handling

```zig
pub fn productionCompress(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8, io: std.Io) !void {
    var logger = try ErrorLogger.init(allocator, "production.log", io);
    defer logger.deinit();
    
    // Validate inputs
    if (input_path.len == 0 or output_path.len == 0) {
        logger.logError("productionCompress", error.InvalidData, "Empty file paths");
        return error.InvalidData;
    }
    
    // Check input file
    const input_stat = std.Io.Dir.cwd().statFile(io, input_path, .{}) catch |err| {
        const context = std.fmt.allocPrint(allocator, "Input file: {s}", .{input_path}) catch "Unknown file";
        defer allocator.free(context);
        logger.logError("productionCompress", err, context);
        return err;
    };
    
    // Read with size limit
    const max_size = 500 * 1024 * 1024; // 500MB limit
    if (input_stat.size > max_size) {
        const context = std.fmt.allocPrint(allocator, "File too large: {d} bytes (max: {d})", .{ input_stat.size, max_size }) catch "File too large";
        defer allocator.free(context);
        logger.logError("productionCompress", error.FileTooBig, context);
        return error.FileTooBig;
    }
    
    const input_data = std.Io.Dir.cwd().readFileAlloc(io, input_path, allocator, .limited(@intCast(input_stat.size))) catch |err| {
        const context = std.fmt.allocPrint(allocator, "Reading {s} ({d} bytes)", .{ input_path, input_stat.size }) catch "Read error";
        defer allocator.free(context);
        logger.logError("productionCompress", err, context);
        return err;
    };
    defer allocator.free(input_data);
    
    // Compress with fallback
    const compressed = archive.compress(allocator, input_data, .zstd) catch |err| switch (err) {
        error.OutOfMemory => {
            logger.logWarning("productionCompress", "ZSTD failed, trying LZ4 fallback");
            archive.compress(allocator, input_data, .lz4) catch |lz4_err| {
                logger.logError("productionCompress", lz4_err, "LZ4 fallback also failed");
                return lz4_err;
            }
        },
        else => {
            const context = std.fmt.allocPrint(allocator, "ZSTD compression of {d} bytes", .{input_data.len}) catch "ZSTD error";
            defer allocator.free(context);
            logger.logError("productionCompress", err, context);
            return err;
        },
    };
    defer allocator.free(compressed);
    
    // Atomic write
    const temp_path = std.fmt.allocPrint(allocator, "{s}.tmp", .{output_path}) catch {
        logger.logError("productionCompress", error.OutOfMemory, "Creating temp path");
        return error.OutOfMemory;
    };
    defer allocator.free(temp_path);
    
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = temp_path, .data = compressed }) catch |err| {
        const context = std.fmt.allocPrint(allocator, "Writing to {s}", .{temp_path}) catch "Write error";
        defer allocator.free(context);
        logger.logError("productionCompress", err, context);
        return err;
    };
    
    std.Io.Dir.cwd().rename(io, temp_path, output_path) catch |err| {
        std.Io.Dir.cwd().deleteFile(io, temp_path) catch {}; // Clean up temp file
        const context = std.fmt.allocPrint(allocator, "Renaming {s} to {s}", .{ temp_path, output_path }) catch "Rename error";
        defer allocator.free(context);
        logger.logError("productionCompress", err, context);
        return err;
    };
    
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input_data.len)) * 100;
    const success_msg = std.fmt.allocPrint(allocator, 
        "Successfully compressed {s} -> {s} ({d:.1}%)", 
        .{ input_path, output_path, ratio }
    ) catch return;
    defer allocator.free(success_msg);
    
    logger.logWarning("productionCompress", success_msg);
}
```

## Next Steps

- Learn about [Memory Management](./memory.md) for efficient resource usage
- Explore [Threading](./threading.md) for concurrent error handling
- Check out [Platforms](./platforms.md) for platform-specific considerations
- See [Examples](../examples/basic.md) for practical error handling patterns