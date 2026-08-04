# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 0.0.x   | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability in Archive.zig, please report it responsibly.

**Do not open a public GitHub issue for security vulnerabilities.**

Instead, please email the maintainer directly or use [GitHub's private vulnerability reporting](https://github.com/muhammad-fiaz/archive.zig/security/advisories/new).

### What to include

- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

### Response timeline

- **Acknowledgment**: within 48 hours
- **Assessment**: within 1 week
- **Fix or mitigation**: depending on severity, as soon as possible

## Security Considerations

Archive.zig is a compression library. Users should be aware of the following:

- **Decompression bombs**: Decompressing untrusted data can lead to memory exhaustion. Use buffer size limits when processing untrusted input.
- **Memory safety**: Archive.zig is written in Zig, which provides memory safety guarantees at compile time. However, incorrect usage of allocators or unsafe operations can still lead to issues.
- **Dependency security**: This project depends on [brotli.zig](https://github.com/muhammad-fiaz/brotli.zig) and [zstd.zig](https://github.com/muhammad-fiaz/zstd.zig). Dependencies are pinned to specific versions in `build.zig.zon`.
