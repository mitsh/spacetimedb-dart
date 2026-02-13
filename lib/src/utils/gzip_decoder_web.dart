import 'dart:typed_data';

List<int> decodeGzip(Uint8List data) {
  throw UnsupportedError(
    'Gzip decompression is not available on web. '
    'SpacetimeDB uses brotli compression by default.',
  );
}
