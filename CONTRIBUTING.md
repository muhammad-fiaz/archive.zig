# Contributing to Archive.zig

Thank you for your interest in contributing to Archive.zig! This document provides guidelines and information for contributors.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Contributing Guidelines](#contributing-guidelines)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Issue Reporting](#issue-reporting)
- [Community](#community)

## Code of Conduct

This project adheres to a code of conduct that we expect all contributors to follow. Please be respectful and constructive in all interactions.

### Our Standards

- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Gracefully accept constructive criticism
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

- **Zig 0.16.0 or later**: Download from [ziglang.org](https://ziglang.org/download/)
- **Git**: For version control
- **Basic knowledge of compression algorithms** (helpful but not required)

### Fork and Clone

1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/archive.zig.git
   cd archive.zig
   ```

3. Add the upstream repository:
   ```bash
   git remote add upstream https://github.com/muhammad-fiaz/archive.zig.git
   ```

## Development Setup

### Building the Project

```bash
# Build the library
zig build

# Run tests
zig build test

# Run examples
zig build run
```

### Project Structure

```
archive.zig/
├── src/                    # Source code
│   ├── algorithms/         # Compression algorithm implementations
│   ├── archive.zig        # Main library interface
│   ├── config.zig         # Configuration system
│   ├── constants.zig      # Constants and limits
│   ├── errors.zig         # Error definitions
│   ├── stream.zig         # Streaming interfaces
│   └── utils.zig          # Utility functions
├── examples/              # Example programs
├── docs/                  # Documentation
├── .github/               # GitHub workflows
├── build.zig             # Build configuration
├── build.zig.zon         # Package configuration
└── README.md
```

## Contributing Guidelines

### Types of Contributions

We welcome various types of contributions:

- **Bug fixes**: Fix issues in existing code
- **New features**: Add new compression algorithms or functionality
- **Performance improvements**: Optimize existing implementations
- **Documentation**: Improve or add documentation
- **Tests**: Add or improve test coverage
- **Examples**: Create helpful examples

### Before You Start

1. **Check existing issues**: Look for related issues or discussions
2. **Create an issue**: For significant changes, create an issue first to discuss
3. **Keep changes focused**: One feature/fix per pull request
4. **Follow conventions**: Adhere to existing code style and patterns

## Pull Request Process

### 1. Prepare Your Changes

```bash
# Create a feature branch
git checkout -b feature/your-feature-name

# Make your changes
# ... edit files ...

# Test your changes
zig build test
zig build run
```

### 2. Commit Guidelines

Use clear, descriptive commit messages:

```bash
# Good commit messages
git commit -m "Add LZ4 streaming compression support"
git commit -m "Fix memory leak in ZSTD decompression"
git commit -m "Update documentation for new API methods"

# Follow conventional commits format
git commit -m "feat: add support for custom compression levels"
git commit -m "fix: resolve segfault in deflate algorithm"
git commit -m "docs: update installation instructions"
```

### 3. Submit Pull Request

1. Push your branch to your fork:
   ```bash
   git push origin feature/your-feature-name
   ```

2. Create a pull request on GitHub with:
   - Clear title and description
   - Reference to related issues
   - List of changes made
   - Testing information

### 4. Pull Request Template

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Performance improvement
- [ ] Documentation update
- [ ] Test improvement

## Related Issues
Fixes #123

## Changes Made
- Added new compression algorithm
- Updated documentation
- Added tests

## Testing
- [ ] All existing tests pass
- [ ] New tests added and pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
```

## Coding Standards

### Zig Style Guidelines

Follow Zig's official style guide and these project-specific conventions:

#### Naming Conventions

```zig
// Constants: SCREAMING_SNAKE_CASE
const MAX_BUFFER_SIZE = 1024 * 1024;

// Functions: camelCase
pub fn compressData(allocator: Allocator, data: []const u8) ![]u8 {
    // ...
}

// Variables: snake_case
const compressed_data = try compressData(allocator, input);

// Types: PascalCase
pub const CompressionConfig = struct {
    // ...
};

// Enums: PascalCase with snake_case values
pub const Algorithm = enum {
    gzip,
    zlib,
    deflate,
    zstd,
};
```

#### Code Organization

```zig
// 1. Imports
const std = @import("std");
const archive = @import("archive");

// 2. Constants
const BUFFER_SIZE = 64 * 1024;

// 3. Types
pub const MyStruct = struct {
    // ...
};

// 4. Functions
pub fn myFunction() void {
    // ...
}
```

#### Error Handling

```zig
// Use explicit error handling
const result = someFunction() catch |err| switch (err) {
    error.OutOfMemory => return error.OutOfMemory,
    error.InvalidData => {
        std.log.err("Invalid input data provided", .{});
        return error.InvalidData;
    },
    else => return err,
};

// Prefer error unions over optional types for error conditions
pub fn compress(data: []const u8) ![]u8 {
    // ...
}
```

#### Memory Management

```zig
// Always use explicit allocators
pub fn processData(allocator: Allocator, data: []const u8) ![]u8 {
    const buffer = try allocator.alloc(u8, data.len * 2);
    defer allocator.free(buffer);
    
    // ... process data ...
    
    return try allocator.dupe(u8, result);
}

// Document memory ownership
/// Caller owns returned memory and must free it
pub fn createBuffer(allocator: Allocator, size: usize) ![]u8 {
    return try allocator.alloc(u8, size);
}
```

### Documentation Standards

#### Function Documentation

```zig
/// Compresses data using the specified algorithm.
/// 
/// Parameters:
///   - allocator: Memory allocator for output buffer
///   - data: Input data to compress
///   - algorithm: Compression algorithm to use
/// 
/// Returns: Compressed data (caller owns memory)
/// 
/// Errors:
///   - OutOfMemory: Insufficient memory for compression
///   - InvalidData: Input data is invalid or corrupted
/// 
/// Example:
/// ```zig
/// const compressed = try compress(allocator, "Hello, World!", .gzip);
/// defer allocator.free(compressed);
/// ```
pub fn compress(allocator: Allocator, data: []const u8, algorithm: Algorithm) ![]u8 {
    // ...
}
```

#### Type Documentation

```zig
/// Configuration for compression operations.
/// 
/// Provides fine-grained control over compression parameters,
/// including algorithm selection, compression levels, and
/// performance tuning options.
pub const CompressionConfig = struct {
    /// Compression algorithm to use
    algorithm: Algorithm,
    
    /// Compression level (algorithm-specific)
    level: ?u8 = null,
    
    /// Buffer size for streaming operations
    buffer_size: usize = 64 * 1024,
};
```

## Testing

### Test Organization

```zig
// tests/test_compression.zig
const std = @import("std");
const testing = std.testing;
const archive = @import("archive");

test "basic compression and decompression" {
    const allocator = testing.allocator;
    const input = "Hello, Archive.zig!";
    
    const compressed = try archive.compress(allocator, input, .gzip);
    defer allocator.free(compressed);
    
    const decompressed = try archive.decompress(allocator, compressed, .gzip);
    defer allocator.free(decompressed);
    
    try testing.expectEqualStrings(input, decompressed);
}

test "error handling for invalid data" {
    const allocator = testing.allocator;
    const invalid_data = [_]u8{0xFF, 0xFF, 0xFF, 0xFF};
    
    const result = archive.decompress(allocator, &invalid_data, .gzip);
    try testing.expectError(error.InvalidData, result);
}
```

### Test Categories

1. **Unit Tests**: Test individual functions and methods
2. **Integration Tests**: Test algorithm combinations and workflows
3. **Performance Tests**: Benchmark compression ratios and speeds
4. **Error Tests**: Verify proper error handling
5. **Memory Tests**: Check for memory leaks and proper cleanup

### Running Tests

```bash
# Run all tests
zig build test

# Run specific test file
zig test src/algorithms/gzip.zig

# Run tests with memory leak detection
zig build test -Dtest-leak-detection=true
```

## Documentation

### Documentation Types

1. **API Documentation**: Function and type documentation in source code
2. **User Guides**: Step-by-step tutorials in `docs/guide/`
3. **Examples**: Practical examples in `docs/examples/`
4. **README**: Project overview and quick start

### Writing Documentation

- Use clear, concise language
- Include practical examples
- Keep documentation up-to-date with code changes
- Follow the existing documentation structure

### Building Documentation

```bash
# Install dependencies
cd docs
npm install

# Start development server
npm run docs:dev

# Build for production
npm run docs:build
```

## Issue Reporting

### Bug Reports

When reporting bugs, please include:

1. **Zig version**: Output of `zig version`
2. **Operating system**: OS and version
3. **Minimal reproduction**: Smallest code that reproduces the issue
4. **Expected behavior**: What should happen
5. **Actual behavior**: What actually happens
6. **Error messages**: Full error output if applicable

### Feature Requests

For feature requests, please include:

1. **Use case**: Why is this feature needed?
2. **Proposed solution**: How should it work?
3. **Alternatives**: Other ways to achieve the same goal
4. **Implementation ideas**: Technical approach (if known)

### Issue Template

```markdown
## Bug Report / Feature Request

### Description
Clear description of the issue or feature request.

### Environment
- Zig version: 
- OS: 
- Archive.zig version: 

### Reproduction Steps
1. Step one
2. Step two
3. Step three

### Expected Behavior
What should happen.

### Actual Behavior
What actually happens.

### Additional Context
Any other relevant information.
```

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: General questions and discussions
- **Pull Requests**: Code contributions and reviews

### Getting Help

1. **Check documentation**: Look at guides and API docs first
2. **Search issues**: See if your question has been asked before
3. **Create an issue**: Ask questions or report problems
4. **Be patient**: Maintainers are volunteers with limited time

### Recognition

Contributors are recognized in several ways:

- **Contributors list**: Added to README.md
- **Release notes**: Mentioned in changelog
- **GitHub insights**: Contribution graphs and statistics

## Development Workflow

### Typical Workflow

1. **Find or create an issue** to work on
2. **Fork and clone** the repository
3. **Create a feature branch** from main
4. **Make your changes** following coding standards
5. **Add tests** for new functionality
6. **Update documentation** as needed
7. **Test thoroughly** on your local machine
8. **Submit a pull request** with clear description
9. **Respond to feedback** during code review
10. **Celebrate** when your PR is merged! 🎉

### Staying Updated

```bash
# Sync with upstream regularly
git fetch upstream
git checkout main
git merge upstream/main
git push origin main
```

### Release Process

Releases follow semantic versioning (SemVer):

- **Major** (1.0.0): Breaking changes
- **Minor** (0.1.0): New features, backward compatible
- **Patch** (0.0.1): Bug fixes, backward compatible

## Advanced Contributing

### Adding New Algorithms

To add a new compression algorithm:

1. **Create algorithm file**: `src/algorithms/your_algorithm.zig`
2. **Implement interface**: Follow existing algorithm patterns
3. **Add to enum**: Update `Algorithm` enum in `src/archive.zig`
4. **Add constants**: Algorithm-specific constants in `src/constants.zig`
5. **Write tests**: Comprehensive test coverage
6. **Update documentation**: API docs and user guides
7. **Add examples**: Practical usage examples

### Performance Optimization

When optimizing performance:

1. **Profile first**: Use `zig build -Drelease-fast` and profiling tools
2. **Benchmark**: Create before/after performance comparisons
3. **Document changes**: Explain optimization techniques used
4. **Test thoroughly**: Ensure correctness is maintained

### Platform Support

For platform-specific contributions:

1. **Test on target platform**: Verify functionality works correctly
2. **Handle differences**: Use conditional compilation when needed
3. **Update CI**: Add platform to GitHub Actions if needed
4. **Document limitations**: Note any platform-specific behavior

## Questions?

If you have questions about contributing that aren't covered here:

1. **Check existing issues and discussions**
2. **Create a new discussion** on GitHub
3. **Reach out to maintainers** through GitHub

Thank you for contributing to Archive.zig! Your contributions help make compression accessible and efficient for the Zig community.

---

**Happy Coding!** 🚀

*This document is a living guide and may be updated as the project evolves.*