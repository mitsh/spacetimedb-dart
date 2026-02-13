import 'dart:typed_data';
import 'package:spacetimedb/src/codec/bsatn_decoder.dart';
import 'package:spacetimedb/src/reducers/reducer_arg_decoder.dart';

/// Registry for reducer argument decoders
///
/// Mirrors the ClientCache pattern for tables, but for reducers.
/// Each reducer has a decoder that knows how to deserialize its arguments
/// into strongly-typed args objects.
///
/// Usage:
/// ```dart
/// final registry = ReducerRegistry();
///
/// // Register decoders for each reducer (done in generated code)
/// registry.registerDecoder('create_note', CreateNoteArgsDecoder());
/// registry.registerDecoder('update_note', UpdateNoteArgsDecoder());
///
/// // Deserialize arguments from TransactionUpdate message
/// final args = registry.deserializeArgs('create_note', rawBytes);
/// if (args is CreateNoteArgs) {
///   print('Title: ${args.title}');
/// }
/// ```
class ReducerRegistry {
  // Store decoders with type erasure, but they return strongly-typed objects
  final Map<String, ReducerArgDecoder> _decoders = {};

  /// Register a decoder for a reducer's arguments
  ///
  /// Called during client initialization with generated decoders.
  ///
  /// Throws [ArgumentError] if a decoder for this reducer is already registered.
  ///
  /// Example:
  /// ```dart
  /// registry.registerDecoder('create_note', CreateNoteArgsDecoder());
  /// ```
  void registerDecoder(String reducerName, ReducerArgDecoder decoder) {
    if (_decoders.containsKey(reducerName)) {
      throw ArgumentError(
        'Decoder for reducer "$reducerName" is already registered',
      );
    }
    _decoders[reducerName] = decoder;
  }

  /// Deserialize reducer arguments from BSATN bytes into strongly-typed args object
  ///
  /// Returns null if:
  /// - Reducer is not registered (unknown reducer - server might have reducers we don't know about)
  /// - Deserialization fails (schema mismatch, corrupt data)
  ///
  /// The returned object is strongly-typed (e.g., CreateNoteArgs, UpdateNoteArgs)
  /// but stored as dynamic due to type erasure in the map. The generator knows
  /// the concrete type when creating listeners.
  ///
  /// Example:
  /// ```dart
  /// final args = registry.deserializeArgs('create_note', rawBytes);
  /// // args is a CreateNoteArgs object, but type is dynamic here
  /// // Type guards will be used in generated code to ensure type safety
  /// ```
  dynamic deserializeArgs(String reducerName, Uint8List bytes) {
    final decoder = _decoders[reducerName];
    if (decoder == null) {
      // Unknown reducer - server might have reducers we don't know about
      // This is fine, we just can't deserialize the arguments
      return null;
    }

    return decoder.decode(BsatnDecoder(bytes));
  }

  /// Check if a reducer decoder is registered
  bool hasDecoder(String reducerName) => _decoders.containsKey(reducerName);

  /// Get list of all registered reducer names (for debugging)
  List<String> get registeredReducers => _decoders.keys.toList();

  /// Get the number of registered reducers
  int get count => _decoders.length;
}
