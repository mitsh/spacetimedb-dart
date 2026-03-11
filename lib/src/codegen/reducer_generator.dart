import 'package:spacetimedb/src/codegen/models.dart';
import 'package:spacetimedb/src/codegen/type_mapper.dart';

/// Generates reducer call methods and argument decoders
class ReducerGenerator {
  final List<ReducerSchema> reducers;
  final TypeSpace? typeSpace;
  final List<TypeDef>? typeDefs;
  final List<TableSchema>? tables;

  ReducerGenerator(this.reducers, {this.typeSpace, this.typeDefs, this.tables});

  /// Generate Reducers class with call methods and completion callbacks
  String generate() {
    final buf = StringBuffer();
    final hasScheduleAtParam = reducers.any(
      (reducer) => reducer.params.elements.any(
        (param) => TypeMapper.isScheduleAtType(
          param.algebraicType,
          typeSpace: typeSpace,
        ),
      ),
    );
    final hasUint8ListParam = reducers.any(
      (reducer) => reducer.params.elements.any((param) {
        final dartType = TypeMapper.toDartType(
          param.algebraicType,
          typeSpace: typeSpace,
          typeDefs: typeDefs,
        );
        return dartType.contains('Uint8List');
      }),
    );

    // Header
    buf.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buf.writeln();
    buf.writeln("import 'dart:async';");
    if (hasUint8ListParam) {
      buf.writeln("import 'dart:typed_data';");
    }
    buf.writeln(
      "import 'package:spacetimedb/spacetimedb.dart';",
    );
    for (final import in _collectReducerTypeImports()) {
      buf.writeln("import '$import';");
    }
    buf.writeln("import 'reducer_args.dart';");
    buf.writeln();

    if (hasScheduleAtParam) {
      buf.writeln('const int _scheduleAtTimeTag = 1;');
      buf.writeln();
      buf.writeln(
        'void _writeScheduleAt(BsatnEncoder encoder, dynamic value) {',
      );
      buf.writeln('  if (value is Map<String, dynamic>) {');
      buf.writeln("    final tag = value['tag'];");
      buf.writeln("    final microsValue = value['micros'] ?? value['value'];");
      buf.writeln('    if (tag is int && microsValue is Int64) {');
      buf.writeln('      encoder.writeU8(tag);');
      buf.writeln('      encoder.writeI64(microsValue);');
      buf.writeln('      return;');
      buf.writeln('    }');
      buf.writeln('    if (tag is int && microsValue is int) {');
      buf.writeln('      encoder.writeU8(tag);');
      buf.writeln('      encoder.writeI64(Int64(microsValue));');
      buf.writeln('      return;');
      buf.writeln('    }');
      buf.writeln('  }');
      buf.writeln('  if (value is Int64) {');
      buf.writeln('    encoder.writeU8(_scheduleAtTimeTag);');
      buf.writeln('    encoder.writeI64(value);');
      buf.writeln('    return;');
      buf.writeln('  }');
      buf.writeln('  if (value is int) {');
      buf.writeln('    encoder.writeU8(_scheduleAtTimeTag);');
      buf.writeln('    encoder.writeI64(Int64(value));');
      buf.writeln('    return;');
      buf.writeln('  }');
      buf.writeln(
        "  throw UnsupportedError('Unsupported ScheduleAt value: \$value');",
      );
      buf.writeln('}');
      buf.writeln();
    }

    // Class definition
    buf.writeln('/// Generated reducer methods with async/await support');
    buf.writeln('///');
    buf.writeln('/// All methods return Future<TransactionResult> containing:');
    buf.writeln('/// - status: Committed/Failed/OutOfEnergy');
    buf.writeln('/// - timestamp: When the reducer executed');
    buf.writeln(
      '/// - energyConsumed: Energy used (null for TransactionUpdateLight)',
    );
    buf.writeln(
      '/// - executionDuration: How long it took (null for TransactionUpdateLight)',
    );
    buf.writeln('class Reducers {');
    buf.writeln('  final ReducerCaller _reducerCaller;');
    buf.writeln('  final ReducerEmitter _reducerEmitter;');
    buf.writeln();
    buf.writeln('  Reducers(this._reducerCaller, this._reducerEmitter);');
    buf.writeln();

    // Generate call method for each reducer
    for (final reducer in reducers) {
      _generateReducerMethod(buf, reducer);
      buf.writeln();
    }

    // Generate completion callback for each reducer
    for (final reducer in reducers) {
      _generateCompletionCallback(buf, reducer);
      buf.writeln();
    }

    buf.writeln('}');

    return buf.toString();
  }

  /// Generate reducer argument classes and decoders
  ///
  /// This creates a separate file `reducer_args.dart` with:
  /// - Args classes (CreateNoteArgs, etc.)
  /// - Decoder classes (CreateNoteArgsDecoder, etc.)
  String generateArgDecoders() {
    final buf = StringBuffer();
    final hasScheduleAtParam = reducers.any(
      (reducer) => reducer.params.elements.any(
        (param) => TypeMapper.isScheduleAtType(
          param.algebraicType,
          typeSpace: typeSpace,
        ),
      ),
    );
    final hasUint8ListParam = reducers.any(
      (reducer) => reducer.params.elements.any((param) {
        final dartType = TypeMapper.toDartType(
          param.algebraicType,
          typeSpace: typeSpace,
          typeDefs: typeDefs,
        );
        return dartType.contains('Uint8List');
      }),
    );

    // Header
    buf.writeln(
      '// GENERATED REDUCER ARGUMENT CLASSES AND DECODERS - DO NOT MODIFY BY HAND',
    );
    buf.writeln();
    if (hasUint8ListParam) {
      buf.writeln("import 'dart:typed_data';");
    }
    buf.writeln(
      "import 'package:spacetimedb/spacetimedb.dart';",
    );
    for (final import in _collectReducerTypeImports()) {
      buf.writeln("import '$import';");
    }
    buf.writeln();

    if (hasScheduleAtParam) {
      buf.writeln('dynamic _readScheduleAt(BsatnDecoder decoder) {');
      buf.writeln('  final tag = decoder.readU8();');
      buf.writeln('  final micros = decoder.readI64();');
      buf.writeln("  return <String, dynamic>{'tag': tag, 'micros': micros};");
      buf.writeln('}');
      buf.writeln();
    }

    // Generate args class and decoder for each reducer
    for (final reducer in reducers) {
      _generateReducerArgsClass(buf, reducer);
      buf.writeln();
      _generateReducerDecoder(buf, reducer);
      buf.writeln();
    }

    return buf.toString();
  }

  void _generateReducerMethod(StringBuffer buf, ReducerSchema reducer) {
    final methodName = _toCamelCase(reducer.name);

    buf.writeln('  /// Call the ${reducer.name} reducer');
    buf.writeln('  ///');
    buf.writeln('  /// Returns [TransactionResult] with execution metadata:');
    buf.writeln('  /// - `result.isSuccess` - Check if reducer committed');
    buf.writeln(
      '  /// - `result.energyConsumed` - Energy used (null for lightweight responses)',
    );
    buf.writeln(
      '  /// - `result.executionDuration` - How long it took (null for lightweight responses)',
    );
    buf.writeln('  ///');
    buf.writeln(
      '  /// Pass [optimisticChanges] to immediately update the local cache for offline-first UX.',
    );
    buf.writeln('  /// Changes are rolled back if the server rejects them.');
    buf.writeln('  ///');
    buf.writeln(
      '  /// Throws [ReducerException] if the reducer fails or runs out of energy.',
    );
    buf.writeln(
      '  /// Throws [TimeoutException] if the reducer doesn\'t complete within the timeout.',
    );

    buf.write('  Future<TransactionResult> $methodName(');

    if (reducer.params.elements.isEmpty) {
      buf.writeln('{List<OptimisticChange>? optimisticChanges}) async {');
    } else {
      buf.writeln('{');
      for (final param in reducer.params.elements) {
        final paramName = _toCamelCase(param.name ?? 'unknown');
        final dartType = _getParamDartType(param.algebraicType);
        buf.writeln('    required $dartType $paramName,');
      }
      buf.writeln('    List<OptimisticChange>? optimisticChanges,');
      buf.writeln('  }) async {');
    }

    buf.writeln('    final encoder = BsatnEncoder();');
    for (final param in reducer.params.elements) {
      final paramName = _toCamelCase(param.name ?? 'unknown');
      buf.writeln(_getEncodeStatement(paramName, param.algebraicType));
    }
    buf.writeln();

    buf.writeln(
      "    return await _reducerCaller.call('${reducer.name}', encoder.toBytes(), optimisticChanges: optimisticChanges);",
    );
    buf.writeln('  }');
  }

  /// Generate completion callback method for a reducer
  ///
  /// Example generated code:
  /// ```dart
  /// StreamSubscription<void> onCreateNote(
  ///   void Function(EventContext ctx, String title, String content) callback
  /// ) {
  ///   return _reducerEmitter.on('create_note').listen((EventContext ctx) {
  ///     if (ctx.event is! ReducerEvent) return;
  ///     final event = ctx.event;
  ///     final args = event.reducerArgs;
  ///     if (args is! CreateNoteArgs) return;
  ///     callback(ctx, args.title, args.content);
  ///   });
  /// }
  /// ```
  void _generateCompletionCallback(StringBuffer buf, ReducerSchema reducer) {
    final methodName = 'on${_toPascalCase(reducer.name)}';
    final argsClassName = '${_toPascalCase(reducer.name)}Args';

    // Build callback signature
    buf.write('  StreamSubscription<void> $methodName(');
    buf.write('void Function(EventContext ctx');

    // Add typed parameters to callback
    for (final param in reducer.params.elements) {
      final paramName = _toCamelCase(param.name ?? 'unknown');
      final dartType = _getParamDartType(param.algebraicType);
      buf.write(', $dartType $paramName');
    }
    buf.writeln(') callback) {');

    // Implementation
    buf.writeln(
      "    return _reducerEmitter.on('${reducer.name}').listen((EventContext ctx) {",
    );
    buf.writeln('      // Pattern match to extract ReducerEvent');
    buf.writeln('      final event = ctx.event;');
    buf.writeln('      if (event is! ReducerEvent) return;');
    buf.writeln();
    buf.writeln('      // Type guard - ensures args is correct type');
    buf.writeln('      final args = event.reducerArgs;');
    buf.writeln('      if (args is! $argsClassName) return;');
    buf.writeln();
    buf.writeln(
      '      // Extract fields from strongly-typed object - NO CASTING',
    );
    buf.write('      callback(ctx');

    // Extract each arg field
    for (final param in reducer.params.elements) {
      final paramName = _toCamelCase(param.name ?? 'unknown');
      buf.write(', args.$paramName');
    }
    buf.writeln(');');
    buf.writeln('    });');
    buf.writeln('  }');
  }

  /// Generate the strongly-typed args class for a reducer
  void _generateReducerArgsClass(StringBuffer buf, ReducerSchema reducer) {
    final className = '${_toPascalCase(reducer.name)}Args';

    buf.writeln('/// Arguments for the ${reducer.name} reducer');
    buf.writeln('class $className {');

    // Generate fields
    for (final param in reducer.params.elements) {
      final paramName = _toCamelCase(param.name ?? 'unknown');
      final dartType = _getParamDartType(param.algebraicType);
      buf.writeln('  final $dartType $paramName;');
    }

    // Generate constructor
    if (reducer.params.elements.isEmpty) {
      // Empty constructor for reducers with no parameters
      buf.writeln('  $className();');
    } else {
      // Constructor with parameters
      buf.write('  $className({');
      for (final param in reducer.params.elements) {
        final paramName = _toCamelCase(param.name ?? 'unknown');
        buf.write('required this.$paramName, ');
      }
      buf.writeln('});');
    }

    buf.writeln('}');
  }

  /// Generate the decoder for a reducer's arguments
  void _generateReducerDecoder(StringBuffer buf, ReducerSchema reducer) {
    final argsClassName = '${_toPascalCase(reducer.name)}Args';
    final decoderClassName = '${_toPascalCase(reducer.name)}ArgsDecoder';

    buf.writeln('/// Decoder for ${reducer.name} reducer arguments');
    buf.writeln(
      'class $decoderClassName implements ReducerArgDecoder<$argsClassName> {',
    );
    buf.writeln('  @override');
    buf.writeln('  $argsClassName? decode(BsatnDecoder decoder) {');
    buf.writeln('    try {');

    // Decode each parameter
    for (final param in reducer.params.elements) {
      final paramName = _toCamelCase(param.name ?? 'unknown');
      _generateArgDecode(buf, paramName, param.algebraicType);
    }

    buf.writeln();
    buf.writeln('      return $argsClassName(');
    for (final param in reducer.params.elements) {
      final paramName = _toCamelCase(param.name ?? 'unknown');
      buf.writeln('        $paramName: $paramName,');
    }
    buf.writeln('      );');

    buf.writeln('    } catch (e) {');
    buf.writeln('      return null; // Deserialization failed');
    buf.writeln('    }');
    buf.writeln('  }');
    buf.writeln('}');
  }

  /// 🌟 GOLD STANDARD: Handle both primitive and complex types
  ///
  /// This is the critical branching logic that makes the SDK "first in class".
  /// It handles nested structs and enums inside reducer arguments.
  void _generateArgDecode(
    StringBuffer buf,
    String fieldName,
    Map<String, dynamic> algebraicType,
  ) {
    final expression = _getDecodeExpression(algebraicType);
    buf.writeln('      final $fieldName = $expression;');
  }

  /// Check if a type is a primitive (built-in BsatnDecoder method exists)
  bool _isPrimitive(Map<String, dynamic> algebraicType) {
    const primitiveKeys = [
      'U8',
      'U16',
      'U32',
      'U64',
      'I8',
      'I16',
      'I32',
      'I64',
      'F32',
      'F64',
      'Bool',
      'String',
    ];

    return primitiveKeys.any((key) => algebraicType.containsKey(key));
  }

  /// Get the Dart class name for a complex type
  String _getDartClassName(Map<String, dynamic> algebraicType) {
    return _getParamDartType(algebraicType);
  }

  String _getEncodeStatement(
    String valueName,
    Map<String, dynamic> algebraicType,
  ) {
    if (TypeMapper.isIdentityType(
      algebraicType,
      typeSpace: typeSpace,
      typeDefs: typeDefs,
    )) {
      return '    encoder.writeRawBytes(($valueName as Identity).bytes);';
    }

    final optionInnerType = TypeMapper.getOptionInnerType(
      algebraicType,
      typeSpace: typeSpace,
      typeDefs: typeDefs,
    );
    if (optionInnerType != null) {
      final innerDartType = TypeMapper.toDartType(
        optionInnerType,
        typeSpace: typeSpace,
        typeDefs: typeDefs,
      );
      final innerWrite = _getInlineWriteStatement('v', optionInnerType);
      return '    encoder.writeOption<$innerDartType>($valueName as $innerDartType?, (v) => $innerWrite);';
    }

    if (TypeMapper.isScheduleAtType(algebraicType, typeSpace: typeSpace)) {
      return '    _writeScheduleAt(encoder, $valueName);';
    }

    if (TypeMapper.isRefType(algebraicType)) {
      final tableClass = _getTableClassNameForRef(algebraicType);
      if (tableClass != null) {
        return '    ($valueName as $tableClass).encodeBsatn(encoder);';
      }
      return '    $valueName.encode(encoder);';
    }

    final encodeExpr = TypeMapper.getEncodeExpression(valueName, algebraicType, typeSpace: typeSpace, typeDefs: typeDefs);
    return '    $encodeExpr;';
  }

  String _getDecodeExpression(Map<String, dynamic> algebraicType) {
    if (TypeMapper.isIdentityType(
      algebraicType,
      typeSpace: typeSpace,
      typeDefs: typeDefs,
    )) {
      return 'Identity(decoder.readBytes(32))';
    }

    final optionInnerType = TypeMapper.getOptionInnerType(
      algebraicType,
      typeSpace: typeSpace,
      typeDefs: typeDefs,
    );
    if (optionInnerType != null) {
      final innerDartType = TypeMapper.toDartType(
        optionInnerType,
        typeSpace: typeSpace,
        typeDefs: typeDefs,
      );
      final innerDecode = _getInlineDecodeExpression(optionInnerType);
      return 'decoder.readOption<$innerDartType>(() => $innerDecode)';
    }

    if (TypeMapper.isScheduleAtType(algebraicType, typeSpace: typeSpace)) {
      return '_readScheduleAt(decoder)';
    }

    // Handle Array types
    if (algebraicType.containsKey('Array')) {
      final decodeExpr = TypeMapper.getDecodeExpression(algebraicType, typeSpace: typeSpace, typeDefs: typeDefs);
      return decodeExpr;
    }

    if (_isPrimitive(algebraicType)) {
      final method = TypeMapper.getDecoderMethod(algebraicType);
      return 'decoder.$method()';
    }

    final typeName = _getDartClassName(algebraicType);
    final tableClass = _getTableClassNameForRef(algebraicType);
    if (tableClass != null) {
      return '$tableClass.decodeBsatn(decoder)';
    }
    return '$typeName.decode(decoder)';
  }

  String _getInlineWriteStatement(
    String valueName,
    Map<String, dynamic> algebraicType,
  ) {
    if (TypeMapper.isIdentityType(
      algebraicType,
      typeSpace: typeSpace,
      typeDefs: typeDefs,
    )) {
      return 'encoder.writeRawBytes(($valueName as Identity).bytes)';
    }

    if (TypeMapper.isRefType(algebraicType)) {
      final tableClass = _getTableClassNameForRef(algebraicType);
      if (tableClass != null) {
        return '($valueName as $tableClass).encodeBsatn(encoder)';
      }
      return '$valueName.encode(encoder)';
    }

    final encodeExpr = TypeMapper.getEncodeExpression(valueName, algebraicType, typeSpace: typeSpace, typeDefs: typeDefs);
    return encodeExpr;
  }

  String _getInlineDecodeExpression(Map<String, dynamic> algebraicType) {
    if (TypeMapper.isIdentityType(
      algebraicType,
      typeSpace: typeSpace,
      typeDefs: typeDefs,
    )) {
      return 'Identity(decoder.readBytes(32))';
    }

    // Handle Array types
    if (algebraicType.containsKey('Array')) {
      final decodeExpr = TypeMapper.getDecodeExpression(algebraicType, typeSpace: typeSpace, typeDefs: typeDefs);
      return decodeExpr;
    }

    if (_isPrimitive(algebraicType)) {
      final method = TypeMapper.getDecoderMethod(algebraicType);
      return 'decoder.$method()';
    }

    final typeName = _getDartClassName(algebraicType);
    final tableClass = _getTableClassNameForRef(algebraicType);
    if (tableClass != null) {
      return '$tableClass.decodeBsatn(decoder)';
    }
    return '$typeName.decode(decoder)';
  }

  Set<String> _collectReducerTypeImports() {
    final imports = <String>{};
    for (final reducer in reducers) {
      for (final param in reducer.params.elements) {
        final importPath = _getImportForType(param.algebraicType);
        if (importPath != null) {
          imports.add(importPath);
        }

        final optionInnerType = TypeMapper.getOptionInnerType(
          param.algebraicType,
          typeSpace: typeSpace,
          typeDefs: typeDefs,
        );
        if (optionInnerType != null) {
          final optionImportPath = _getImportForType(optionInnerType);
          if (optionImportPath != null) {
            imports.add(optionImportPath);
          }
        }
      }
    }
    return imports;
  }

  String _getParamDartType(Map<String, dynamic> algebraicType) {
    final tableClass = _getTableClassNameForRef(algebraicType);
    if (tableClass != null) {
      return tableClass;
    }

    final optionInnerType = TypeMapper.getOptionInnerType(
      algebraicType,
      typeSpace: typeSpace,
      typeDefs: typeDefs,
    );
    if (optionInnerType != null) {
      final optionTableClass = _getTableClassNameForRef(optionInnerType);
      if (optionTableClass != null) {
        return '$optionTableClass?';
      }
    }

    return TypeMapper.toDartType(
      algebraicType,
      typeSpace: typeSpace,
      typeDefs: typeDefs,
    );
  }

  String? _getImportForType(Map<String, dynamic> algebraicType) {
    if (_getTableClassNameForRef(algebraicType) != null && tables != null) {
      final typeIndex = algebraicType['Ref'] as int;
      for (final table in tables!) {
        if (table.productTypeRef == typeIndex) {
          return '${table.name}.dart';
        }
      }
    }

    if (!TypeMapper.isRefType(algebraicType) || typeDefs == null) {
      return null;
    }

    final typeName = TypeMapper.getRefTypeName(algebraicType, typeDefs!);
    if (typeName == null || typeName == 'Identity') {
      return null;
    }

    return '${_toSnakeCase(typeName)}.dart';
  }

  String? _getTableClassNameForRef(Map<String, dynamic> algebraicType) {
    if (!TypeMapper.isRefType(algebraicType) || tables == null) {
      return null;
    }

    final typeIndex = algebraicType['Ref'] as int;
    for (final table in tables!) {
      if (table.productTypeRef == typeIndex) {
        return _toPascalCase(table.name);
      }
    }

    return null;
  }

  String _toCamelCase(String input) {
    final parts = input.split('_');
    if (parts.isEmpty) return input;

    return parts[0].toLowerCase() +
        parts.skip(1).map((word) {
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        }).join('');
  }

  String _toPascalCase(String input) {
    final parts = input.split('_');
    if (parts.isEmpty) return input;

    return parts.map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join('');
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }
}
