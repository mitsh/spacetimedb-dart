import 'models/type_models.dart';

class TypeMapper {
  // Type mappings
  static const _dartTypeMap = {
    'U8': 'int',
    'U16': 'int',
    'U32': 'int',
    'U64': 'Int64',
    'I8': 'int',
    'I16': 'int',
    'I32': 'int',
    'I64': 'Int64',
    'F32': 'double',
    'F64': 'double',
    'Bool': 'bool',
    'String': 'String',
    'Timestamp': 'Int64',
  };

  static const _encoderMethodMap = {
    'U8': 'writeU8',
    'U16': 'writeU16',
    'U32': 'writeU32',
    'U64': 'writeU64',
    'I8': 'writeI8',
    'I16': 'writeI16',
    'I32': 'writeI32',
    'I64': 'writeI64',
    'F32': 'writeF32',
    'F64': 'writeF64',
    'Bool': 'writeBool',
    'String': 'writeString',
    'Timestamp': 'writeU64',
  };

  static const _decoderMethodMap = {
    'U8': 'readU8',
    'U16': 'readU16',
    'U32': 'readU32',
    'U64': 'readU64',
    'I8': 'readI8',
    'I16': 'readI16',
    'I32': 'readI32',
    'I64': 'readI64',
    'F32': 'readF32',
    'F64': 'readF64',
    'Bool': 'readBool',
    'String': 'readString',
    'Timestamp': 'readU64',
  };

  /// Map algebraic type to Dart type string
  /// Pass typeSpace and typeDefs to resolve Ref types
  static String toDartType(
    Map<String, dynamic> algebraicType, {
    TypeSpace? typeSpace,
    List<TypeDef>? typeDefs,
  }) {
    final optionInnerType = getOptionInnerType(
      algebraicType,
      typeSpace: typeSpace,
      typeDefs: typeDefs,
    );
    if (optionInnerType != null) {
      final innerDartType = toDartType(
        optionInnerType,
        typeSpace: typeSpace,
        typeDefs: typeDefs,
      );
      return '$innerDartType?';
    }

    if (isIdentityType(
      algebraicType,
      typeSpace: typeSpace,
      typeDefs: typeDefs,
    )) {
      return 'Identity';
    }

    if (isScheduleAtType(algebraicType, typeSpace: typeSpace)) {
      return 'dynamic';
    }

    // 1. Handle Timestamp (Product with __timestamp_micros_since_unix_epoch__)
    if (algebraicType.containsKey('Product')) {
      final product = algebraicType['Product'];
      if (product is Map && product.containsKey('elements')) {
        final elements = product['elements'] as List;
        if (elements.length == 1) {
          final element = elements[0];
          if (element['name'] != null &&
              element['name']['some'] ==
                  '__timestamp_micros_since_unix_epoch__') {
            return 'Int64';
          }
        }
      }
    }

    if (algebraicType.containsKey('Ref')) {
      final typeIndex = algebraicType['Ref'] as int;

      if (typeSpace != null && typeDefs != null) {
        final typeDef = typeDefs.firstWhere(
          (td) => td.typeRef == typeIndex,
          orElse: () =>
              TypeDef(scope: [], name: '', typeRef: -1, customOrdering: false),
        );

        if (typeDef.name.isNotEmpty) {
          return _toPascalCase(typeDef.name);
        }
      }

      return 'dynamic';
    }

    // 2. Handle Array types (recursive)
    if (algebraicType.containsKey('Array')) {
      final elementType = algebraicType['Array'];
      if (elementType is Map && elementType.containsKey('U8')) {
        return 'Uint8List';
      }
      final dartInnerType = toDartType(
        (elementType as Map).cast<String, dynamic>(),
        typeSpace: typeSpace,
        typeDefs: typeDefs,
      );
      return 'List<$dartInnerType>';
    }

    // 3. Handle primitive types
    for (final key in _dartTypeMap.keys) {
      if (algebraicType.containsKey(key)) {
        return _dartTypeMap[key]!;
      }
    }

    return 'dynamic';
  }

  static String getEncoderMethod(Map<String, dynamic> algebraicType) {
    // Handle Timestamp
    if (algebraicType.containsKey('Product')) {
      final product = algebraicType['Product'];
      if (product is Map && product.containsKey('elements')) {
        final elements = product['elements'] as List;
        if (elements.length == 1) {
          final element = elements[0];
          if (element['name'] != null &&
              element['name']['some'] ==
                  '__timestamp_micros_since_unix_epoch__') {
            return 'writeI64';
          }
        }
      }
    }

    if (algebraicType.containsKey('Array')) {
      final elementType = algebraicType['Array'];
      if (elementType is Map && elementType.containsKey('U8')) {
        return 'writeBytes';
      }
      throw UnsupportedError(
          'No encoder method for array type: $algebraicType');
    }

    for (final key in _encoderMethodMap.keys) {
      if (algebraicType.containsKey(key)) {
        return _encoderMethodMap[key]!;
      }
    }

    throw UnsupportedError('No encoder method for type: $algebraicType');
  }

  static String getDecoderMethod(Map<String, dynamic> algebraicType) {
    // Handle Timestamp
    if (algebraicType.containsKey('Product')) {
      final product = algebraicType['Product'];
      if (product is Map && product.containsKey('elements')) {
        final elements = product['elements'] as List;
        if (elements.length == 1) {
          final element = elements[0];
          if (element['name'] != null &&
              element['name']['some'] ==
                  '__timestamp_micros_since_unix_epoch__') {
            return 'readI64';
          }
        }
      }
    }

    if (algebraicType.containsKey('Array')) {
      final elementType = algebraicType['Array'];
      if (elementType is Map && elementType.containsKey('U8')) {
        return 'readBytes';
      }
      throw UnsupportedError(
          'No decoder method for array type: $algebraicType');
    }

    for (final key in _decoderMethodMap.keys) {
      if (algebraicType.containsKey(key)) {
        return _decoderMethodMap[key]!;
      }
    }

    throw UnsupportedError('No decoder method for type: $algebraicType');
  }

  /// Get the full encode expression for a type, handling Array types.
  /// Returns e.g. 'encoder.writeU64(value)' or
  /// 'encoder.writeArray<Int64>(value, (item) => encoder.writeU64(item))'
  static String getEncodeExpression(
    String valueName,
    Map<String, dynamic> algebraicType, {
    TypeSpace? typeSpace,
    List<TypeDef>? typeDefs,
  }) {
    if (algebraicType.containsKey('Array')) {
      final elementType = algebraicType['Array'] as Map<String, dynamic>;
      if (elementType.containsKey('U8')) {
        return 'encoder.writeBytes($valueName)';
      }
      final innerDartType = toDartType(
        elementType,
        typeSpace: typeSpace,
        typeDefs: typeDefs,
      );
      final innerExpr = getEncodeExpression(
        'item',
        elementType,
        typeSpace: typeSpace,
        typeDefs: typeDefs,
      );
      return 'encoder.writeArray<$innerDartType>($valueName, (item) => $innerExpr)';
    }
    final method = getEncoderMethod(algebraicType);
    return 'encoder.$method($valueName)';
  }

  /// Get the full decode expression for a type, handling Array types.
  /// Returns e.g. 'decoder.readU64()' or
  /// 'decoder.readArray<Int64>(() => decoder.readU64())'
  static String getDecodeExpression(
    Map<String, dynamic> algebraicType, {
    TypeSpace? typeSpace,
    List<TypeDef>? typeDefs,
  }) {
    if (algebraicType.containsKey('Array')) {
      final elementType = algebraicType['Array'] as Map<String, dynamic>;
      if (elementType.containsKey('U8')) {
        return 'decoder.readBytes()';
      }
      final innerDartType = toDartType(
        elementType,
        typeSpace: typeSpace,
        typeDefs: typeDefs,
      );
      final innerExpr = getDecodeExpression(
        elementType,
        typeSpace: typeSpace,
        typeDefs: typeDefs,
      );
      return 'decoder.readArray<$innerDartType>(() => $innerExpr)';
    }
    final method = getDecoderMethod(algebraicType);
    return 'decoder.$method()';
  }

  static bool isIdentityType(
    Map<String, dynamic> algebraicType, {
    TypeSpace? typeSpace,
    List<TypeDef>? typeDefs,
  }) {
    if (_isIdentityProduct(algebraicType)) {
      return true;
    }

    if (algebraicType.containsKey('Ref') &&
        typeSpace != null &&
        typeDefs != null) {
      final typeIndex = algebraicType['Ref'] as int;
      final typeDef = typeDefs.firstWhere(
        (td) => td.typeRef == typeIndex,
        orElse: () =>
            TypeDef(scope: [], name: '', typeRef: -1, customOrdering: false),
      );

      if (typeDef.name.toLowerCase() == 'identity') {
        return true;
      }

      final resolved = _resolveRefType(algebraicType, typeSpace);
      if (resolved != null && _isIdentityProduct(resolved)) {
        return true;
      }
    }

    return false;
  }

  static Map<String, dynamic>? getOptionInnerType(
    Map<String, dynamic> algebraicType, {
    TypeSpace? typeSpace,
    List<TypeDef>? typeDefs,
  }) {
    final resolvedType = _resolveAlgebraicType(algebraicType, typeSpace);
    if (!resolvedType.containsKey('Sum')) {
      return null;
    }

    final sum = resolvedType['Sum'];
    if (sum is! Map<String, dynamic>) {
      return null;
    }

    final variants = sum['variants'];
    if (variants is! List || variants.length != 2) {
      return null;
    }

    final firstVariant = variants[0];
    final secondVariant = variants[1];
    if (firstVariant is! Map<String, dynamic> ||
        secondVariant is! Map<String, dynamic>) {
      return null;
    }

    final firstType = _resolveAlgebraicType(
      (firstVariant['algebraic_type'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
      typeSpace,
    );
    final secondType = _resolveAlgebraicType(
      (secondVariant['algebraic_type'] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{},
      typeSpace,
    );

    Map<String, dynamic> noneType;
    Map<String, dynamic> someType;
    if (_isUnitLike(firstType) && !_isUnitLike(secondType)) {
      noneType = firstType;
      someType = secondType;
    } else if (_isUnitLike(secondType) && !_isUnitLike(firstType)) {
      noneType = secondType;
      someType = firstType;
    } else {
      return null;
    }

    if (!_isUnitLike(noneType)) {
      return null;
    }

    if (someType.containsKey('Product')) {
      if (_isIdentityProduct(someType)) {
        return someType;
      }

      final product = someType['Product'];
      if (product is Map<String, dynamic>) {
        final elements = product['elements'];
        if (elements is List && elements.length == 1) {
          final element = elements[0];
          if (element is Map<String, dynamic>) {
            final inner = element['algebraic_type'];
            if (inner is Map<String, dynamic>) {
              return inner;
            }
          }
        }
      }
    }

    if (_isUnitLike(someType)) {
      return null;
    }

    return someType;
  }

  static bool isScheduleAtType(
    Map<String, dynamic> algebraicType, {
    TypeSpace? typeSpace,
  }) {
    final resolvedType = _resolveAlgebraicType(algebraicType, typeSpace);
    if (!resolvedType.containsKey('Sum')) {
      return false;
    }

    final sum = resolvedType['Sum'];
    if (sum is! Map<String, dynamic>) {
      return false;
    }

    final variants = sum['variants'];
    if (variants is! List || variants.length != 2) {
      return false;
    }

    for (final variant in variants) {
      if (variant is! Map<String, dynamic>) {
        return false;
      }

      final variantType = _resolveAlgebraicType(
        (variant['algebraic_type'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{},
        typeSpace,
      );

      if (!_isI64Payload(variantType)) {
        return false;
      }
    }

    return true;
  }

  /// Check if a type is a Ref (reference to another type)
  static bool isRefType(Map<String, dynamic> algebraicType) {
    return algebraicType.containsKey('Ref');
  }

  /// Get the type name for a Ref type
  static String? getRefTypeName(
    Map<String, dynamic> algebraicType,
    List<TypeDef> typeDefs,
  ) {
    if (!isRefType(algebraicType)) return null;

    final typeIndex = algebraicType['Ref'] as int;
    final typeDef = typeDefs.firstWhere(
      (td) => td.typeRef == typeIndex,
      orElse: () =>
          TypeDef(scope: [], name: '', typeRef: -1, customOrdering: false),
    );

    return typeDef.name.isNotEmpty ? typeDef.name : null;
  }

  static String _toPascalCase(String input) {
    if (input.isEmpty) return input;
    return input[0].toUpperCase() + input.substring(1);
  }

  static Map<String, dynamic> _resolveAlgebraicType(
    Map<String, dynamic> algebraicType,
    TypeSpace? typeSpace,
  ) {
    final resolvedRef = _resolveRefType(algebraicType, typeSpace);
    return resolvedRef ?? algebraicType;
  }

  static Map<String, dynamic>? _resolveRefType(
    Map<String, dynamic> algebraicType,
    TypeSpace? typeSpace,
  ) {
    if (typeSpace == null || !algebraicType.containsKey('Ref')) {
      return null;
    }

    final typeIndex = algebraicType['Ref'] as int;
    if (typeIndex < 0 || typeIndex >= typeSpace.types.length) {
      return null;
    }

    final resolved = typeSpace.types[typeIndex];
    if (resolved.product != null) {
      return <String, dynamic>{
        'Product': <String, dynamic>{
          'elements': resolved.product!.elements.map((element) {
            return <String, dynamic>{
              'name': <String, dynamic>{'some': element.name ?? ''},
              'algebraic_type': element.algebraicType,
            };
          }).toList(),
        },
      };
    }

    if (resolved.sum != null) {
      return <String, dynamic>{
        'Sum': <String, dynamic>{
          'variants': resolved.sum!.variants.map((variant) {
            return <String, dynamic>{
              'name': <String, dynamic>{'some': variant.name ?? ''},
              'algebraic_type': variant.algebraicTypeJson,
            };
          }).toList(),
        },
      };
    }

    return null;
  }

  static bool _isIdentityProduct(Map<String, dynamic> algebraicType) {
    if (!algebraicType.containsKey('Product')) {
      return false;
    }

    final product = algebraicType['Product'];
    if (product is! Map<String, dynamic>) {
      return false;
    }

    final elements = product['elements'];
    if (elements is! List || elements.length != 1) {
      return false;
    }

    final element = elements.first;
    if (element is! Map<String, dynamic>) {
      return false;
    }

    final nameObj = element['name'];
    if (nameObj is! Map<String, dynamic>) {
      return false;
    }

    final name = nameObj['some'];
    if (name == '__identity_bytes' || name == '__identity__') {
      return true;
    }

    final inner = element['algebraic_type'];
    return inner is Map<String, dynamic> && inner.containsKey('U256');
  }

  static bool _isUnitLike(Map<String, dynamic> algebraicType) {
    if (algebraicType.isEmpty) {
      return true;
    }

    if (!algebraicType.containsKey('Product')) {
      return false;
    }

    final product = algebraicType['Product'];
    if (product is! Map<String, dynamic>) {
      return false;
    }

    final elements = product['elements'];
    return elements is List && elements.isEmpty;
  }

  static bool _isI64Payload(Map<String, dynamic> algebraicType) {
    if (algebraicType.containsKey('I64') || algebraicType.containsKey('U64')) {
      return true;
    }

    if (_isTimestamp(algebraicType)) {
      return true;
    }

    if (algebraicType.containsKey('Product')) {
      final product = algebraicType['Product'];
      if (product is! Map<String, dynamic>) {
        return false;
      }

      final elements = product['elements'];
      if (elements is! List || elements.length != 1) {
        return false;
      }

      final first = elements.first;
      if (first is! Map<String, dynamic>) {
        return false;
      }

      final inner = first['algebraic_type'];
      if (inner is! Map<String, dynamic>) {
        return false;
      }

      return inner.containsKey('I64') ||
          inner.containsKey('U64') ||
          _isTimestamp(inner);
    }

    return false;
  }

  static bool _isTimestamp(Map<String, dynamic> algebraicType) {
    if (!algebraicType.containsKey('Product')) {
      return false;
    }

    final product = algebraicType['Product'];
    if (product is! Map<String, dynamic>) {
      return false;
    }

    final elements = product['elements'];
    if (elements is! List || elements.length != 1) {
      return false;
    }

    final element = elements.first;
    if (element is! Map<String, dynamic>) {
      return false;
    }

    final nameObj = element['name'];
    return nameObj is Map<String, dynamic> &&
        nameObj['some'] == '__timestamp_micros_since_unix_epoch__';
  }
}
