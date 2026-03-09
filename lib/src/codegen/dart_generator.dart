import 'package:spacetimedb/src/codegen/client_generator.dart';
import 'package:spacetimedb/src/codegen/reducer_generator.dart';
import 'package:spacetimedb/src/codegen/models.dart';
import 'package:spacetimedb/src/codegen/table_generator.dart';
import 'package:spacetimedb/src/codegen/view_generator.dart';
import 'package:spacetimedb/src/codegen/generators/sum_type_generator.dart';
import 'package:spacetimedb/src/utils/sdk_logger.dart';
import 'dart:io';

class DartGenerator {
  final DatabaseSchema schema;
  DartGenerator(this.schema);

  List<GeneratedFile> generateAll() {
    final files = <GeneratedFile>[];

    // Generate sum type enums
    for (final typeDef in schema.types) {
      final type = schema.typeSpace.types[typeDef.typeRef];

      if (type.isSum) {
        final generator = SumTypeGenerator(
          enumName: typeDef.name,
          sumType: type.sum!,
          typeSpace: schema.typeSpace,
          typeDefs: schema.types,
        );

        final fileName = _toSnakeCase(typeDef.name);
        files.add(
          GeneratedFile(
            filename: '$fileName.dart',
            content: generator.generate(),
          ),
        );
      }
    }

    for (final table in schema.tables) {
      final generator = TableGenerator(schema, table);
      files.add(
        GeneratedFile(
          filename: '${table.name}.dart',
          content: generator.generate(),
        ),
      );
    }

    // Generate files for view return types not backed by tables
    final generatedTypeRefs =
        schema.tables.map((t) => t.productTypeRef).toSet();
    final viewGenerator = ViewGenerator(schema);

    for (final view in schema.views) {
      final typeRef = viewGenerator.getViewTypeRef(view);
      if (typeRef == null) continue;
      if (generatedTypeRefs.contains(typeRef)) continue;
      if (typeRef < 0 || typeRef >= schema.typeSpace.types.length) continue;
      if (schema.typeSpace.types[typeRef].product == null) continue;

      generatedTypeRefs.add(typeRef);

      // Look up actual TypeDef name for proper file naming
      final typeDefForNaming = schema.types.firstWhere(
        (td) => td.typeRef == typeRef,
        orElse: () => TypeDef(scope: [], name: '', typeRef: -1, customOrdering: false),
      );
      final typeBaseName = typeDefForNaming.name.isNotEmpty
          ? _toSnakeCase(typeDefForNaming.name)
          : 'type$typeRef';

      final syntheticTable = TableSchema(
        name: typeBaseName,
        productTypeRef: typeRef,
        primaryKey: const [],
        indexes: const [],
        constraints: const [],
        sequences: const [],
        schedule: const {},
        tableType: const {},
        tableAccess: const {},
      );

      final generator = TableGenerator(schema, syntheticTable);
      files.add(
        GeneratedFile(
          filename: '$typeBaseName.dart',
          content: generator.generate(),
        ),
      );
    }

    if (schema.reducers.isNotEmpty) {
      final generator = ReducerGenerator(
        schema.reducers,
        typeSpace: schema.typeSpace,
        typeDefs: schema.types,
        tables: schema.tables,
      );
      files.add(
        GeneratedFile(filename: 'reducers.dart', content: generator.generate()),
      );

      // Generate reducer argument classes and decoders
      files.add(
        GeneratedFile(
          filename: 'reducer_args.dart',
          content: generator.generateArgDecoders(),
        ),
      );
    }

    final clientGenerator = ClientGenerator(schema);
    files.add(
      GeneratedFile(
        filename: 'client.dart',
        content: clientGenerator.generate(),
      ),
    );

    return files;
  }

  String _toSnakeCase(String input) {
    return input
        .replaceAllMapped(
          RegExp(r'[A-Z]'),
          (match) => '_${match.group(0)!.toLowerCase()}',
        )
        .replaceFirst(RegExp(r'^_'), '');
  }

  Future<void> writeToDirectory(String outputPath) async {
    final dir = Directory(outputPath);
    await dir.create(recursive: true);

    final files = generateAll();

    // Clean up stale .dart files before writing new ones
    for (final entity in dir.listSync()) {
      if (entity is File && entity.path.endsWith('.dart')) {
        entity.deleteSync();
      }
    }

    for (final file in files) {
      final path = '${dir.path}/${file.filename}';
      await File(path).writeAsString(file.content);
      SdkLogger.i('Generated $path');
    }
  }
}

class GeneratedFile {
  final String filename;
  final String content;

  GeneratedFile({required this.filename, required this.content});
}
