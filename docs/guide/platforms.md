# Platforms

Archive.zig is designed to work across all platforms supported by Zig, from desktop operating systems to embedded systems and bare metal targets. This guide covers platform-specific considerations, optimizations, and best practices.

## Supported Platforms

### Desktop Platforms

Archive.zig works on all major desktop platforms:

- **Windows** (x86_64, x86, aarch64)
- **Linux** (x86_64, x86, aarch64, arm, riscv64)
- **macOS** (x86_64, aarch64)
- **FreeBSD** (x86_64, x86, aarch64)

### Embedded and Bare Metal

Archive.zig supports embedded and bare metal targets:

- **ARM Cortex-M** (thumbv6m, thumbv7m, thumbv7em, thumbv8m)
- **RISC-V** (riscv32, riscv64)
- **AVR** (avr)
- **WebAssembly** (wasm32, wasm64)
- **Bare metal** (freestanding)

## Platform-Specific Optimizations

### Windows Optimizations

```zig
const std = @import("std");
const archive = @import("archive");

pub fn windowsOptimizations(allocator: std.mem.Allocator) !void {
    if (std.builtin.os.tag != .windows) return;
    
    // Windows-specific configuration
    const config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(10) // Good balance for desktop systems
        .withBufferSize(256 * 1024) // Larger buffers work well on Windows
        .withMemoryLevel(8); // Higher memory usage acceptable
    
    const input = "Windows-optimized compression data";
    const compressed = try archive.compressWithConfig(allocator, input, config);
    defer allocator.free(compressed);
    
    std.debug.print("Windows optimization: {d} bytes\n", .{compressed.len});
}

pub fn windowsFileHandling(allocator: std.mem.Allocator, io: std.Io) !void {
    if (std.builtin.os.tag != .windows) return;
    
    // Windows file path handling
    const input_path = "C:\\temp\\input.txt";
    const output_path = "C:\\temp\\output.gz";
    
    // Handle Windows-specific file attributes
    const input_file = std.Io.Dir.cwd().openFile(io, input_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("File not found: {s}\n", .{input_path});
            return;
        },
        error.AccessDenied => {
            std.debug.print("Access denied - check file permissions\n", .{});
            return;
        },
        else => return err,
    };
    defer input_file.close();
    
    // Read file with Windows line endings handling
    const file_size = try input_file.getEndPos();
    const file_data = try allocator.alloc(u8, file_size);
    defer allocator.free(file_data);
    
    _ = try input_file.readAll(file_data);
    
    // Compress and write
    const compressed = try archive.compress(allocator, file_data, .gzip);
    defer allocator.free(compressed);
    
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_path, .data = compressed });
    
    std.debug.print("Windows file handling completed\n", .{});
}
```

### Linux Optimizations

```zig
pub fn linuxOptimizations(allocator: std.mem.Allocator) !void {
    if (std.builtin.os.tag != .linux) return;
    
    // Linux-specific configuration
    const config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(15) // Higher compression for server environments
        .withBufferSize(512 * 1024) // Large buffers for server workloads
        .withMemoryLevel(9); // Maximum memory usage
    
    const input = "Linux server-optimized compression";
    const compressed = try archive.compressWithConfig(allocator, input, config);
    defer allocator.free(compressed);
    
    std.debug.print("Linux optimization: {d} bytes\n", .{compressed.len});
}

pub fn linuxSystemIntegration(allocator: std.mem.Allocator) !void {
    if (std.builtin.os.tag != .linux) return;
    
    // Use Linux-specific features
    const page_size = std.mem.page_size;
    std.debug.print("System page size: {d} bytes\n", .{page_size});
    
    // Align buffer to page size for better performance
    const aligned_size = std.mem.alignForward(usize, 128 * 1024, page_size);
    const config = archive.CompressionConfig.init(.lz4)
        .withBufferSize(aligned_size);
    
    const input = "Linux system-integrated compression";
    const compressed = try archive.compressWithConfig(allocator, input, config);
    defer allocator.free(compressed);
    
    std.debug.print("Linux system integration: {d} bytes\n", .{compressed.len});
}
```

### macOS Optimizations

```zig
pub fn macosOptimizations(allocator: std.mem.Allocator) !void {
    if (std.builtin.os.tag != .macos) return;
    
    // macOS-specific configuration
    const config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(12) // Balanced for macOS systems
        .withBufferSize(256 * 1024) // Good for macOS memory management
        .withMemoryLevel(7); // Moderate memory usage
    
    const input = "macOS-optimized compression data";
    const compressed = try archive.compressWithConfig(allocator, input, config);
    defer allocator.free(compressed);
    
    std.debug.print("macOS optimization: {d} bytes\n", .{compressed.len});
}

pub fn macosResourceHandling(allocator: std.mem.Allocator, io: std.Io) !void {
    if (std.builtin.os.tag != .macos) return;
    
    // Handle macOS resource forks and extended attributes
    const input_path = "/tmp/input.txt";
    const output_path = "/tmp/output.gz";
    
    // Check for extended attributes (simplified example)
    const input_file = try std.Io.Dir.cwd().openFile(io, input_path, .{});
    defer input_file.close();
    
    const file_data = try input_file.readToEndAlloc(allocator, 10 * 1024 * 1024);
    defer allocator.free(file_data);
    
    const compressed = try archive.compress(allocator, file_data, .gzip);
    defer allocator.free(compressed);
    
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_path, .data = compressed });
    
    std.debug.print("macOS resource handling completed\n", .{});
}
```

## Embedded Systems

### Memory-Constrained Environments

```zig
pub fn embeddedOptimizations(allocator: std.mem.Allocator) !void {
    // Configuration for embedded systems with limited memory
    const config = archive.CompressionConfig.init(.lz4) // Fast, low memory
        .withLevel(.fastest) // Minimize processing time
        .withBufferSize(4 * 1024) // Small 4KB buffer
        .withMemoryLevel(1); // Minimal memory usage
    
    const input = "Embedded system data";
    const compressed = try archive.compressWithConfig(allocator, input, config);
    defer allocator.free(compressed);
    
    std.debug.print("Embedded optimization: {d} bytes (ratio: {d:.1}%)\n", 
                   .{ compressed.len, @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input.len)) * 100 });
}

pub fn microcontrollerExample() !void {
    // Example for microcontroller with very limited resources
    comptime {
        if (std.builtin.cpu.arch == .thumb) {
            // ARM Cortex-M specific optimizations
            @compileLog("Compiling for ARM Cortex-M");
        }
    }
    
    // Use stack allocation for small buffers
    var stack_buffer: [1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&stack_buffer);
    const allocator = fba.allocator();
    
    const input = "MCU data";
    
    // Use fastest algorithm with minimal memory
    const compressed = archive.compress(allocator, input, .lz4) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("Not enough memory for compression\n", .{});
            return;
        },
        else => return err,
    };
    defer allocator.free(compressed);
    
    std.debug.print("Microcontroller compression: {d} bytes\n", .{compressed.len});
}
```

### Real-Time Systems

```zig
pub fn realTimeCompression(allocator: std.mem.Allocator) !void {
    // Configuration for real-time systems
    const config = archive.CompressionConfig.init(.lz4)
        .withLevel(.fastest) // Predictable, fast compression
        .withBufferSize(8 * 1024); // Small buffer for low latency
    
    // Simulate real-time data processing
    var i: u32 = 0;
    while (i < 100) {
        const start_time = std.time.nanoTimestamp();
        
        const data = try std.fmt.allocPrint(allocator, "Real-time packet {d}", .{i});
        defer allocator.free(data);
        
        const compressed = try archive.compressWithConfig(allocator, data, config);
        defer allocator.free(compressed);
        
        const end_time = std.time.nanoTimestamp();
        const duration_us = @as(f64, @floatFromInt(end_time - start_time)) / 1000.0;
        
        // Check if compression meets real-time constraints (e.g., < 100μs)
        if (duration_us > 100.0) {
            std.debug.print("Warning: Compression took {d:.2}μs (> 100μs)\n", .{duration_us});
        }
        
        i += 1;
        
        // Simulate real-time interval
        std.time.sleep(1 * std.time.ns_per_ms);
    }
    
    std.debug.print("Real-time compression test completed\n", .{});
}
```

## WebAssembly

### WASM Optimizations

```zig
pub fn wasmOptimizations(allocator: std.mem.Allocator) !void {
    if (std.builtin.cpu.arch != .wasm32 and std.builtin.cpu.arch != .wasm64) return;
    
    // WebAssembly-specific configuration
    const config = archive.CompressionConfig.init(.lz4) // Fast for web environments
        .withLevel(.fast) // Balance speed and size
        .withBufferSize(32 * 1024); // Moderate buffer for web
    
    const input = "WebAssembly compression data";
    const compressed = try archive.compressWithConfig(allocator, input, config);
    defer allocator.free(compressed);
    
    std.debug.print("WASM optimization: {d} bytes\n", .{compressed.len});
}

// Export functions for JavaScript interop
export fn compress_for_js(data_ptr: [*]const u8, data_len: usize, output_ptr: [*]u8, output_len: *usize) c_int {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    const input_data = data_ptr[0..data_len];
    
    const compressed = archive.compress(allocator, input_data, .lz4) catch return -1;
    defer allocator.free(compressed);
    
    if (compressed.len > output_len.*) {
        output_len.* = compressed.len;
        return -2; // Buffer too small
    }
    
    @memcpy(output_ptr[0..compressed.len], compressed);
    output_len.* = compressed.len;
    return 0; // Success
}
```

## Cross-Platform Considerations

### Endianness Handling

```zig
pub fn crossPlatformEndianness(allocator: std.mem.Allocator) !void {
    const input = "Cross-platform data with endianness considerations";
    
    // Compress data
    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);
    
    // Handle endianness for cross-platform compatibility
    const native_endian = std.builtin.cpu.arch.endian();
    std.debug.print("Native endianness: {}\n", .{native_endian});
    
    // For network protocols or file formats, ensure consistent byte order
    if (compressed.len >= 4) {
        const header_bytes = compressed[0..4];
        std.debug.print("Header bytes: {X:0>2} {X:0>2} {X:0>2} {X:0>2}\n", 
                       .{ header_bytes[0], header_bytes[1], header_bytes[2], header_bytes[3] });
    }
    
    std.debug.print("Cross-platform compression: {d} bytes\n", .{compressed.len});
}
```

### Path Handling

```zig
pub fn crossPlatformPaths(allocator: std.mem.Allocator) !void {
    // Handle different path separators across platforms
    const separator = std.fs.path.sep;
    
    const input_path = try std.fmt.allocPrint(allocator, "data{c}input.txt", .{separator});
    defer allocator.free(input_path);
    
    const output_path = try std.fmt.allocPrint(allocator, "data{c}output.gz", .{separator});
    defer allocator.free(output_path);
    
    std.debug.print("Platform paths: {s} -> {s}\n", .{ input_path, output_path });
    
    // Normalize paths for cross-platform compatibility
    var normalized_input = try allocator.alloc(u8, input_path.len);
    defer allocator.free(normalized_input);
    
    _ = std.fs.path.resolve(allocator, &[_][]const u8{input_path}) catch {
        std.debug.print("Path resolution failed\n", .{});
        return;
    };
}
```

## Performance Profiling

### Platform-Specific Benchmarks

```zig
pub fn platformBenchmarks(allocator: std.mem.Allocator) !void {
    const test_data = "Benchmark data for platform performance testing " ** 100;
    
    const algorithms = [_]archive.Algorithm{ .lz4, .gzip, .zstd };
    
    std.debug.print("Platform: {s}\n", .{@tagName(std.builtin.os.tag)});
    std.debug.print("Architecture: {s}\n", .{@tagName(std.builtin.cpu.arch)});
    std.debug.print("Algorithm | Time (ms) | Size | Ratio\n");
    std.debug.print("----------|-----------|------|------\n");
    
    for (algorithms) |algo| {
        const start_time = std.time.nanoTimestamp();
        const compressed = try archive.compress(allocator, test_data, algo);
        defer allocator.free(compressed);
        const end_time = std.time.nanoTimestamp();
        
        const duration_ms = @as(f64, @floatFromInt(end_time - start_time)) / 1_000_000.0;
        const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(test_data.len)) * 100;
        
        std.debug.print("{s:>9} | {d:>9.2} | {d:>4} | {d:>5.1}%\n", 
                       .{ @tagName(algo), duration_ms, compressed.len, ratio });
    }
}
```

### Memory Usage Profiling

```zig
pub fn platformMemoryProfile(allocator: std.mem.Allocator) !void {
    const initial_memory = getCurrentMemoryUsage();
    
    const test_data = try allocator.alloc(u8, 1024 * 1024); // 1MB
    defer allocator.free(test_data);
    
    // Fill with test pattern
    for (test_data, 0..) |*byte, i| {
        byte.* = @intCast(i % 256);
    }
    
    const before_compression = getCurrentMemoryUsage();
    
    const compressed = try archive.compress(allocator, test_data, .zstd);
    defer allocator.free(compressed);
    
    const after_compression = getCurrentMemoryUsage();
    
    std.debug.print("Memory usage profile:\n", .{});
    std.debug.print("  Initial: {d} KB\n", .{initial_memory / 1024});
    std.debug.print("  Before compression: {d} KB\n", .{before_compression / 1024});
    std.debug.print("  After compression: {d} KB\n", .{after_compression / 1024});
    std.debug.print("  Peak usage: {d} KB\n", .{(after_compression - initial_memory) / 1024});
}

fn getCurrentMemoryUsage() usize {
    // Platform-specific memory usage detection
    switch (std.builtin.os.tag) {
        .linux => {
            // Read from /proc/self/status on Linux
            const status_file = std.fs.openFileAbsolute("/proc/self/status", .{}) catch return 0;
            defer status_file.close();
            
            var buffer: [4096]u8 = undefined;
            const bytes_read = status_file.readAll(&buffer) catch return 0;
            
            // Parse VmRSS line (simplified)
            var lines = std.mem.split(u8, buffer[0..bytes_read], "\n");
            while (lines.next()) |line| {
                if (std.mem.startsWith(u8, line, "VmRSS:")) {
                    // Extract memory value (simplified parsing)
                    var parts = std.mem.split(u8, line, " ");
                    _ = parts.next(); // Skip "VmRSS:"
                    if (parts.next()) |value_str| {
                        return std.fmt.parseInt(usize, std.mem.trim(u8, value_str, " \t"), 10) catch 0;
                    }
                }
            }
            return 0;
        },
        .windows => {
            // Windows memory usage would require Win32 API calls
            return 0;
        },
        .macos => {
            // macOS memory usage would require system calls
            return 0;
        },
        else => return 0,
    }
}
```

## Build Configuration

### Platform-Specific Build Options

```zig
// In build.zig
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const exe = b.addExecutable(.{
        .name = "archive-example",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    
    // Platform-specific optimizations
    switch (target.result.os.tag) {
        .windows => {
            // Windows-specific build options
            exe.linkSystemLibrary("kernel32");
            exe.addCSourceFile(.{
                .file = b.path("src/windows_specific.c"),
                .flags = &[_][]const u8{"-DWINDOWS_BUILD"},
            });
        },
        .linux => {
            // Linux-specific build options
            exe.linkSystemLibrary("c");
            exe.addCSourceFile(.{
                .file = b.path("src/linux_specific.c"),
                .flags = &[_][]const u8{"-DLINUX_BUILD"},
            });
        },
        .macos => {
            // macOS-specific build options
            exe.linkFramework("Foundation");
            exe.addCSourceFile(.{
                .file = b.path("src/macos_specific.c"),
                .flags = &[_][]const u8{"-DMACOS_BUILD"},
            });
        },
        else => {},
    }
    
    // Architecture-specific optimizations
    switch (target.result.cpu.arch) {
        .x86_64 => {
            exe.root_module.addCMacro("ARCH_X86_64", "1");
        },
        .aarch64 => {
            exe.root_module.addCMacro("ARCH_AARCH64", "1");
        },
        .wasm32, .wasm64 => {
            exe.root_module.addCMacro("ARCH_WASM", "1");
        },
        else => {},
    }
    
    b.installArtifact(exe);
}
```

## Best Practices

### Platform-Specific Guidelines

1. **Test on target platforms** - Don't assume cross-platform compatibility
2. **Use appropriate algorithms** - Consider platform constraints
3. **Handle endianness** - Ensure consistent byte order for data exchange
4. **Optimize for platform** - Use platform-specific optimizations
5. **Consider memory constraints** - Embedded systems need special attention
6. **Profile performance** - Benchmark on actual target hardware
7. **Handle platform differences** - File systems, paths, line endings
8. **Use conditional compilation** - Platform-specific code paths

### Universal Configuration

```zig
pub fn universalConfig() archive.CompressionConfig {
    // Configuration that works well across all platforms
    return archive.CompressionConfig.init(.lz4)
        .withLevel(.fast) // Good balance everywhere
        .withBufferSize(64 * 1024) // Reasonable for most platforms
        .withMemoryLevel(6); // Moderate memory usage
}

pub fn platformOptimizedConfig() archive.CompressionConfig {
    // Choose configuration based on platform capabilities
    switch (std.builtin.os.tag) {
        .windows, .macos, .linux => {
            // Desktop platforms - can use more resources
            return archive.CompressionConfig.init(.zstd)
                .withZstdLevel(10)
                .withBufferSize(256 * 1024)
                .withMemoryLevel(8);
        },
        .freestanding => {
            // Embedded/bare metal - minimal resources
            return archive.CompressionConfig.init(.lz4)
                .withLevel(.fastest)
                .withBufferSize(4 * 1024)
                .withMemoryLevel(1);
        },
        else => {
            // Other platforms - conservative settings
            return archive.CompressionConfig.init(.gzip)
                .withLevel(.default)
                .withBufferSize(32 * 1024)
                .withMemoryLevel(4);
        },
    }
}
```

## Next Steps

- Review [Memory Management](./memory.md) for platform-specific memory optimization
- Check [Threading](./threading.md) for platform-specific concurrency
- Explore [Error Handling](./errors.md) for platform-specific error conditions
- See [Examples](../examples/basic.md) for platform-specific usage patterns