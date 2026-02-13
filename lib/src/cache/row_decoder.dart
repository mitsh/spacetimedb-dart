import '../codec/bsatn_decoder.dart';

abstract class RowDecoder<T> {
  T decode(BsatnDecoder decoder);

  dynamic getPrimaryKey(T row);

  Map<String, dynamic>? toJson(T row) => null;

  T? fromJson(Map<String, dynamic> json) => null;

  bool get supportsJsonSerialization => false;
}
