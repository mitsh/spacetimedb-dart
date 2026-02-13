export 'gzip_decoder_stub.dart'
    if (dart.library.io) 'gzip_decoder_io.dart'
    if (dart.library.html) 'gzip_decoder_web.dart';
