# What is Archive.zig?

Archive.zig is a comprehensive, high-performance compression and archive library for the Zig programming language. It provides a unified interface for working with multiple compression algorithms and archive formats, making it easy to handle compressed data in your Zig applications.

## Key Features

### 🚀 High Performance
- Optimized implementations with minimal memory allocations
- Efficient streaming compression and decompression
- Zero-copy operations where possible
- Memory-efficient buffer management

### 🔧 Multiple Algorithms
Archive.zig supports 10 different compression algorithms:

- **gzip** - GNU zip format with CRC32 checksums
- **zlib** - Deflate compression with Adler32 checksums  
- **deflate** - Raw deflate compression (fastest)
- **zstd** - Modern Zstandard compression (excellent ratio/speed)
- **lz4** - Ultra-fast compression for real-time applications
- **lzma** - High compression ratio for archival
- **xz** - LZMA2-based compression
- **tar.gz** - TAR archives with gzip compression
- **zip** - Standard ZIP archive format
- **brotli** - Modern web compression with excellent ratio

### 🌊 Streaming Support
- Process large files without loading everything into memory
- Real-time compression and decompression
- Configurable buffer sizes for memory optimization
- Support for incremental processing

### 🎯 Simple API
- Clean, intuitive function interface
- Builder pattern for advanced configuration
- Automatic algorithm detection from file headers
- Comprehensive error handling

## Design Philosophy

Archive.zig is designed with several key principles:

**Performance First**: Every operation is optimized for speed and memory efficiency. The library uses minimal allocations and provides streaming interfaces for large data processing.

**Safety**: Built on Zig's memory safety guarantees, with comprehensive error handling and bounds checking.

**Flexibility**: Support for multiple algorithms with extensive configuration options, allowing you to choose the right tool for each use case.

**Simplicity**: Despite supporting many algorithms, the API remains clean and easy to use, with sensible defaults for common operations.

## Use Cases

Archive.zig is perfect for:

- **File Compression**: Compress files and directories with various algorithms
- **Data Archiving**: Create compressed archives for long-term storage
- **Network Protocols**: Compress data for network transmission
- **Database Storage**: Compress data before storing in databases
- **Log Processing**: Compress log files and rotate archives
- **Backup Systems**: Create compressed backups with integrity checking
- **Game Development**: Compress game assets and save files
- **Embedded Systems**: Efficient compression for resource-constrained environments

## Why Choose Archive.zig?

### Compared to C Libraries
- **Memory Safety**: No buffer overflows or memory leaks
- **Better Error Handling**: Comprehensive error types and handling
- **Zero Dependencies**: No need to link external C libraries
- **Cross-Platform**: Works consistently across all Zig-supported platforms

### Compared to Other Zig Libraries
- **Comprehensive**: Support for 10 different algorithms in one library
- **Mature**: Battle-tested implementations with extensive testing
- **Documented**: Complete documentation with examples
- **Maintained**: Active development and community support

## Getting Started

Ready to start using Archive.zig? Check out the [Installation](./installation.md) guide and [Getting Started](./getting-started.md) tutorial to begin compressing data in your Zig applications.