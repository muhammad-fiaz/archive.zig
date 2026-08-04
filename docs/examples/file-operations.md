# File Operations Examples

This page demonstrates how to work with files using Archive.zig, including compression, decompression, and batch processing operations.

## Basic File Operations

### Compressing Files

```zig
const std = @import("std");
const archive = @import("archive");

pub fn compressFileExample(allocator: std.mem.Allocator, io: std.Io) !void {
    // Create a test file
    const test_content = "This is test content for file compression example.\n" ** 100;
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = "test_input.txt", .data = test_content });
    
    // Read and compress file
    const input_data = try std.Io.Dir.cwd().readFileAlloc(io, "test_input.txt", allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(input_data);
    
    const compressed = try archive.compress(allocator, input_data, .gzip);
    defer allocator.free(compressed);
    
    // Write compressed file
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = "test_output.gz", .data = compressed });
    
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input_data.len)) * 100;
    std.debug.print("File compression:\n");
    std.debug.print("  Input: {d} bytes\n", .{input_data.len});
    std.debug.print("  Output: {d} bytes ({d:.1}%)\n", .{ compressed.len, ratio });
    
    // Clean up
    std.Io.Dir.cwd().deleteFile(io, "test_input.txt") catch {};
    std.Io.Dir.cwd().deleteFile(io, "test_output.gz") catch {};
}
```

### Decompressing Files

```zig
pub fn decompressFileExample(allocator: std.mem.Allocator, io: std.Io) !void {
    // Create test compressed file
    const original_content = "This is the original content that will be compressed and then decompressed.\n" ** 50;
    const compressed = try archive.compress(allocator, original_content, .zstd);
    defer allocator.free(compressed);
    
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = "compressed_test.zst", .data = compressed });
    
    // Read and decompress file
    const compressed_data = try std.Io.Dir.cwd().readFileAlloc(io, "compressed_test.zst", allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(compressed_data);
    
    // Decompress
    const decompressed = try archive.decompress(allocator, compressed_data, .zstd);
    defer allocator.free(decompressed);
    
    // Write decompressed file
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = "decompressed_test.txt", .data = decompressed });
    
    // Verify integrity
    const matches = std.mem.eql(u8, original_content, decompressed);
    
    std.debug.print("File decompression:\n");
    std.debug.print("  Compressed: {d} bytes\n", .{compressed_data.len});
    std.debug.print("  Decompressed: {d} bytes\n", .{decompressed.len});
    std.debug.print("  Integrity check: {s}\n", .{if (matches) "PASS" else "FAIL"});
    
    // Clean up
    std.Io.Dir.cwd().deleteFile(io, "compressed_test.zst") catch {};
    std.Io.Dir.cwd().deleteFile(io, "decompressed_test.txt") catch {};
}
```

## Batch File Processing

### Compressing Multiple Files

```zig
pub fn batchCompressionExample(allocator: std.mem.Allocator, io: std.Io) !void {
    // Create test files
    const test_files = [_]struct { name: []const u8, content: []const u8 }{
        .{ .name = "document1.txt", .content = "Document 1 content with some text data.\n" ** 20 },
        .{ .name = "document2.txt", .content = "Document 2 content with different text.\n" ** 30 },
        .{ .name = "data.json", .content = "{\"key\": \"value\", \"array\": [1, 2, 3]}\n" ** 15 },
        .{ .name = "config.xml", .content = "<config><setting>value</setting></config>\n" ** 25 },
    };
    
    // Create test files
    for (test_files) |file_info| {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = file_info.name, .data = file_info.content });
    }
    
    std.debug.print("Batch compression results:\n");
    
    // Compress each file
    for (test_files) |file_info| {
        const input_data = try std.Io.Dir.cwd().readFileAlloc(io, file_info.name, allocator, .limited(1024 * 1024));
        defer allocator.free(input_data);
        
        const compressed = try archive.compress(allocator, input_data, .gzip);
        defer allocator.free(compressed);
        
        const output_name = try std.fmt.allocPrint(allocator, "{s}.gz", .{file_info.name});
        defer allocator.free(output_name);
        
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_name, .data = compressed });
        
        const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(input_data.len)) * 100;
        std.debug.print("  {s}: {d} -> {d} bytes ({d:.1}%)\n", 
                       .{ file_info.name, input_data.len, compressed.len, ratio });
        
        // Clean up
        std.Io.Dir.cwd().deleteFile(io, file_info.name) catch {};
        std.Io.Dir.cwd().deleteFile(io, output_name) catch {};
    }
}
```

### Directory Compression

```zig
pub fn directoryCompressionExample(allocator: std.mem.Allocator, io: std.Io) !void {
    // Create test directory structure
    try std.Io.Dir.cwd().makeDir(io, "test_dir");
    try std.Io.Dir.cwd().makeDir(io, "test_dir/subdir");
    
    const test_files = [_]struct { path: []const u8, content: []const u8 }{
        .{ .path = "test_dir/file1.txt", .content = "Content of file 1\n" ** 10 },
        .{ .path = "test_dir/file2.txt", .content = "Content of file 2\n" ** 15 },
        .{ .path = "test_dir/subdir/file3.txt", .content = "Content of file 3\n" ** 8 },
        .{ .path = "test_dir/subdir/file4.txt", .content = "Content of file 4\n" ** 12 },
    };
    
    // Create test files
    for (test_files) |file_info| {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = file_info.path, .data = file_info.content });
    }
    
    // Collect all files in directory
    var file_list = .empty;
    defer {
        for (file_list.items) |path| {
            allocator.free(path);
        }
        file_list.deinit(allocator);
    }
    
    try collectFilesRecursive(allocator, "test_dir", &file_list, io);
    
    // Create archive data
    var archive_data = .empty;
    defer archive_data.deinit(allocator);
    
    for (file_list.items) |file_path| {
        const file_data = try std.Io.Dir.cwd().readFileAlloc(io, file_path, allocator, .limited(1024 * 1024));
        defer allocator.free(file_data);
        
        // Simple archive format: path_length + path + data_length + data
        const path_len = @as(u32, @intCast(file_path.len));
        const data_len = @as(u32, @intCast(file_data.len));
        
        try archive_data.appendSlice(std.mem.asBytes(&path_len));
        try archive_data.appendSlice(file_path);
        try archive_data.appendSlice(std.mem.asBytes(&data_len));
        try archive_data.appendSlice(file_data);
    }
    
    // Compress archive
    const compressed_archive = try archive.compress(allocator, archive_data.items, .zstd);
    defer allocator.free(compressed_archive);
    
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = "directory_archive.zst", .data = compressed_archive });
    
    const ratio = @as(f64, @floatFromInt(compressed_archive.len)) / @as(f64, @floatFromInt(archive_data.items.len)) * 100;
    
    std.debug.print("Directory compression:\n");
    std.debug.print("  Files: {d}\n", .{file_list.items.len});
    std.debug.print("  Original: {d} bytes\n", .{archive_data.items.len});
    std.debug.print("  Compressed: {d} bytes ({d:.1}%)\n", .{ compressed_archive.len, ratio });
    
    // Clean up
    for (test_files) |file_info| {
        std.Io.Dir.cwd().deleteFile(io, file_info.path) catch {};
    }
    std.Io.Dir.cwd().deleteDir(io, "test_dir/subdir") catch {};
    std.Io.Dir.cwd().deleteDir(io, "test_dir") catch {};
    std.Io.Dir.cwd().deleteFile(io, "directory_archive.zst") catch {};
}

fn collectFilesRecursive(allocator: std.mem.Allocator, dir_path: []const u8, file_list: *std.ArrayList([]const u8), io: std.Io) !void {
    var dir = try std.Io.Dir.cwd().openDir(io, dir_path, .{ .iterate = true });
    defer dir.close();
    
    var iterator = dir.iterate();
    while (try iterator.next()) |entry| {
        const full_path = try std.fs.path.join(allocator, &[_][]const u8{ dir_path, entry.name });
        
        switch (entry.kind) {
            .file => try file_list.append(full_path),
            .directory => {
                try collectFilesRecursive(allocator, full_path, file_list, io);
                allocator.free(full_path);
            },
            else => allocator.free(full_path),
        }
    }
}
```

## Advanced File Operations

### Atomic File Operations

```zig
pub fn atomicFileOperations(allocator: std.mem.Allocator, io: std.Io) !void {
    const original_content = "Important data that must be handled atomically\n" ** 50;
    
    // Create original file
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = "important_data.txt", .data = original_content });
    
    // Atomic compression: write to temporary file first
    const temp_path = "important_data.txt.gz.tmp";
    const final_path = "important_data.txt.gz";
    
    // Read original file
    const input_data = try std.Io.Dir.cwd().readFileAlloc(io, "important_data.txt", allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(input_data);
    
    // Compress data
    const compressed = try archive.compress(allocator, input_data, .gzip);
    defer allocator.free(compressed);
    
    // Write to temporary file
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = temp_path, .data = compressed });
    
    // Verify compressed file by decompressing
    const temp_data = try std.Io.Dir.cwd().readFileAlloc(io, temp_path, allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(temp_data);
    
    const verified = try archive.decompress(allocator, temp_data, .gzip);
    defer allocator.free(verified);
    
    if (!std.mem.eql(u8, original_content, verified)) {
        std.Io.Dir.cwd().deleteFile(io, temp_path) catch {};
        return error.VerificationFailed;
    }
    
    // Atomically move temporary file to final location
    try std.Io.Dir.cwd().rename(io, temp_path, final_path);
    
    std.debug.print("Atomic file compression:\n");
    std.debug.print("  Original: {d} bytes\n", .{input_data.len});
    std.debug.print("  Compressed: {d} bytes\n", .{compressed.len});
    std.debug.print("  Verification: PASS\n");
    std.debug.print("  Atomic operation: SUCCESS\n");
    
    // Clean up
    std.Io.Dir.cwd().deleteFile(io, "important_data.txt") catch {};
    std.Io.Dir.cwd().deleteFile(io, final_path) catch {};
}
```

### File Backup and Compression

```zig
pub fn backupAndCompress(allocator: std.mem.Allocator, file_path: []const u8, io: std.Io) !void {
    std.debug.print("Backing up and compressing: {s}\n", .{file_path});
    
    // Create test file if it doesn't exist
    const test_content = "This is test content for backup and compression example.\n" ** 100;
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = file_path, .data = test_content });
    
    // Create backup filename
    const backup_path = try std.fmt.allocPrint(allocator, "{s}.backup", .{file_path});
    defer allocator.free(backup_path);
    
    const compressed_path = try std.fmt.allocPrint(allocator, "{s}.gz", .{file_path});
    defer allocator.free(compressed_path);
    
    // Create backup copy
    try std.Io.Dir.cwd().copyFile(io, file_path, std.Io.Dir.cwd(), backup_path, .{});
    
    // Read and compress original file
    const file_data = try std.Io.Dir.cwd().readFileAlloc(io, file_path, allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(file_data);
    
    const compressed = archive.compress(allocator, file_data, .gzip) catch |err| {
        // Restore from backup on compression error
        std.Io.Dir.cwd().copyFile(io, backup_path, std.Io.Dir.cwd(), file_path, .{}) catch {};
        std.Io.Dir.cwd().deleteFile(io, backup_path) catch {};
        return err;
    };
    defer allocator.free(compressed);
    
    // Write compressed file
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = compressed_path, .data = compressed }) catch |err| {
        // Restore from backup on write error
        std.Io.Dir.cwd().copyFile(io, backup_path, std.Io.Dir.cwd(), file_path, .{}) catch {};
        std.Io.Dir.cwd().deleteFile(io, backup_path) catch {};
        return err;
    };
    
    // Verify compressed file
    const verify_data = try std.Io.Dir.cwd().readFileAlloc(io, compressed_path, allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(verify_data);
    
    const decompressed = archive.decompress(allocator, verify_data, .gzip) catch |err| {
        // Restore from backup on verification error
        std.Io.Dir.cwd().copyFile(io, backup_path, std.Io.Dir.cwd(), file_path, .{}) catch {};
        std.Io.Dir.cwd().deleteFile(io, backup_path) catch {};
        std.Io.Dir.cwd().deleteFile(io, compressed_path) catch {};
        return err;
    };
    defer allocator.free(decompressed);
    
    if (!std.mem.eql(u8, file_data, decompressed)) {
        // Restore from backup on data mismatch
        std.Io.Dir.cwd().copyFile(io, backup_path, std.Io.Dir.cwd(), file_path, .{}) catch {};
        std.Io.Dir.cwd().deleteFile(io, backup_path) catch {};
        std.Io.Dir.cwd().deleteFile(io, compressed_path) catch {};
        return error.DataMismatch;
    }
    
    // Success - remove backup
    try std.Io.Dir.cwd().deleteFile(io, backup_path);
    
    const ratio = @as(f64, @floatFromInt(compressed.len)) / @as(f64, @floatFromInt(file_data.len)) * 100;
    
    std.debug.print("  Original: {d} bytes\n", .{file_data.len});
    std.debug.print("  Compressed: {d} bytes ({d:.1}%)\n", .{ compressed.len, ratio });
    std.debug.print("  Backup and compression: SUCCESS\n");
    
    // Clean up
    std.Io.Dir.cwd().deleteFile(io, file_path) catch {};
    std.Io.Dir.cwd().deleteFile(io, compressed_path) catch {};
}

pub fn backupExample(allocator: std.mem.Allocator, io: std.Io) !void {
    try backupAndCompress(allocator, "test_backup_file.txt", io);
}
```

### File Integrity Verification

```zig
pub fn fileIntegrityExample(allocator: std.mem.Allocator, io: std.Io) !void {
    const original_content = "File integrity verification test content.\n" ** 75;
    
    // Create and compress file
    const compressed = try archive.compress(allocator, original_content, .zstd);
    defer allocator.free(compressed);
    
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = "integrity_test.zst", .data = compressed });
    
    // Function to verify file integrity
    const verifyFile = struct {
        fn verify(alloc: std.mem.Allocator, file_path: []const u8, expected: []const u8, io: std.Io) !bool {
            const file_data = try std.Io.Dir.cwd().readFileAlloc(io, file_path, allocator, .limited(10 * 1024 * 1024));
            defer alloc.free(file_data);
            
            const decompressed = try archive.decompress(alloc, file_data, .zstd);
            defer alloc.free(decompressed);
            
            return std.mem.eql(u8, expected, decompressed);
        }
    }.verify;
    
    // Test 1: Verify intact file
    const intact_result = try verifyFile(allocator, "integrity_test.zst", original_content, io);
    std.debug.print("File integrity verification:\n");
    std.debug.print("  Intact file: {s}\n", .{if (intact_result) "PASS" else "FAIL"});
    
    // Test 2: Simulate corruption
    const file_data = try std.Io.Dir.cwd().readFileAlloc(io, "integrity_test.zst", allocator, .limited(10 * 1024 * 1024));
    defer allocator.free(file_data);
    
    var corrupted_data = try allocator.dupe(u8, file_data);
    defer allocator.free(corrupted_data);
    
    // Corrupt some bytes (but not the header)
    if (corrupted_data.len > 20) {
        corrupted_data[10] ^= 0xFF;
        corrupted_data[15] ^= 0xFF;
        corrupted_data[20] ^= 0xFF;
    }
    
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = "integrity_test_corrupted.zst", .data = corrupted_data });
    
    const corrupted_result = verifyFile(allocator, "integrity_test_corrupted.zst", original_content, io) catch false;
    std.debug.print("  Corrupted file: {s}\n", .{if (corrupted_result) "FAIL (should have failed)" else "PASS (correctly detected corruption)"});
    
    // Test 3: Verify checksum-enabled compression
    const config = archive.CompressionConfig.init(.zstd)
        .withZstdLevel(10)
        .withChecksum();
    
    const checksum_compressed = try archive.compressWithConfig(allocator, original_content, config);
    defer allocator.free(checksum_compressed);
    
    try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = "integrity_test_checksum.zst", .data = checksum_compressed });
    
    const checksum_result = try verifyFile(allocator, "integrity_test_checksum.zst", original_content, io);
    std.debug.print("  Checksum-enabled: {s}\n", .{if (checksum_result) "PASS" else "FAIL"});
    
    // Clean up
    std.Io.Dir.cwd().deleteFile(io, "integrity_test.zst") catch {};
    std.Io.Dir.cwd().deleteFile(io, "integrity_test_corrupted.zst") catch {};
    std.Io.Dir.cwd().deleteFile(io, "integrity_test_checksum.zst") catch {};
}
```

## Configuration-Based File Operations

### Filtered File Compression

```zig
pub fn filteredFileCompression(allocator: std.mem.Allocator, io: std.Io) !void {
    // Create test directory structure
    try std.Io.Dir.cwd().makeDir(io, "project");
    try std.Io.Dir.cwd().makeDir(io, "project/src");
    try std.Io.Dir.cwd().makeDir(io, "project/build");
    try std.Io.Dir.cwd().makeDir(io, "project/docs");
    
    const test_files = [_]struct { path: []const u8, content: []const u8 }{
        .{ .path = "project/src/main.zig", .content = "const std = @import(\"std\");\n" ** 20 },
        .{ .path = "project/src/utils.zig", .content = "pub fn helper() void {}\n" ** 15 },
        .{ .path = "project/build/output.exe", .content = "BINARY_DATA" ** 100 },
        .{ .path = "project/build/temp.tmp", .content = "TEMP_DATA" ** 50 },
        .{ .path = "project/docs/README.md", .content = "# Project Documentation\n" ** 30 },
        .{ .path = "project/debug.log", .content = "DEBUG LOG ENTRY\n" ** 40 },
    };
    
    // Create test files
    for (test_files) |file_info| {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = file_info.path, .data = file_info.content });
    }
    
    // Configuration to include only source and documentation files
    const include_rules = [_]archive.FilterRule{
        .{ .pattern = "*.zig", .is_directory = false },
        .{ .pattern = "*.md", .is_directory = false },
    };
    const exclude_rules = [_]archive.FilterRule{
        .{ .pattern = "*.tmp", .is_directory = false },
        .{ .pattern = "*.log", .is_directory = false },
        .{ .pattern = "*.exe", .is_directory = false },
    };
    
    const config = archive.CompressionConfig.init(.zstd)
        .withPathFilter(.{ .include_rules = &include_rules, .exclude_rules = &exclude_rules })
        .withRecursive(true)
        .withZstdLevel(12);
    
    // Collect and filter files
    var all_files = .empty;
    defer {
        for (all_files.items) |path| {
            allocator.free(path);
        }
        all_files.deinit(allocator);
    }
    
    try collectFilesRecursive(allocator, "project", &all_files, io);
    
    var filtered_files = .empty;
    defer filtered_files.deinit(allocator);
    
    for (all_files.items) |file_path| {
        if (config.path_filter.shouldInclude(file_path, false)) {
            try filtered_files.append(file_path);
        }
    }
    
    std.debug.print("Filtered file compression:\n");
    std.debug.print("  Total files: {d}\n", .{all_files.items.len});
    std.debug.print("  Filtered files: {d}\n", .{filtered_files.items.len});
    
    // Compress filtered files
    var total_original: usize = 0;
    var total_compressed: usize = 0;
    
    for (filtered_files.items) |file_path| {
        const file_data = try std.Io.Dir.cwd().readFileAlloc(io, file_path, allocator, .limited(1024 * 1024));
        defer allocator.free(file_data);
        
        const compressed = try archive.compressWithConfig(allocator, file_data, config);
        defer allocator.free(compressed);
        
        const output_path = try std.fmt.allocPrint(allocator, "{s}.zst", .{file_path});
        defer allocator.free(output_path);
        
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_path, .data = compressed });
        
        total_original += file_data.len;
        total_compressed += compressed.len;
        
        std.debug.print("    {s}: {d} -> {d} bytes\n", .{ file_path, file_data.len, compressed.len });
        
        // Clean up compressed file
        std.Io.Dir.cwd().deleteFile(io, output_path) catch {};
    }
    
    const overall_ratio = @as(f64, @floatFromInt(total_compressed)) / @as(f64, @floatFromInt(total_original)) * 100;
    std.debug.print("  Overall: {d} -> {d} bytes ({d:.1}%)\n", .{ total_original, total_compressed, overall_ratio });
    
    // Clean up test files and directories
    for (test_files) |file_info| {
        std.Io.Dir.cwd().deleteFile(io, file_info.path) catch {};
    }
    std.Io.Dir.cwd().deleteDir(io, "project/src") catch {};
    std.Io.Dir.cwd().deleteDir(io, "project/build") catch {};
    std.Io.Dir.cwd().deleteDir(io, "project/docs") catch {};
    std.Io.Dir.cwd().deleteDir(io, "project") catch {};
}
```

## Error Handling in File Operations

### Robust File Processing

```zig
pub fn robustFileProcessing(allocator: std.mem.Allocator, io: std.Io) !void {
    const test_files = [_]struct { name: []const u8, content: []const u8, should_fail: bool }{
        .{ .name = "good_file.txt", .content = "Good file content\n" ** 50, .should_fail = false },
        .{ .name = "empty_file.txt", .content = "", .should_fail = true },
        .{ .name = "large_file.txt", .content = "Large file content\n" ** 1000, .should_fail = false },
    };
    
    // Create test files
    for (test_files) |file_info| {
        try std.Io.Dir.cwd().writeFile(io, .{ .sub_path = file_info.name, .data = file_info.content });
    }
    
    std.debug.print("Robust file processing:\n");
    
    var success_count: usize = 0;
    var error_count: usize = 0;
    
    for (test_files) |file_info| {
        std.debug.print("  Processing {s}: ", .{file_info.name});
        
        const result = processFileRobustly(allocator, file_info.name, io);
        if (result) {
            std.debug.print("SUCCESS\n");
            success_count += 1;
        } else |err| {
            std.debug.print("ERROR - {}\n", .{err});
            error_count += 1;
        }
        
        // Clean up
        std.Io.Dir.cwd().deleteFile(io, file_info.name) catch {};
        
        const output_name = try std.fmt.allocPrint(allocator, "{s}.gz", .{file_info.name});
        defer allocator.free(output_name);
        std.Io.Dir.cwd().deleteFile(io, output_name) catch {};
    }
    
    std.debug.print("  Results: {d} success, {d} errors\n", .{ success_count, error_count });
}

fn processFileRobustly(allocator: std.mem.Allocator, file_path: []const u8, io: std.Io) !void {
    // Check if file exists and get info
    const file_stat = std.Io.Dir.cwd().statFile(io, file_path, .{}) catch |err| switch (err) {
        error.FileNotFound => {
            std.debug.print("File not found");
            return err;
        },
        error.AccessDenied => {
            std.debug.print("Access denied");
            return err;
        },
        else => return err,
    };
    
    // Check file size
    if (file_stat.size == 0) {
        std.debug.print("Empty file");
        return error.EmptyFile;
    }
    
    if (file_stat.size > 10 * 1024 * 1024) { // 10MB limit
        std.debug.print("File too large");
        return error.FileTooLarge;
    }
    
    // Read file
    const file_data = std.Io.Dir.cwd().readFileAlloc(io, file_path, allocator, .limited(@intCast(file_stat.size))) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("Out of memory");
            return err;
        },
        else => return err,
    };
    defer allocator.free(file_data);
    
    // Compress file
    const compressed = archive.compress(allocator, file_data, .gzip) catch |err| switch (err) {
        error.OutOfMemory => {
            std.debug.print("Compression out of memory");
            return err;
        },
        error.InvalidData => {
            std.debug.print("Invalid data for compression");
            return err;
        },
        else => return err,
    };
    defer allocator.free(compressed);
    
    // Write compressed file
    const output_path = try std.fmt.allocPrint(allocator, "{s}.gz", .{file_path});
    defer allocator.free(output_path);
    
    std.Io.Dir.cwd().writeFile(io, .{ .sub_path = output_path, .data = compressed }) catch |err| switch (err) {
        error.AccessDenied => {
            std.debug.print("Cannot write output");
            return err;
        },
        error.NoSpaceLeft => {
            std.debug.print("No space left");
            return err;
        },
        else => return err,
    };
}
```

## Next Steps

- Learn about [Streaming](./streaming.md) for memory-efficient file processing
- Explore [Configuration](./configuration.md) for advanced file filtering
- See [Builder Pattern](./builder.md) for flexible configuration options