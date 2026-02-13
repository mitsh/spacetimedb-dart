import 'dart:typed_data';

/// Decode gzip-compressed data.
///
/// SpacetimeDB currently uses brotli compression (tag=1) or none (tag=0).
/// Gzip (tag=2) is defined in the protocol but not used by current servers.
/// This stub exists for protocol completeness and avoids importing dart:io
/// which is not available on web.
List<int> decodeGzip(Uint8List data) {
  throw UnsupportedError(
    'Gzip decompression is not yet implemented. '
    'SpacetimeDB uses brotli compression by default.',
  );
}
