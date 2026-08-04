# Threading

Archive.zig supports thread-safe operations and parallel compression for improved performance on multi-core systems. This guide covers threading strategies, synchronization, and parallel processing techniques.

## Thread Safety

### Basic Thread Safety

Archive.zig compression functions are thread-safe when using separate allocators and data:

```zig
const std = @import("std");
const archive = @import("archive");

pub fn threadSafeExample() !void {
    const num_threads = 4;
    var threads: [num_threads]std.Thread = undefined;
    var results: [num_threads][]u8 = undefined;
    
    // Create separate data for each thread
    const test_data = [_][]const u8{
        "Thread 1 data to compress",
        "Thread 2 data to compress", 
        "Thread 3 data to compress",
        "Thread 4 data to compress",
    };
    
    // Start threads
    for (0..num_threads) |i| {
        threads[i] = try std.Thread.spawn(.{}, compressWorker, .{ i, test_data[i], &results[i] });
    }
    
    // Wait for completion
    for (threads) |thread| {
        thread.join();
    }
    
    // Process results
    for (results, 0..) |result, i| {
        defer std.heap.page_allocator.free(result);
        std.debug.print("Thread {d}: compressed to {d} bytes\n", .{ i, result.len });
    }
}

fn compressWorker(thread_id: usize, data: []const u8, result: *[]u8) void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    result.* = archive.compress(allocator, data, .lz4) catch unreachable;
    std.debug.print("Thread {d} completed compression\n", .{thread_id});
}
```

## Parallel Compression

### Chunk-Based Parallel Compression

```zig
pub const ParallelCompressor = struct {
    allocator: std.mem.Allocator,
    num_threads: usize,
    algorithm: archive.Algorithm,
    
    pub fn init(allocator: std.mem.Allocator, num_threads: usize, algorithm: archive.Algorithm) ParallelCompressor {
        return ParallelCompressor{
            .allocator = allocator,
            .num_threads = num_threads,
            .algorithm = algorithm,
        };
    }
    
    pub fn compressParallel(self: *ParallelCompressor, data: []const u8) ![]u8 {
        if (data.len < 1024 * 1024) {
            // Small data - use single thread
            return archive.compress(self.allocator, data, self.algorithm);
        }
        
        const chunk_size = data.len / self.num_threads;
        var threads: []std.Thread = try self.allocator.alloc(std.Thread, self.num_threads);
        defer self.allocator.free(threads);
        
        var chunks: [][]u8 = try self.allocator.alloc([]u8, self.num_threads);
        defer self.allocator.free(chunks);
        
        var compressed_chunks: [][]u8 = try self.allocator.alloc([]u8, self.num_threads);
        defer {
            for (compressed_chunks) |chunk| {
                if (chunk.len > 0) self.allocator.free(chunk);
            }
            self.allocator.free(compressed_chunks);
        }
        
        // Prepare chunks
        for (0..self.num_threads) |i| {
            const start = i * chunk_size;
            const end = if (i == self.num_threads - 1) data.len else (i + 1) * chunk_size;
            chunks[i] = data[start..end];
        }
        
        // Start compression threads
        for (0..self.num_threads) |i| {
            threads[i] = try std.Thread.spawn(.{}, compressChunk, .{ 
                self.allocator, chunks[i], self.algorithm, &compressed_chunks[i] 
            });
        }
        
        // Wait for completion
        for (threads) |thread| {
            thread.join();
        }
        
        // Combine results
        var total_size: usize = 0;
        for (compressed_chunks) |chunk| {
            total_size += chunk.len + 4; // 4 bytes for chunk size
        }
        
        var result = try self.allocator.alloc(u8, total_size);
        var offset: usize = 0;
        
        for (compressed_chunks) |chunk| {
            const chunk_size_bytes = std.mem.toBytes(@as(u32, @intCast(chunk.len)));
            @memcpy(result[offset..offset + 4], &chunk_size_bytes);
            offset += 4;
            
            @memcpy(result[offset..offset + chunk.len], chunk);
            offset += chunk.len;
        }
        
        return result;
    }
};

fn compressChunk(allocator: std.mem.Allocator, data: []const u8, algorithm: archive.Algorithm, result: *[]u8) void {
    result.* = archive.compress(allocator, data, algorithm) catch {
        result.* = &[_]u8{}; // Empty on error
    };
}

pub fn parallelCompressionExample(allocator: std.mem.Allocator) !void {
    var compressor = ParallelCompressor.init(allocator, 4, .lz4);
    
    // Create large test data
    const large_data = try allocator.alloc(u8, 10 * 1024 * 1024); // 10MB
    defer allocator.free(large_data);
    
    // Fill with test pattern
    for (large_data, 0..) |*byte, i| {
        byte.* = @intCast(i % 256);
    }
    
    const start_time = std.time.nanoTimestamp();
    const compressed = try compressor.compressParallel(large_data);
    defer allocator.free(compressed);
    const end_time = std.time.nanoTimestamp();
    
    const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(large_data.len)) * 100;
    
    std.debug.print("Parallel compression: {d} -> {d} bytes ({d:.1}%) in {d:.2}ms\n", 
                   .{ large_data.len, compressed.len, ratio, duration_ms });
}
```

### Thread Pool for Compression Tasks

```zig
pub const CompressionThreadPool = struct {
    allocator: std.mem.Allocator,
    threads: []std.Thread,
    task_queue: std.fifo.LinearFifo(CompressionTask, .Dynamic),
    result_queue: std.fifo.LinearFifo(CompressionResult, .Dynamic),
    mutex: std.Thread.Mutex,
    condition: std.Thread.Condition,
    shutdown: std.atomic.Value(bool),
    
    const CompressionTask = struct {
        id: u32,
        data: []const u8,
        algorithm: archive.Algorithm,
    };
    
    const CompressionResult = struct {
        id: u32,
        compressed_data: []u8,
        error_occurred: bool,
    };
    
    pub fn init(allocator: std.mem.Allocator, num_threads: usize) !CompressionThreadPool {
        var pool = CompressionThreadPool{
            .allocator = allocator,
            .threads = try allocator.alloc(std.Thread, num_threads),
            .task_queue = std.fifo.LinearFifo(CompressionTask, .Dynamic).init(allocator),
            .result_queue = std.fifo.LinearFifo(CompressionResult, .Dynamic).init(allocator),
            .mutex = std.Thread.Mutex{},
            .condition = std.Thread.Condition{},
            .shutdown = std.atomic.Value(bool).init(false),
        };
        
        // Start worker threads
        for (pool.threads, 0..) |*thread, i| {
            thread.* = try std.Thread.spawn(.{}, workerThread, .{ &pool, i });
        }
        
        return pool;
    }
    
    pub fn deinit(self: *CompressionThreadPool) void {
        // Signal shutdown
        self.shutdown.store(true, .monotonic);
        self.condition.broadcast();
        
        // Wait for threads to finish
        for (self.threads) |thread| {
            thread.join();
        }
        
        // Clean up remaining tasks and results
        while (self.task_queue.readItem()) |_| {}
        while (self.result_queue.readItem()) |result| {
            if (!result.error_occurred) {
                self.allocator.free(result.compressed_data);
            }
        }
        
        self.task_queue.deinit();
        self.result_queue.deinit();
        self.allocator.free(self.threads);
    }
    
    pub fn submitTask(self: *CompressionThreadPool, id: u32, data: []const u8, algorithm: archive.Algorithm) !void {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        try self.task_queue.writeItem(CompressionTask{
            .id = id,
            .data = data,
            .algorithm = algorithm,
        });
        
        self.condition.signal();
    }
    
    pub fn getResult(self: *CompressionThreadPool) ?CompressionResult {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        return self.result_queue.readItem();
    }
    
    fn workerThread(self: *CompressionThreadPool, worker_id: usize) void {
        var gpa = std.heap.DebugAllocator(.{}){};
        defer _ = gpa.deinit();
        const allocator = gpa.allocator();
        
        while (!self.shutdown.load(.monotonic)) {
            self.mutex.lock();
            
            while (self.task_queue.readItem() == null and !self.shutdown.load(.monotonic)) {
                self.condition.wait(&self.mutex);
            }
            
            const task = self.task_queue.readItem();
            self.mutex.unlock();
            
            if (task) |t| {
                std.debug.print("Worker {d} processing task {d}\n", .{ worker_id, t.id });
                
                const result = if (archive.compress(allocator, t.data, t.algorithm)) |compressed| 
                    CompressionResult{
                        .id = t.id,
                        .compressed_data = compressed,
                        .error_occurred = false,
                    }
                else |_|
                    CompressionResult{
                        .id = t.id,
                        .compressed_data = &[_]u8{},
                        .error_occurred = true,
                    };
                
                self.mutex.lock();
                self.result_queue.writeItem(result) catch {};
                self.mutex.unlock();
            }
        }
    }
};

pub fn threadPoolExample(allocator: std.mem.Allocator) !void {
    var pool = try CompressionThreadPool.init(allocator, 4);
    defer pool.deinit();
    
    // Submit multiple tasks
    const test_data = [_][]const u8{
        "Task 1 data for compression",
        "Task 2 data for compression",
        "Task 3 data for compression",
        "Task 4 data for compression",
        "Task 5 data for compression",
    };
    
    for (test_data, 0..) |data, i| {
        try pool.submitTask(@intCast(i), data, .lz4);
    }
    
    // Collect results
    var completed: usize = 0;
    while (completed < test_data.len) {
        if (pool.getResult()) |result| {
            defer if (!result.error_occurred) allocator.free(result.compressed_data);
            
            if (result.error_occurred) {
                std.debug.print("Task {d} failed\n", .{result.id});
            } else {
                std.debug.print("Task {d} completed: {d} bytes\n", .{ result.id, result.compressed_data.len });
            }
            completed += 1;
        } else {
            std.time.sleep(1 * std.time.ns_per_ms); // Wait a bit
        }
    }
}
```

## Synchronization

### Thread-Safe Configuration

```zig
pub const ThreadSafeCompressor = struct {
    config: archive.CompressionConfig,
    mutex: std.Thread.Mutex,
    stats: CompressionStats,
    
    const CompressionStats = struct {
        total_compressed: std.atomic.Value(usize),
        total_original: std.atomic.Value(usize),
        compression_count: std.atomic.Value(usize),
    };
    
    pub fn init(config: archive.CompressionConfig) ThreadSafeCompressor {
        return ThreadSafeCompressor{
            .config = config,
            .mutex = std.Thread.Mutex{},
            .stats = CompressionStats{
                .total_compressed = std.atomic.Value(usize).init(0),
                .total_original = std.atomic.Value(usize).init(0),
                .compression_count = std.atomic.Value(usize).init(0),
            },
        };
    }
    
    pub fn compress(self: *ThreadSafeCompressor, allocator: std.mem.Allocator, data: []const u8) ![]u8 {
        // Thread-safe compression with statistics
        const compressed = try archive.compressWithConfig(allocator, data, self.config);
        
        // Update statistics atomically
        _ = self.stats.total_original.fetchAdd(data.len, .monotonic);
        _ = self.stats.total_compressed.fetchAdd(compressed.len, .monotonic);
        _ = self.stats.compression_count.fetchAdd(1, .monotonic);
        
        return compressed;
    }
    
    pub fn getStats(self: *ThreadSafeCompressor) struct { 
        total_original: usize, 
        total_compressed: usize, 
        count: usize,
        ratio: f64,
    } {
        const original = self.stats.total_original.load(.monotonic);
        const compressed = self.stats.total_compressed.load(.monotonic);
        const count = self.stats.compression_count.load(.monotonic);
        
        const ratio = if (original > 0) 
            @as(f64, @floatFromInt(compressed)) / @as(f64, @floatFromInt(original)) * 100.0
        else 
            0.0;
        
        return .{
            .total_original = original,
            .total_compressed = compressed,
            .count = count,
            .ratio = ratio,
        };
    }
};

pub fn threadSafeCompressionExample(allocator: std.mem.Allocator) !void {
    const config = archive.CompressionConfig.init(.lz4).withLevel(.fastest);
    var compressor = ThreadSafeCompressor.init(config);
    
    const num_threads = 4;
    var threads: [num_threads]std.Thread = undefined;
    
    // Start multiple threads compressing data
    for (0..num_threads) |i| {
        threads[i] = try std.Thread.spawn(.{}, threadSafeWorker, .{ &compressor, allocator, i });
    }
    
    // Wait for completion
    for (threads) |thread| {
        thread.join();
    }
    
    // Print statistics
    const stats = compressor.getStats();
    std.debug.print("Thread-safe compression stats:\n", .{});
    std.debug.print("  Operations: {d}\n", .{stats.count});
    std.debug.print("  Original: {d} bytes\n", .{stats.total_original});
    std.debug.print("  Compressed: {d} bytes\n", .{stats.total_compressed});
    std.debug.print("  Ratio: {d:.1}%\n", .{stats.ratio});
}

fn threadSafeWorker(compressor: *ThreadSafeCompressor, allocator: std.mem.Allocator, thread_id: usize) void {
    for (0..10) |i| {
        const data = std.fmt.allocPrint(allocator, "Thread {d} iteration {d} data", .{ thread_id, i }) catch return;
        defer allocator.free(data);
        
        const compressed = compressor.compress(allocator, data) catch return;
        defer allocator.free(compressed);
        
        // Simulate some work
        std.time.sleep(10 * std.time.ns_per_ms);
    }
}
```

## Performance Optimization

### NUMA-Aware Threading

```zig
pub fn numaAwareCompression(allocator: std.mem.Allocator) !void {
    const num_cores = try std.Thread.getCpuCount();
    std.debug.print("Detected {d} CPU cores\n", .{num_cores});
    
    // Use optimal thread count (usually cores - 1 to leave one for OS)
    const optimal_threads = @max(1, num_cores - 1);
    
    var threads: []std.Thread = try allocator.alloc(std.Thread, optimal_threads);
    defer allocator.free(threads);
    
    var results: [][]u8 = try allocator.alloc([]u8, optimal_threads);
    defer {
        for (results) |result| {
            if (result.len > 0) allocator.free(result);
        }
        allocator.free(results);
    }
    
    // Create test data for each thread
    for (0..optimal_threads) |i| {
        const data = try std.fmt.allocPrint(allocator, "NUMA-aware thread {d} data " ** 100, .{i});
        defer allocator.free(data);
        
        threads[i] = try std.Thread.spawn(.{}, numaWorker, .{ data, &results[i] });
    }
    
    // Wait for completion
    for (threads) |thread| {
        thread.join();
    }
    
    // Process results
    var total_compressed: usize = 0;
    for (results) |result| {
        total_compressed += result.len;
    }
    
    std.debug.print("NUMA-aware compression completed: {d} total bytes\n", .{total_compressed});
}

fn numaWorker(data: []const u8, result: *[]u8) void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    result.* = archive.compress(allocator, data, .lz4) catch &[_]u8{};
}
```

### Lock-Free Operations

```zig
pub const LockFreeCounter = struct {
    value: std.atomic.Value(usize),
    
    pub fn init() LockFreeCounter {
        return LockFreeCounter{
            .value = std.atomic.Value(usize).init(0),
        };
    }
    
    pub fn increment(self: *LockFreeCounter) usize {
        return self.value.fetchAdd(1, .monotonic);
    }
    
    pub fn get(self: *LockFreeCounter) usize {
        return self.value.load(.monotonic);
    }
};

pub fn lockFreeExample(allocator: std.mem.Allocator) !void {
    var counter = LockFreeCounter.init();
    const num_threads = 4;
    var threads: [num_threads]std.Thread = undefined;
    
    // Start threads that increment counter during compression
    for (0..num_threads) |i| {
        threads[i] = try std.Thread.spawn(.{}, lockFreeWorker, .{ &counter, i });
    }
    
    // Wait for completion
    for (threads) |thread| {
        thread.join();
    }
    
    std.debug.print("Lock-free counter final value: {d}\n", .{counter.get()});
}

fn lockFreeWorker(counter: *LockFreeCounter, thread_id: usize) void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    for (0..100) |i| {
        const data = std.fmt.allocPrint(allocator, "Thread {d} operation {d}", .{ thread_id, i }) catch return;
        defer allocator.free(data);
        
        const compressed = archive.compress(allocator, data, .lz4) catch return;
        defer allocator.free(compressed);
        
        _ = counter.increment();
    }
}
```

## Error Handling in Threaded Code

### Thread-Safe Error Reporting

```zig
pub const ThreadSafeErrorReporter = struct {
    errors: std.ArrayList(ThreadError),
    mutex: std.Thread.Mutex,
    allocator: std.mem.Allocator,
    
    const ThreadError = struct {
        thread_id: usize,
        error_type: anyerror,
        message: []const u8,
        timestamp: i64,
    };
    
    pub fn init(allocator: std.mem.Allocator) ThreadSafeErrorReporter {
        return ThreadSafeErrorReporter{
            .errors = .empty,
            .mutex = std.Thread.Mutex{},
            .allocator = allocator,
        };
    }
    
    pub fn deinit(self: *ThreadSafeErrorReporter) void {
        for (self.errors.items) |err| {
            self.allocator.free(err.message);
        }
        self.errors.deinit(self.allocator);
    }
    
    pub fn reportError(self: *ThreadSafeErrorReporter, thread_id: usize, err: anyerror, message: []const u8) !void {
        const error_message = try self.allocator.dupe(u8, message);
        
        self.mutex.lock();
        defer self.mutex.unlock();
        
        try self.errors.append(ThreadError{
            .thread_id = thread_id,
            .error_type = err,
            .message = error_message,
            .timestamp = std.time.timestamp(),
        });
    }
    
    pub fn getErrors(self: *ThreadSafeErrorReporter) []const ThreadError {
        self.mutex.lock();
        defer self.mutex.unlock();
        
        return self.errors.items;
    }
};

pub fn threadSafeErrorHandling(allocator: std.mem.Allocator) !void {
    var error_reporter = ThreadSafeErrorReporter.init(allocator);
    defer error_reporter.deinit();
    
    const num_threads = 4;
    var threads: [num_threads]std.Thread = undefined;
    
    // Start threads that may encounter errors
    for (0..num_threads) |i| {
        threads[i] = try std.Thread.spawn(.{}, errorProneWorker, .{ &error_reporter, i });
    }
    
    // Wait for completion
    for (threads) |thread| {
        thread.join();
    }
    
    // Report errors
    const errors = error_reporter.getErrors();
    if (errors.len > 0) {
        std.debug.print("Errors encountered:\n", .{});
        for (errors) |err| {
            std.debug.print("  Thread {d}: {} - {s}\n", .{ err.thread_id, err.error_type, err.message });
        }
    } else {
        std.debug.print("No errors encountered\n", .{});
    }
}

fn errorProneWorker(error_reporter: *ThreadSafeErrorReporter, thread_id: usize) void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    for (0..10) |i| {
        // Simulate occasional errors
        if (i == 5 and thread_id == 2) {
            error_reporter.reportError(thread_id, error.SimulatedError, "Simulated compression error") catch {};
            continue;
        }
        
        const data = std.fmt.allocPrint(allocator, "Thread {d} data {d}", .{ thread_id, i }) catch {
            error_reporter.reportError(thread_id, error.OutOfMemory, "Failed to allocate test data") catch {};
            continue;
        };
        defer allocator.free(data);
        
        const compressed = archive.compress(allocator, data, .lz4) catch |err| {
            const msg = std.fmt.allocPrint(allocator, "Compression failed for iteration {d}", .{i}) catch "Compression failed";
            defer allocator.free(msg);
            error_reporter.reportError(thread_id, err, msg) catch {};
            continue;
        };
        defer allocator.free(compressed);
    }
}
```

## Best Practices

### Threading Guidelines

1. **Use separate allocators per thread** - Avoid contention
2. **Minimize shared state** - Reduce synchronization overhead
3. **Use atomic operations for counters** - Avoid locks when possible
4. **Size thread pools appropriately** - Usually CPU cores - 1
5. **Handle errors gracefully** - Don't let one thread failure affect others
6. **Monitor thread performance** - Profile and optimize bottlenecks
7. **Consider NUMA topology** - Optimize for memory locality
8. **Test thoroughly** - Threading bugs are hard to reproduce

### Performance Tips

```zig
pub fn performanceOptimizedThreading(allocator: std.mem.Allocator) !void {
    // Use optimal thread count
    const num_cores = try std.Thread.getCpuCount();
    const num_threads = @max(1, @min(num_cores, 8)); // Cap at 8 threads
    
    // Use fast algorithm for threading
    const config = archive.CompressionConfig.init(.lz4)
        .withLevel(.fastest)
        .withBufferSize(64 * 1024); // Moderate buffer size
    
    std.debug.print("Using {d} threads with LZ4 fast compression\n", .{num_threads});
    
    // Implementation would go here...
}
```

## Next Steps

- Learn about [Platforms](./platforms.md) for platform-specific threading
- Explore [Memory Management](./memory.md) for thread-safe allocators
- Check out [Error Handling](./errors.md) for robust threaded applications
- See [Examples](../examples/basic.md) for practical threading patterns