# Memory Management

Archive.zig is designed for efficient memory usage with careful attention to allocation patterns, memory safety, and performance optimization. This guide covers memory management strategies and best practices.

## Memory Allocation Patterns

### Basic Memory Management

```zig
const std = @import("std");
const archive = @import("archive");

pub fn basicMemoryManagement(allocator: std.mem.Allocator) !void {
    const input = "Data to compress";
    
    // Compress - allocates memory for result
    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed); // Always free allocated memory
    
    // Decompress - allocates memory for result
    const decompressed = try archive.decompress(allocator, compressed, .gzip);
    defer allocator.free(decompressed); // Always free allocated memory
    
    std.debug.print("Memory management completed successfully\n", .{});
}
```

### Arena Allocator for Temporary Operations

```zig
pub fn arenaAllocatorExample(base_allocator: std.mem.Allocator) !void {
    // Create arena allocator for temporary allocations
    var arena = std.heap.ArenaAllocator.init(base_allocator);
    defer arena.deinit(); // Frees all arena memory at once
    
    const arena_allocator = arena.allocator();
    
    // All allocations use arena - no need for individual free() calls
    const input = "Multiple compression operations";
    
    const gzip_compressed = try archive.compress(arena_allocator, input, .gzip);
    const zlib_compressed = try archive.compress(arena_allocator, input, .zlib);
    const lz4_compressed = try archive.compress(arena_allocator, input, .lz4);
    
    // Process compressed data...
    std.debug.print("Gzip: {d} bytes\n", .{gzip_compressed.len});
    std.debug.print("Zlib: {d} bytes\n", .{zlib_compressed.len});
    std.debug.print("LZ4: {d} bytes\n", .{lz4_compressed.len});
    
    // arena.deinit() automatically frees all allocations
}
```

## Memory-Efficient Strategies

### Streaming for Large Files

```zig
pub fn memoryEfficientFileCompression(allocator: std.mem.Allocator, input_path: []const u8, output_path: []const u8) !void {
    const input_file = try std.fs.cwd().openFile(input_path, .{});
    defer input_file.close();
    
    const output_file = try std.fs.cwd().createFile(output_path, .{});
    defer output_file.close();
    
    // Use small buffer to minimize memory usage
    const buffer_size = 64 * 1024; // 64KB buffer
    var buffer: [buffer_size]u8 = undefined;
    
    var total_input: usize = 0;
    var total_output: usize = 0;
    
    while (true) {
        const bytes_read = try input_file.readAll(&buffer);
        if (bytes_read == 0) break;
        
        total_input += bytes_read;
        
        // Compress chunk
        const compressed_chunk = try archive.compress(allocator, buffer[0..bytes_read], .lz4);
        defer allocator.free(compressed_chunk);
        
        // Write chunk size and data
        const chunk_size = @as(u32, @intCast(compressed_chunk.len));
        try output_file.writeAll(std.mem.asBytes(&chunk_size));
        try output_file.writeAll(compressed_chunk);
        
        total_output += 4 + compressed_chunk.len; // 4 bytes for size + data
    }
    
    std.debug.print("Memory-efficient compression: {d} -> {d} bytes\n", .{ total_input, total_output });
}
```

### Buffer Reuse

```zig
pub const ReusableCompressor = struct {
    allocator: std.mem.Allocator,
    buffer: std.ArrayList(u8),
    algorithm: archive.Algorithm,
    
    pub fn init(allocator: std.mem.Allocator, algorithm: archive.Algorithm) ReusableCompressor {
        return ReusableCompressor{
            .allocator = allocator,
            .buffer = .empty,
            .algorithm = algorithm,
        };
    }
    
    pub fn deinit(self: *ReusableCompressor) void {
        self.buffer.deinit(self.allocator);
    }
    
    pub fn compress(self: *ReusableCompressor, data: []const u8) ![]u8 {
        // Clear buffer but keep capacity
        self.buffer.clearRetainingCapacity();
        
        // Compress data
        const compressed = try archive.compress(self.allocator, data, self.algorithm);
        
        // Store in reusable buffer
        try self.buffer.appendSlice(compressed);
        self.allocator.free(compressed);
        
        // Return slice of buffer (caller should not free this)
        return self.buffer.items;
    }
};

pub fn bufferReuseExample(allocator: std.mem.Allocator) !void {
    var compressor = ReusableCompressor.init(allocator, .lz4);
    defer compressor.deinit();
    
    const data_chunks = [_][]const u8{
        "First chunk of data",
        "Second chunk of data",
        "Third chunk of data",
    };
    
    for (data_chunks) |chunk| {
        const compressed = try compressor.compress(chunk);
        std.debug.print("Compressed {d} bytes to {d} bytes\n", .{ chunk.len, compressed.len });
        
        // Process compressed data immediately
        // Don't free - buffer is reused
    }
}
```

## Memory Monitoring

### Memory Usage Tracking

```zig
pub const TrackingAllocator = struct {
    child_allocator: std.mem.Allocator,
    allocated_bytes: std.atomic.Value(usize),
    peak_bytes: std.atomic.Value(usize),
    allocation_count: std.atomic.Value(usize),
    
    pub fn init(child_allocator: std.mem.Allocator) TrackingAllocator {
        return TrackingAllocator{
            .child_allocator = child_allocator,
            .allocated_bytes = std.atomic.Value(usize).init(0),
            .peak_bytes = std.atomic.Value(usize).init(0),
            .allocation_count = std.atomic.Value(usize).init(0),
        };
    }
    
    pub fn allocator(self: *TrackingAllocator) std.mem.Allocator {
        return .{
            .ptr = self,
            .vtable = &.{
                .alloc = alloc,
                .resize = resize,
                .free = free,
            },
        };
    }
    
    fn alloc(ctx: *anyopaque, len: usize, log2_ptr_align: u8, ret_addr: usize) ?[*]u8 {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        
        const result = self.child_allocator.rawAlloc(len, log2_ptr_align, ret_addr);
        if (result) |ptr| {
            const current = self.allocated_bytes.fetchAdd(len, .monotonic) + len;
            _ = self.allocation_count.fetchAdd(1, .monotonic);
            
            // Update peak if necessary
            var peak = self.peak_bytes.load(.monotonic);
            while (current > peak) {
                peak = self.peak_bytes.cmpxchgWeak(peak, current, .monotonic, .monotonic) orelse break;
            }
        }
        return result;
    }
    
    fn resize(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, new_len: usize, ret_addr: usize) bool {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        
        if (self.child_allocator.rawResize(buf, log2_buf_align, new_len, ret_addr)) {
            const old_len = buf.len;
            if (new_len > old_len) {
                _ = self.allocated_bytes.fetchAdd(new_len - old_len, .monotonic);
            } else {
                _ = self.allocated_bytes.fetchSub(old_len - new_len, .monotonic);
            }
            return true;
        }
        return false;
    }
    
    fn free(ctx: *anyopaque, buf: []u8, log2_buf_align: u8, ret_addr: usize) void {
        const self: *TrackingAllocator = @ptrCast(@alignCast(ctx));
        
        self.child_allocator.rawFree(buf, log2_buf_align, ret_addr);
        _ = self.allocated_bytes.fetchSub(buf.len, .monotonic);
    }
    
    pub fn getCurrentBytes(self: *TrackingAllocator) usize {
        return self.allocated_bytes.load(.monotonic);
    }
    
    pub fn getPeakBytes(self: *TrackingAllocator) usize {
        return self.peak_bytes.load(.monotonic);
    }
    
    pub fn getAllocationCount(self: *TrackingAllocator) usize {
        return self.allocation_count.load(.monotonic);
    }
};

pub fn memoryTrackingExample() !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    
    var tracking = TrackingAllocator.init(gpa.allocator());
    const allocator = tracking.allocator();
    
    const input = "Data to compress and track memory usage";
    
    std.debug.print("Initial memory: {d} bytes\n", .{tracking.getCurrentBytes()});
    
    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);
    
    std.debug.print("After compression: {d} bytes\n", .{tracking.getCurrentBytes()});
    
    const decompressed = try archive.decompress(allocator, compressed, .gzip);
    defer allocator.free(decompressed);
    
    std.debug.print("After decompression: {d} bytes\n", .{tracking.getCurrentBytes()});
    std.debug.print("Peak memory usage: {d} bytes\n", .{tracking.getPeakBytes()});
    std.debug.print("Total allocations: {d}\n", .{tracking.getAllocationCount()});
}
```

## Memory Optimization Techniques

### Pre-allocation Strategies

```zig
pub fn preallocationExample(allocator: std.mem.Allocator) !void {
    const input = "Data to compress with pre-allocation";
    
    // Estimate compressed size (rough heuristic)
    const estimated_size = input.len + (input.len / 10) + 64; // Add 10% + header overhead
    
    // Pre-allocate buffer
    var buffer = .empty;
    try buffer.ensureTotalCapacity(allocator, estimated_size);
    defer buffer.deinit(allocator);
    
    // Use configuration to control memory usage
    const config = archive.CompressionConfig.init(.gzip)
        .withBufferSize(16 * 1024) // Smaller buffer
        .withMemoryLevel(6); // Moderate memory usage
    
    const compressed = try archive.compressWithConfig(allocator, input, config);
    defer allocator.free(compressed);
    
    std.debug.print("Estimated: {d}, Actual: {d} bytes\n", .{ estimated_size, compressed.len });
}
```

### Memory Pool for Frequent Operations

```zig
pub const CompressionPool = struct {
    allocator: std.mem.Allocator,
    buffers: std.ArrayList([]u8),
    mutex: std.Thread.Mutex,
    buffer_size: usize,
    
    pub fn init(allocator: std.mem.Allocator, pool_size: usize, buffer_size: usize) !CompressionPool {
        var buffers = .empty;
        try buffers.ensureTotalCapacity(allocator, pool_size);
        var pool = CompressionPool{
            .allocator = allocator,
            .buffers = buffers,
            .mutex = std.Thread.Mutex{},
            .buffer_size = buffer_size,
        };
        
        // Pre-allocate buffers
        for (0..pool_size) |_| {
            const buffer = try allocator.alloc(u8, buffer_size);
            try pool.buffers.append(buffer);
        }
        
        return pool;
    }
    
    pub fn deinit(self: *CompressionPool) void {
        for (self.buffers.items) |buffer| {
            self.allocator.free(buffer);
        }
        self.buffers.deinit(self.allocator);
    }
    
    pub fn getBuffer(self: *CompressionPool) ?[]u8 {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        return self.buffers.popOrNull();
    }
    
    pub fn returnBuffer(self: *CompressionPool, buffer: []u8) void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        if (buffer.len == self.buffer_size) {
            self.buffers.append(buffer) catch {
                // Pool is full, free the buffer
                self.allocator.free(buffer);
            };
        } else {
            // Wrong size buffer, free it
            self.allocator.free(buffer);
        }
    }
    
    pub fn compress(self: *CompressionPool, data: []const u8, algorithm: archive.Algorithm) ![]u8 {
        // This is a simplified example - real implementation would use the pool buffers
        return archive.compress(self.allocator, data, algorithm);
    }
};

pub fn memoryPoolExample(allocator: std.mem.Allocator) !void {
    var pool = try CompressionPool.init(allocator, 4, 64 * 1024);
    defer pool.deinit();
    
    const test_data = "Test data for memory pool compression";
    
    // Simulate multiple compression operations
    for (0..10) |i| {
        const compressed = try pool.compress(test_data, .lz4);
        defer allocator.free(compressed);
        
        std.debug.print("Operation {d}: {d} bytes\n", .{ i, compressed.len });
    }
}
```

## Memory Safety

### Safe Memory Operations

```zig
pub fn safeMemoryOperations(allocator: std.mem.Allocator) !void {
    const input = "Data for safe memory operations";
    
    // Use errdefer for cleanup on error
    const compressed = archive.compress(allocator, input, .gzip) catch |err| {
        std.debug.print("Compression failed: {}\n", .{err});
        return err;
    };
    errdefer allocator.free(compressed); // Clean up on error
    
    // Validate compressed data before using
    if (compressed.len == 0) {
        allocator.free(compressed);
        return error.InvalidData;
    }
    
    const decompressed = archive.decompress(allocator, compressed, .gzip) catch |err| {
        allocator.free(compressed); // Clean up compressed data
        std.debug.print("Decompression failed: {}\n", .{err});
        return err;
    };
    defer allocator.free(decompressed);
    defer allocator.free(compressed);
    
    // Verify data integrity
    if (!std.mem.eql(u8, input, decompressed)) {
        return error.DataCorruption;
    }
    
    std.debug.print("Safe memory operations completed\n", .{});
}
```

### Memory Leak Detection

```zig
pub fn memoryLeakDetection() !void {
    var gpa = std.heap.DebugAllocator(.{
        .safety = true, // Enable safety checks
        .never_unmap = true, // Keep memory mapped for leak detection
        .retain_metadata = true, // Keep allocation metadata
    }){};
    defer {
        const leaked = gpa.deinit();
        if (leaked == .leak) {
            std.debug.print("Memory leak detected!\n", .{});
        } else {
            std.debug.print("No memory leaks detected\n", .{});
        }
    }
    
    const allocator = gpa.allocator();
    
    // Test compression operations
    const input = "Test data for leak detection";
    
    {
        const compressed = try archive.compress(allocator, input, .gzip);
        defer allocator.free(compressed);
        
        const decompressed = try archive.decompress(allocator, compressed, .gzip);
        defer allocator.free(decompressed);
        
        // Operations complete - memory should be freed
    }
    
    // Intentional leak for testing (remove in production)
    // const leaked_data = try allocator.alloc(u8, 1024);
    // _ = leaked_data; // Don't free - will be detected as leak
}
```

## Platform-Specific Considerations

### Windows Memory Management

```zig
pub fn windowsMemoryOptimization(allocator: std.mem.Allocator) !void {
    if (std.builtin.os.tag != .windows) return;
    
    // On Windows, use larger buffers for better performance
    const config = archive.CompressionConfig.init(.zstd)
        .withBufferSize(256 * 1024) // 256KB buffer
        .withMemoryLevel(8); // Higher memory usage acceptable on desktop
    
    const input = "Windows-optimized compression";
    const compressed = try archive.compressWithConfig(allocator, input, config);
    defer allocator.free(compressed);
    
    std.debug.print("Windows optimization: {d} bytes\n", .{compressed.len});
}
```

### Embedded/Low-Memory Optimization

```zig
pub fn embeddedMemoryOptimization(allocator: std.mem.Allocator) !void {
    // Configuration for memory-constrained environments
    const config = archive.CompressionConfig.init(.lz4) // Fast, low memory
        .withBufferSize(4 * 1024) // Small 4KB buffer
        .withMemoryLevel(1); // Minimal memory usage
    
    const input = "Embedded system data";
    const compressed = try archive.compressWithConfig(allocator, input, config);
    defer allocator.free(compressed);
    
    std.debug.print("Embedded optimization: {d} bytes\n", .{compressed.len});
}
```

## Best Practices

### Memory Management Guidelines

1. **Always free allocated memory** - Use `defer` for automatic cleanup
2. **Use arena allocators for temporary operations** - Simplifies cleanup
3. **Monitor memory usage in production** - Track allocations and peaks
4. **Pre-allocate when possible** - Reduces fragmentation
5. **Use streaming for large files** - Avoid loading everything into memory
6. **Choose appropriate algorithms** - Balance compression vs memory usage
7. **Test for memory leaks** - Use debug allocators during development
8. **Consider platform constraints** - Optimize for target environment

### Memory-Efficient Configuration

```zig
pub fn memoryEfficientConfig() archive.CompressionConfig {
    return archive.CompressionConfig.init(.lz4) // Fast, low memory
        .withLevel(.fastest) // Minimize processing time
        .withBufferSize(32 * 1024) // Reasonable buffer size
        .withMemoryLevel(4); // Moderate memory usage
}

pub fn balancedConfig() archive.CompressionConfig {
    return archive.CompressionConfig.init(.zstd) // Good compression
        .withZstdLevel(6) // Balanced level
        .withBufferSize(128 * 1024) // Good buffer size
        .withMemoryLevel(6); // Balanced memory usage
}

pub fn highCompressionConfig() archive.CompressionConfig {
    return archive.CompressionConfig.init(.lzma) // Maximum compression
        .withLevel(.best) // Best compression
        .withBufferSize(512 * 1024) // Large buffer
        .withMemoryLevel(9); // Maximum memory usage
}
```

## Next Steps

- Learn about [Threading](./threading.md) for concurrent memory management
- Explore [Platforms](./platforms.md) for platform-specific optimizations
- Check out [Streaming](./streaming.md) for memory-efficient processing
- See [Examples](../examples/basic.md) for practical memory management patterns