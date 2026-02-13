import 'dart:io';
import 'dart:typed_data';

List<int> decodeGzip(Uint8List data) {
  return GZipCodec().decode(data);
}
