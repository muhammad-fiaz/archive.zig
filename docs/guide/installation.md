# Installation

This guide covers different ways to install and integrate Archive.zig into your project.

## Prerequisites

- **Zig 0.16.0** or later
- No external dependencies required

## Package Manager (Recommended)

The easiest way to add Archive.zig to your project is using Zig's built-in package manager:

### Stable Release

```bash
zig fetch --save https://github.com/muhammad-fiaz/archive.zig/archive/refs/tags/0.0.2.tar.gz
```

### Latest Development Version

```bash
zig fetch --save git+https://github.com/muhammad-fiaz/archive.zig.git
```

This automatically adds the dependency to your `build.zig.zon` file with the correct hash.

## Manual Configuration

### 1. Update build.zig.zon

Add Archive.zig to your project's `build.zig.zon`:

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .archive = .{
            .url = "https://github.com/muhammad-fiaz/archive.zig/archive/refs/tags/0.0.2.tar.gz",
            .hash = "1220...", // Run zig fetch to get the correct hash
        },
    },
}
```

### 2. Update build.zig

Add the dependency to your `build.zig`:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Add Archive.zig dependency
    const archive = b.dependency("archive", .{
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "my-app",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Add the archive module to your executable
    exe.root_module.addImport("archive", archive.module("archive"));

    b.installArtifact(exe);
}
```

### 3. Import in Your Code

```zig
const std = @import("std");
const archive = @import("archive");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    _ = allocator; // Your code here
}
```

## Verification

Verify your installation by creating a simple test:

```zig
const std = @import("std");
const archive = @import("archive");

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;

    const input = "Hello, Archive.zig!";
    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);

    std.debug.print("Installation successful! Compressed {d} bytes to {d} bytes\n", 
                   .{ input.len, compressed.len });
}
```

Run with:
```bash
zig build run
```

## Build Options

Archive.zig supports several build options:

### Target Platforms

Archive.zig works on all Zig-supported platforms:

```bash
# Linux x86_64
zig build -Dtarget=x86_64-linux

# Windows x86_64  
zig build -Dtarget=x86_64-windows

# macOS x86_64
zig build -Dtarget=x86_64-macos

# macOS ARM64
zig build -Dtarget=aarch64-macos

# And many more...
```

### Optimization Levels

```bash
# Debug build (default)
zig build

# Release with safety checks
zig build -Doptimize=ReleaseSafe

# Release optimized for speed
zig build -Doptimize=ReleaseFast

# Release optimized for size
zig build -Doptimize=ReleaseSmall
```

## Troubleshooting

### Hash Mismatch

If you get a hash mismatch error:

1. Delete the existing entry from `build.zig.zon`
2. Run `zig fetch --save <url>` again
3. The correct hash will be automatically added

### Build Errors

If you encounter build errors:

1. Ensure you're using Zig 0.16.0 or later:
   ```bash
   zig version
   ```

2. Clean your build cache:
   ```bash
   rm -rf zig-cache zig-out
   ```

3. Try building again:
   ```bash
   zig build
   ```

### Import Errors

If you get import errors:

1. Verify the module name in your `build.zig` matches your import:
   ```zig
   // In build.zig
   exe.root_module.addImport("archive", archive.module("archive"));
   
   // In your code
   const archive = @import("archive");
   ```

2. Make sure you've added the import to the correct executable/library target

## Next Steps

Now that Archive.zig is installed, check out:

- [Getting Started](./getting-started.md) - Your first compression program
- [Quick Start](./quick-start.md) - Common usage patterns
- [Configuration](./configuration.md) - Advanced configuration options
- [Examples](../examples/basic.md) - Practical examples