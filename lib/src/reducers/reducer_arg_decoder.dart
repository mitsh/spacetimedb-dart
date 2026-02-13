import 'package:spacetimedb/src/codec/bsatn_decoder.dart';

/// Decodes BSATN-encoded reducer arguments into a strongly-typed args object
///
/// Each reducer gets a generated implementation that returns a specific args class.
/// This interface uses the generic type parameter T to preserve type information
/// through the deserialization process.
///
/// Example generated implementation:
/// ```dart
/// class CreateNoteArgs {
///   final String title;
///   final String content;
///   CreateNoteArgs({required this.title, required this.content});
/// }
///
/// class CreateNoteArgsDecoder implements ReducerArgDecoder<CreateNoteArgs> {
///   @override
///   CreateNoteArgs? decode(BsatnDecoder decoder) {
///     try {
///       final title = decoder.readString();
///       final content = decoder.readString();
///       return CreateNoteArgs(title: title, content: content);
///     } catch (e) {
///       return null; // Deserialization failed
///     }
///   }
/// }
/// ```
abstract class ReducerArgDecoder<T> {
  /// Deserialize BSATN bytes into a strongly-typed args object
  ///
  /// Returns null if deserialization fails (e.g., schema mismatch, corrupt data).
  /// The type parameter T ensures the returned object is correctly typed.
  T? decode(BsatnDecoder decoder);
}
