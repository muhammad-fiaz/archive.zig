const std = @import("std");

/// Unified error set covering all compression backends.
///
/// Every error represents a distinct failure mode that consumers of the
/// archive library may encounter. Backend-specific errors are mapped into
/// this set by the respective algorithm modules.
pub const CompressError = error{
    UnsupportedAlgorithm,
    UnsupportedAlgorithmForDirectory,
    InvalidData,
    CorruptedStream,
    OutOfMemory,
    InternalFailure,
    ChecksumMismatch,
    OutputTooLarge,
    InvalidMagic,
    InvalidOffset,
    InvalidZipArchive,
    UnsupportedZipCompressionMethod,
    InvalidTarArchive,
    InvalidLzmaHeader,
    UnsupportedLzma2Chunk,
    ZstdError,
    FileNotFound,
    PermissionDenied,
    ExcludedByPattern,
    EmptyInput,
    ReadFailed,
    WriteFailed,
    EndOfStream,
};

pub fn formatError(err: CompressError) []const u8 {
    return switch (err) {
        error.UnsupportedAlgorithm => "Unsupported compression algorithm",
        error.UnsupportedAlgorithmForDirectory => "Algorithm does not support directory compression",
        error.InvalidData => "Invalid or corrupted data",
        error.CorruptedStream => "Corrupted data stream",
        error.OutOfMemory => "Out of memory",
        error.InternalFailure => "Internal compression failure",
        error.ChecksumMismatch => "Checksum verification failed",
        error.OutputTooLarge => "Output size exceeds limit",
        error.InvalidMagic => "Invalid file magic number",
        error.InvalidOffset => "Invalid back-reference offset",
        error.InvalidZipArchive => "Invalid ZIP archive format",
        error.UnsupportedZipCompressionMethod => "Unsupported ZIP compression method",
        error.InvalidTarArchive => "Invalid TAR archive format",
        error.InvalidLzmaHeader => "Invalid LZMA header",
        error.UnsupportedLzma2Chunk => "Unsupported LZMA2 chunk type",
        error.ZstdError => "Zstandard compression error",
        error.FileNotFound => "File not found",
        error.PermissionDenied => "Permission denied",
        error.ExcludedByPattern => "Excluded by pattern",
        error.EmptyInput => "Empty input data",
        error.ReadFailed => "Read operation failed",
        error.WriteFailed => "Write operation failed",
        error.EndOfStream => "Unexpected end of stream",
    };
}

test "error formatting" {
    const testing = std.testing;
    const msg = formatError(error.InvalidData);
    try testing.expect(msg.len > 0);
}
