---
title: Constants API
---

# Constants API

The `constants.zig` module defines algorithm-specific constants, buffer sizes, magic bytes, and limits used throughout the library.

## TimeConstants

```zig
pub const TimeConstants = struct {
    pub const ns_per_us: u64 = 1_000;
    pub const ns_per_ms: u64 = 1_000_000;
    pub const ns_per_second: u64 = 1_000_000_000;
    pub const ms_per_second: u64 = 1000;
    pub const seconds_per_minute: u64 = 60;
    pub const seconds_per_hour: u64 = 3600;
    pub const seconds_per_day: u64 = 86400;
};
```

## SizeConstants

```zig
pub const SizeConstants = struct {
    pub const bytes_per_kb: u64 = 1024;
    pub const bytes_per_mb: u64 = 1024 * 1024;
    pub const bytes_per_gb: u64 = 1024 * 1024 * 1024;
    pub const bytes_per_tb: u64 = 1024 * 1024 * 1024 * 1024;
};
```

## BufferSizes

```zig
pub const BufferSizes = struct {
    pub const compression: usize = 64 * 1024;
    pub const decompression: usize = 64 * 1024;
    pub const streaming: usize = 32 * 1024;
    pub const tar_block: usize = 512;
    pub const flate_window: usize = 32768;
    pub const min_buffer: usize = 1024;
    pub const max_buffer: usize = 16 * 1024 * 1024;
    pub const default_read: usize = 128 * 1024;
    pub const default_write: usize = 128 * 1024;
    pub const zstd_in: usize = 128 * 1024;
    pub const zstd_out: usize = 128 * 1024;
    pub const lz4_block_max: usize = 4 * 1024 * 1024;
    pub const flate_min: usize = std.compress.flate.max_window_len;
};
```

## CompressionConstants

```zig
pub const CompressionConstants = struct {
    pub const window_fast: usize = 4096;
    pub const window_default: usize = 32768;
    pub const window_best: usize = 65536;
    pub const min_match: usize = 3;
    pub const max_match: usize = 258;
    pub const max_run_length: usize = 255;
    pub const hash_bits: u5 = 16;
    pub const hash_size: usize = 1 << 16;
    pub const memory_level_min: u8 = 1;
    pub const memory_level_max: u8 = 9;
    pub const memory_level_default: u8 = 8;
    pub const window_bits_min: u8 = 8;
    pub const window_bits_max: u8 = 15;
    pub const window_bits_default: u8 = 15;
};
```

## LzmaConstants

```zig
pub const LzmaConstants = struct {
    pub const properties_byte: u8 = 0x5D;
    pub const dict_size: u32 = 65536;
    pub const max_offset: usize = 65535;
    pub const min_match: usize = 2;
    pub const max_match: usize = 272;
    pub const chunk_size: usize = 32768;
};
```

## Lz4Constants

```zig
pub const Lz4Constants = struct {
    pub const min_match: usize = 4;
    pub const max_offset: usize = 65535;
    pub const hash_bits: u5 = 16;
    pub const hash_size: usize = 1 << 16;
    pub const min_level: c_int = 1;
    pub const max_level: c_int = 12;
    pub const default_level: c_int = 1;
    pub const acceleration_default: c_int = 1;
    pub const acceleration_max: c_int = 65537;
};
```

## ZstdConstants

```zig
pub const ZstdConstants = struct {
    pub const default_level: c_int = 3;
    pub const min_level: c_int = 1;
    pub const max_level: c_int = 22;
    pub const ultra_min_level: c_int = 20;
    pub const window_log_min: u8 = 10;
    pub const window_log_max: u8 = 31;
    pub const hash_log_min: u8 = 6;
    pub const hash_log_max: u8 = 26;
    pub const chain_log_min: u8 = 6;
    pub const chain_log_max: u8 = 28;
    pub const search_log_min: u8 = 1;
    pub const search_log_max: u8 = 26;
    pub const min_match_min: u8 = 3;
    pub const min_match_max: u8 = 7;
    pub const target_length_min: u32 = 0;
    pub const target_length_max: u32 = 999999999;
    pub const ldm_hash_log_min: u8 = 6;
    pub const ldm_hash_log_max: u8 = 26;
    pub const ldm_min_match_min: u8 = 4;
    pub const ldm_min_match_max: u8 = 4096;
    pub const ldm_bucket_size_log_min: u8 = 1;
    pub const ldm_bucket_size_log_max: u8 = 8;
    pub const overlap_log_min: u8 = 0;
    pub const overlap_log_max: u8 = 9;
    pub const job_size_min: usize = 32 * 1024;
    pub const job_size_max: usize = 512 * 1024 * 1024;
};
```

## Magic

```zig
pub const Magic = struct {
    pub const lgz: [3]u8 = .{ 'L', 'G', 'Z' };
    pub const xz: [6]u8 = .{ 0xFD, 0x37, 0x7A, 0x58, 0x5A, 0x00 };
    pub const xz_footer: [2]u8 = .{ 0x59, 0x5A };
    pub const gzip: [2]u8 = .{ 0x1F, 0x8B };
    pub const zlib: [2]u8 = .{ 0x78, 0x9C };
    pub const zip_local: u32 = 0x04034b50;
    pub const zip_central: u32 = 0x02014b50;
    pub const zip_end: u32 = 0x06054b50;
};
```

## Extensions

```zig
pub const Extensions = struct {
    pub const gzip: []const u8 = ".gz";
    pub const zstd: []const u8 = ".zst";
    pub const lzma: []const u8 = ".lzma";
    pub const lzma2: []const u8 = ".lzma2";
    pub const xz: []const u8 = ".xz";
    pub const tar_gz: []const u8 = ".tar.gz";
    pub const zip: []const u8 = ".zip";
    pub const lz4: []const u8 = ".lz4";
    pub const deflate: []const u8 = ".deflate";
    pub const zlib_ext: []const u8 = ".zlib";
    pub const brotli: []const u8 = ".br";
    pub const none: []const u8 = "";
};
```

## ZipConstants

```zig
pub const ZipConstants = struct {
    pub const version: u16 = 20;
    pub const method_store: u16 = 0;
    pub const method_deflate: u16 = 8;
    pub const local_header_size: usize = 30;
    pub const central_header_size: usize = 46;
    pub const end_record_size: usize = 22;
    pub const EOCD_SIZE_NOV: usize = 22;
    pub const CDHF_SIZE_NOV: usize = 46;
    pub const LFH_SIZE_NOV: usize = 30;
    pub const EOCD_SIGNATURE: u32 = 0x06054b50;
    pub const CDFH_SIGNATURE: u32 = 0x02014b50;
    pub const LFH_SIGNATURE: u32 = 0x04034b50;
    pub const SIGNATURE_LENGTH: usize = 4;
    pub const MAX_COMMENT_SIZE: usize = 65535;
};
```

## CompressionLimits

```zig
pub const CompressionLimits = struct {
    pub const max_input_size: usize = 1024 * 1024 * 1024;
    pub const max_compression_ratio: f64 = 10.0;
    pub const min_compression_benefit: f64 = 0.95;
    pub const default_buffer_size: usize = 64 * 1024;
    pub const max_dictionary_size: usize = 1024 * 1024;
    pub const max_threads: u32 = 128;
    pub const max_window_log: u8 = 31;
    pub const min_window_log: u8 = 10;
    pub const max_file_size: u64 = 1024 * 1024 * 1024 * 1024;
    pub const max_depth: u32 = 1000;
};
```

## ValidationConstants

```zig
pub const ValidationConstants = struct {
    pub const min_file_size: usize = 1;
    pub const max_filename_length: usize = 255;
    pub const max_path_length: usize = 4096;
    pub const checksum_size: usize = 4;
};
```

## Usage Examples

### Using Buffer Size Constants

```zig
const buf_size = archive.constants.BufferSizes.compression; // 64KB
```
