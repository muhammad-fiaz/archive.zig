# Streaming Examples

This page demonstrates practical streaming compression and decompression examples for memory-efficient processing of large files and real-time data.

## Basic Streaming Operations

### Simple Stream Compression

```zig
const std = @import("std");
const archive = @import("archive");

pub fn basicStreamCompression(allocator: std.mem.Allocator) !void {
    // Create a stream compressor
    var compressor = try archive.stream.CompressStream.init(allocator, .gzip, .default);
    defer compressor.deinit();
    
    // Process data in chunks
    const chunks = [_][]const u8{
        "First chunk of streaming data. ",
        "Second chunk with more content. ",
        "Third chunk continuing the stream. ",
        "Final chunk to complete the data.",
    };
    
    std.debug.print("Basic stream compression:\n");
    
    for (chunks) |chunk| {
        total_input += chunk.len;
        try compressor.write(chunk);
    }
    
    const compressed = try compressor.finish();
    defer allocator.free(compressed);
    total_output = compressed.len;
    
    std.debug.print("  Total: {d} -> {d} bytes ({d:.1}%)\n", .{ total_input, total_output, @as(f64, @floatFromInt(total_output)) / @as(f64, @floatFromInt(total_input)) * 100 });
}
```

### Stream Decompression

```zig
pub fn basicStreamDecompression(allocator: std.mem.Allocator) !void {
    // First, create some compressed data
    const original_data = "This is test data for stream decompression example. " ** 20;
    const compressed_data = try archive.compress(allocator, original_data, .zstd);
    defer allocator.free(compressed_data);
    
    // Now decompress it using streaming
    var decompressor = try archive.stream.DecompressStream.init(allocator);
    defer decompressor.deinit();
    
    std.debug.print("Stream decompression:\n");
    std.debug.print("  Compressed data: {d} bytes\n", .{compressed_data.len});
    
    // Process in chunks
    const chunk_size = 256;
    var offset: usize = 0;
    var total_decompressed: usize = 0;
    var chunk_count: usize = 0;
    
    while (offset < compressed_data.len) {
        const end = @min(offset + chunk_size, compressed_data.len);
        const chunk = compressed_data[offset..end];
        
        try decompressor.write(chunk);
        
        total_decompressed += chunk.len;
        chunk_count += 1;
        
        std.debug.print("  Chunk {d}: {d} bytes input\n", .{ chunk_count, chunk.len });
        
        offset = end;
    }
    
    const decompressed = try decompressor.finish();
    defer allocator.free(decompressed);
    
    total_decompressed = decompressed.len;
    
    std.debug.print("  Total decompressed: {d} bytes\n", .{total_decompressed});
    std.debug.print("  Integrity: {s}\n", .{if (decompressed.len == original_data.len) "PASS" else "FAIL"});
}
```

## File Streaming

### Large File Compression

```zig
pub fn streamCompressLargeFile(allocator: std.mem.Allocator) !void {
    // Create a large test file
    const test_file = "large_test_file.txt";
    const compressed_file = "large_test_file.txt.zst";
    
    // Generate large test content
    const line_content = "This is line content for large file streaming test.\n";
    const num_lines = 10000;
    
    {
        const output_file = try std.fs.cwd().createFile(test_file, .{});
        defer output_file.close();
        
        var i: usize = 0;
        while (i < num_lines) : (i += 1) {
            const line = try std.fmt.allocPrint(allocator, "Line {d}: {s}", .{ i, line_content });
            defer allocator.free(line);
            try output_file.writeAll(line);
        }
    }
    
    // Stream compress the file
    const input_file = try std.fs.cwd().openFile(test_file, .{});
    defer input_file.close();
    
    const output_file = try std.fs.cwd().createFile(compressed_file, .{});
    defer output_file.close();
    
    var compressor = try archive.stream.CompressStream.init(allocator, .zstd, .default);
    defer compressor.deinit();
    
    var buffer: [64 * 1024]u8 = undefined; // 64KB buffer
    var total_read: usize = 0;
    var total_written: usize = 0;
    var chunk_count: usize = 0;
    
    const start_time = std.time.nanoTimestamp();
    
    while (true) {
        const bytes_read = try input_file.readAll(&buffer);
        if (bytes_read == 0) break;
        
        total_read += bytes_read;
        chunk_count += 1;
        
        try compressor.write(buffer[0..bytes_read]);
        
        if (bytes_read < buffer.len) break;
    }
    
    const compressed = try compressor.finish();
    defer allocator.free(compressed);
    
    try output_file.writeAll(compressed);
    total_written = compressed.len;
    
    const end_time = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    const ratio = @as(f64, @floatFromInt(total_written)) / @as(f64, @floatFromInt(total_read)) * 100;
    const throughput_mb = @as(f64, @floatFromInt(total_read)) / (1024.0 * 1024.0) / (duration_ms / 1000.0);
    
    std.debug.print("Large file stream compression:\n");
    std.debug.print("  Input: {d} bytes ({d} chunks)\n", .{ total_read, chunk_count });
    std.debug.print("  Output: {d} bytes ({d:.1}%)\n", .{ total_written, ratio });
    std.debug.print("  Time: {d:.2}ms ({d:.2} MB/s)\n", .{ duration_ms, throughput_mb });
    
    // Clean up
    std.fs.cwd().deleteFile(test_file) catch {};
    std.fs.cwd().deleteFile(compressed_file) catch {};
}
```

### Large File Decompression

```zig
pub fn streamDecompressLargeFile(allocator: std.mem.Allocator) !void {
    // Create test files
    const original_file = "original_large.txt";
    const compressed_file = "compressed_large.lz4";
    const decompressed_file = "decompressed_large.txt";
    
    // Create original file
    const test_content = "Large file decompression test content line.\n" ** 5000;
    try std.fs.cwd().writeFile(.{ .sub_path = original_file, .data = test_content });
    
    // Compress it first
    const original_data = try std.fs.cwd().readFileAlloc(allocator, original_file, 10 * 1024 * 1024);
    defer allocator.free(original_data);
    
    const compressed_data = try archive.compress(allocator, original_data, .lz4);
    defer allocator.free(compressed_data);
    
    try std.fs.cwd().writeFile(.{ .sub_path = compressed_file, .data = compressed_data });
    
    // Now stream decompress
    const input_file = try std.fs.cwd().openFile(compressed_file, .{});
    defer input_file.close();
    
    const output_file = try std.fs.cwd().createFile(decompressed_file, .{});
    defer output_file.close();
    
    var decompressor = try archive.stream.DecompressStream.init(allocator);
    defer decompressor.deinit();
    
    var buffer: [32 * 1024]u8 = undefined; // 32KB buffer
    var total_read: usize = 0;
    var total_written: usize = 0;
    
    const start_time = std.time.nanoTimestamp();
    
    while (true) {
        const bytes_read = try input_file.readAll(&buffer);
        if (bytes_read == 0) break;
        
        total_read += bytes_read;
        
        try decompressor.write(buffer[0..bytes_read]);
        
        if (bytes_read < buffer.len) break;
    }
    
    const decompressed = try decompressor.finish();
    defer allocator.free(decompressed);
    
    try output_file.writeAll(decompressed);
    total_written = decompressed.len;
    
    const end_time = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    
    // Verify integrity
    const decompressed_data = try std.fs.cwd().readFileAlloc(allocator, decompressed_file, 10 * 1024 * 1024);
    defer allocator.free(decompressed_data);
    
    const integrity_check = std.mem.eql(u8, original_data, decompressed_data);
    
    std.debug.print("Large file stream decompression:\n");
    std.debug.print("  Compressed: {d} bytes\n", .{total_read});
    std.debug.print("  Decompressed: {d} bytes\n", .{total_written});
    std.debug.print("  Time: {d:.2}ms\n", .{duration_ms});
    std.debug.print("  Integrity: {s}\n", .{if (integrity_check) "PASS" else "FAIL"});
    
    // Clean up
    std.fs.cwd().deleteFile(original_file) catch {};
    std.fs.cwd().deleteFile(compressed_file) catch {};
    std.fs.cwd().deleteFile(decompressed_file) catch {};
}
```

## Real-Time Data Processing

### Simulated Real-Time Compression

```zig
pub fn realTimeDataCompression(allocator: std.mem.Allocator) !void {
    var compressor = try archive.stream.CompressStream.init(allocator, .lz4, .default);
    defer compressor.deinit();
    
    std.debug.print("Real-time data compression simulation:\n");
    
    // Simulate real-time data packets
    var packet_id: u32 = 0;
    var total_input: usize = 0;
    var total_output: usize = 0;
    
    while (packet_id < 50) : (packet_id += 1) {
        // Generate simulated sensor data
        const timestamp = std.time.nanoTimestamp();
        const sensor_data = try std.fmt.allocPrint(allocator, 
            "{{\"id\":{d},\"timestamp\":{d},\"temperature\":{d:.1},\"humidity\":{d:.1},\"pressure\":{d:.2}}}\n",
            .{ packet_id, timestamp, 20.0 + @as(f64, @floatFromInt(packet_id % 15)), 
               45.0 + @as(f64, @floatFromInt(packet_id % 30)), 1013.25 + @as(f64, @floatFromInt(packet_id % 10)) });
        defer allocator.free(sensor_data);
        
        total_input += sensor_data.len;
        
        // Compress packet
        try compressor.write(sensor_data);
        
        // Simulate network transmission delay
        std.time.sleep(5 * std.time.ns_per_ms);
    }
    
    // Finish the stream
    const final_chunk = try compressor.finish();
    defer allocator.free(final_chunk);
    total_output += final_chunk.len;
    
    const ratio = @as(f64, @floatFromInt(total_output)) / @as(f64, @floatFromInt(total_input)) * 100;
    std.debug.print("  Total: {d} packets, {d} -> {d} bytes ({d:.1}%)\n", 
                   .{ packet_id, total_input, total_output, ratio });
}
```

### Buffered Stream Processing

```zig
pub const BufferedStreamProcessor = struct {
    compressor: archive.stream.CompressStream,
    buffer: std.ArrayList(u8),
    buffer_limit: usize,
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator, algorithm: archive.Algorithm, buffer_limit: usize) !BufferedStreamProcessor {
        return BufferedStreamProcessor{
            .compressor = try archive.stream.CompressStream.init(allocator, algorithm, .default),
            .buffer = .empty,
            .buffer_limit = buffer_limit,
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *BufferedStreamProcessor) void {
        self.compressor.deinit();
        self.buffer.deinit(self.allocator);
    }
    
    pub fn addData(self: *BufferedStreamProcessor, data: []const u8) !?[]u8 {
        try self.buffer.appendSlice(data);
        
        if (self.buffer.items.len >= self.buffer_limit) {
            return self.flushBuffer();
        }
        
        return null; // Buffer not full yet
    }
    
    pub fn flushBuffer(self: *BufferedStreamProcessor) ![]u8 {
        if (self.buffer.items.len == 0) {
            return try self.allocator.alloc(u8, 0);
        }
        
        try self.compressor.write(self.buffer.items);
        self.buffer.clearRetainingCapacity();
        return try self.compressor.finish();
    }
    
    pub fn finish(self: *BufferedStreamProcessor) ![]u8 {
        const compressed = try self.compressor.finish();
        self.buffer.clearRetainingCapacity();
        return compressed;
    }
};

pub fn bufferedStreamExample(allocator: std.mem.Allocator) !void {
    var processor = try BufferedStreamProcessor.init(allocator, .gzip, 2048);
    defer processor.deinit();
    
    std.debug.print("Buffered stream processing:\n");
    
    var flush_count: usize = 0;
    var total_input: usize = 0;
    var total_output: usize = 0;
    
    // Add data in small increments
    var i: u32 = 0;
    while (i < 200) : (i += 1) {
        const data = try std.fmt.allocPrint(allocator, "Data entry {d} with some content. ", .{i});
        defer allocator.free(data);
        
        total_input += data.len;
        
        if (try processor.addData(data)) |compressed| {
            defer allocator.free(compressed);
            flush_count += 1;
            total_output += compressed.len;
            
            if (flush_count % 5 == 0) {
                std.debug.print("  Flush {d}: {d} bytes compressed\n", .{ flush_count, compressed.len });
            }
        }
    }
    
    // Finish processing
    const final_compressed = try processor.finish();
    defer allocator.free(final_compressed);
    total_output += final_compressed.len;
    
    const ratio = @as(f64, @floatFromInt(total_output)) / @as(f64, @floatFromInt(total_input)) * 100;
    std.debug.print("  Final: {d} bytes, Total: {d} -> {d} bytes ({d:.1}%)\n", 
                   .{ final_compressed.len, total_input, total_output, ratio });
}
```

## Advanced Streaming Patterns

### Pipeline Stream Processing

```zig
pub fn pipelineStreamProcessing(allocator: std.mem.Allocator) !void {
    // Create a processing pipeline: Input -> Transform -> Compress -> Output
    
    const input_data = [_][]const u8{
        "Raw sensor reading: temperature=25.3",
        "Raw sensor reading: temperature=26.1", 
        "Raw sensor reading: temperature=24.8",
        "Raw sensor reading: temperature=25.9",
        "Raw sensor reading: temperature=26.4",
    };
    
    var compressor = try archive.stream.CompressStream.init(allocator, .lz4, .default);
    defer compressor.deinit();
    
    std.debug.print("Pipeline stream processing:\n");
    
    var total_input: usize = 0;
    var total_transformed: usize = 0;
    var total_compressed: usize = 0;
    
    for (input_data, 0..) |raw_data, i| {
        // Stage 1: Input
        total_input += raw_data.len;
        
        // Stage 2: Transform (convert to JSON)
        const transformed = try std.fmt.allocPrint(allocator, 
            "{{\"sensor_id\":\"temp_01\",\"reading\":\"{s}\",\"timestamp\":{d}}}\n",
            .{ raw_data, std.time.nanoTimestamp() });
        defer allocator.free(transformed);
        
        total_transformed += transformed.len;
        
        // Stage 3: Compress
        try compressor.write(transformed);
        total_compressed += transformed.len;
        
        // Stage 4: Output (simulate sending)
        std.debug.print("  Pipeline {d}: {d} -> {d} bytes\n", 
                       .{ i + 1, raw_data.len, transformed.len });
    }
    
    const transform_ratio = @as(f64, @floatFromInt(total_transformed)) / @as(f64, @floatFromInt(total_input)) * 100;
    
    std.debug.print("  Transform: {d} -> {d} bytes ({d:.1}%)\n", .{ total_input, total_transformed, transform_ratio });
}
```

### Memory-Efficient Stream Processing

```zig
pub fn memoryEfficientStreaming(allocator: std.mem.Allocator) !void {
    // Use arena allocator for temporary allocations
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();
    
    // Create test files
    const input_file = "memory_test_input.txt";
    const output_file = "memory_test_output.lz4";
    
    // Generate test content
    const content = "Memory efficient streaming test content line.\n" ** 2000;
    try std.fs.cwd().writeFile(.{ .sub_path = input_file, .data = content });
    
    // Process with minimal memory usage
    const input = try std.fs.cwd().openFile(input_file, .{});
    defer input.close();
    
    const output = try std.fs.cwd().createFile(output_file, .{});
    defer output.close();
    
    var compressor = try archive.stream.CompressStream.init(arena_allocator, .lz4, .default);
    defer compressor.deinit();
    
    // Use small buffer to minimize memory usage
    const buffer_size = 4096; // 4KB buffer
    var buffer: [buffer_size]u8 = undefined;
    
    var total_processed: usize = 0;
    var chunk_count: usize = 0;
    
    std.debug.print("Memory-efficient streaming:\n");
    std.debug.print("  Buffer size: {d} bytes\n", .{buffer_size});
    
    const start_time = std.time.nanoTimestamp();
    
    while (true) {
        const bytes_read = try input.readAll(&buffer);
        if (bytes_read == 0) break;
        
        total_processed += bytes_read;
        chunk_count += 1;
        
        try compressor.write(buffer[0..bytes_read]);
        
        if (bytes_read < buffer.len) {
            const compressed = try compressor.finish();
            try output.writeAll(compressed);
            break;
        }
    }
    
    const end_time = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    
    // Get output file size
    const output_stat = try std.fs.cwd().statFile(output_file);
    const ratio = @as(f64, @floatFromInt(output_stat.size)) / @as(f64, @floatFromInt(total_processed)) * 100;
    
    std.debug.print("  Processed: {d} bytes in {d} chunks\n", .{ total_processed, chunk_count });
    std.debug.print("  Compressed: {d} bytes ({d:.1}%)\n", .{ output_stat.size, ratio });
    std.debug.print("  Time: {d:.2}ms\n", .{duration_ms});
    std.debug.print("  Memory usage: Minimal (arena-based)\n");
    
    // Clean up
    std.fs.cwd().deleteFile(input_file) catch {};
    std.fs.cwd().deleteFile(output_file) catch {};
}
```

## Error Handling in Streaming

### Robust Stream Processing

```zig
pub fn robustStreamProcessing(allocator: std.mem.Allocator) !void {
    std.debug.print("Robust stream processing with error handling:\n");
    
    // Test different scenarios
    const test_cases = [_]struct { name: []const u8, data: []const u8, should_fail: bool }{
        .{ .name = "Normal data", .data = "Normal streaming data content", .should_fail = false },
        .{ .name = "Empty data", .data = "", .should_fail = false },
        .{ .name = "Large data", .data = "Large data content " ** 100, .should_fail = false },
    };
    
    for (test_cases) |test_case| {
        std.debug.print("  Testing: {s} - ", .{test_case.name});
        
        const result = processStreamRobustly(allocator, test_case.data);
        if (result) {
            std.debug.print("SUCCESS\n");
        } else |err| {
            std.debug.print("ERROR: {}\n", .{err});
        }
    }
}

fn processStreamRobustly(allocator: std.mem.Allocator, data: []const u8) !void {
    var compressor = archive.stream.CompressStream.init(allocator, .gzip, .default) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("Failed to initialize compressor (OOM)");
            return err;
        },
        else => return err,
    };
    defer compressor.deinit();
    
    // Process data
    try compressor.write(data);
    
    // Finish stream
    const compressed = compressor.finish() catch |err| switch (err) {
        error.StreamNotFinalized => {
            std.debug.print("Stream finalization failed");
            return err;
        },
        else => return err,
    };
    defer allocator.free(compressed);
    
    // Verify by decompressing
    const decompressed = archive.decompress(allocator, compressed, .gzip) catch |err| switch (err) {
        error.CorruptedStream => {
            std.debug.print("Verification failed (corrupted)");
            return err;
        },
        else => return err,
    };
    defer allocator.free(decompressed);
    
    if (!std.mem.eql(u8, data, decompressed)) {
        std.debug.print("Verification failed (mismatch)");
        return error.VerificationFailed;
    }
}
```

## Performance Optimization

### High-Performance Streaming

```zig
pub fn highPerformanceStreaming(allocator: std.mem.Allocator) !void {
    // Create large test data
    const test_file = "performance_test.txt";
    const compressed_file = "performance_test.lz4";
    
    // Generate large content
    const line = "High performance streaming test line with sufficient content for benchmarking.\n";
    const num_lines = 50000;
    
    {
        const file = try std.fs.cwd().createFile(test_file, .{});
        defer file.close();
        
        var i: usize = 0;
        while (i < num_lines) : (i += 1) {
            try file.writeAll(line);
        }
    }
    
    // High-performance configuration
    const config = archive.CompressionConfig.init(.lz4)
        .withLevel(.fastest)
        .withBufferSize(1024 * 1024); // 1MB buffer
    
    var compressor = try archive.stream.CompressStream.init(allocator, config.algorithm, config.level);
    defer compressor.deinit();
    
    const input_file = try std.fs.cwd().openFile(test_file, .{});
    defer input_file.close();
    
    const output_file = try std.fs.cwd().createFile(compressed_file, .{});
    defer output_file.close();
    
    // Pre-allocate large buffer
    const buffer = try allocator.alloc(u8, config.buffer_size);
    defer allocator.free(buffer);
    
    var total_bytes: usize = 0;
    var chunk_count: usize = 0;
    
    const start_time = std.time.nanoTimestamp();
    
    while (true) {
        const bytes_read = try input_file.readAll(buffer);
        if (bytes_read == 0) break;
        
        total_bytes += bytes_read;
        chunk_count += 1;
        
        try compressor.write(buffer[0..bytes_read]);
        
        if (bytes_read < buffer.len) break;
    }
    
    const compressed = try compressor.finish();
    defer allocator.free(compressed);
    try output_file.writeAll(compressed);
    }
    
    const end_time = std.time.nanoTimestamp();
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    const throughput_mb = @as(f64, @floatFromInt(total_bytes)) / (1024.0 * 1024.0) / (duration_ms / 1000.0);
    
    // Get compressed file size
    const compressed_stat = try std.fs.cwd().statFile(compressed_file);
    const ratio = @as(f64, @floatFromInt(compressed_stat.size)) / @as(f64, @floatFromInt(total_bytes)) * 100;
    
    std.debug.print("High-performance streaming results:\n");
    std.debug.print("  Input: {d:.2} MB ({d} chunks)\n", .{ @as(f64, @floatFromInt(total_bytes)) / (1024.0 * 1024.0), chunk_count });
    std.debug.print("  Output: {d:.2} MB ({d:.1}%)\n", .{ @as(f64, @floatFromInt(compressed_stat.size)) / (1024.0 * 1024.0), ratio });
    std.debug.print("  Time: {d:.2}ms\n", .{duration_ms});
    std.debug.print("  Throughput: {d:.2} MB/s\n", .{throughput_mb});
    std.debug.print("  Buffer size: {d} KB\n", .{config.buffer_size / 1024});
    
    // Clean up
    std.fs.cwd().deleteFile(test_file) catch {};
    std.fs.cwd().deleteFile(compressed_file) catch {};
}
```

## Complete Example

### Full Streaming Application

```zig
pub fn completeStreamingExample(allocator: std.mem.Allocator) !void {
    std.debug.print("Complete streaming application example:\n");
    
    // Run all streaming examples
    try basicStreamCompression(allocator);
    std.debug.print("\n");
    
    try basicStreamDecompression(allocator);
    std.debug.print("\n");
    
    try streamCompressLargeFile(allocator);
    std.debug.print("\n");
    
    try realTimeDataCompression(allocator);
    std.debug.print("\n");
    
    try bufferedStreamExample(allocator);
    std.debug.print("\n");
    
    try memoryEfficientStreaming(allocator);
    std.debug.print("\n");
    
    try robustStreamProcessing(allocator);
    std.debug.print("\n");
    
    try highPerformanceStreaming(allocator);
    
    std.debug.print("\nAll streaming examples completed successfully!\n");
}
```

## Next Steps

- Learn about [File Operations](./file-operations.md) for file-based streaming
- Explore [Configuration](./configuration.md) for streaming optimization
- See [Builder Pattern](./builder.md) for flexible stream configuration