import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;
import 'package:spacetimedb/src/codegen/models.dart';
import 'package:spacetimedb/src/utils/sdk_logger.dart';

/// Extracts database schema from various sources
///
/// Supports:
/// - Network: Fetch from running SpacetimeDB instance
/// - Local project: Build and extract from Rust module
/// - WASM binary: Extract from compiled module
class SchemaExtractor {
  /// Extract schema from a running SpacetimeDB instance (network)
  ///
  /// Uses `spacetime describe --json` to fetch schema.
  static Future<DatabaseSchema> fromNetwork({
    required String database,
    String? server,
  }) async {
    final args = ['describe', '--json', database];
    if (server != null) {
      args.addAll(['--server', server]);
    }

    final result = await Process.run('spacetime', args, runInShell: true);

    if (result.exitCode != 0) {
      throw Exception(
        'Failed to fetch schema: ${result.stderr}',
      );
    }

    // Filter out WARNING lines
    final output = result.stdout.toString();
    final jsonStr = output
        .split('\n')
        .where((line) => !line.startsWith('WARNING:'))
        .join('\n');

    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw StateError(
          'Expected JSON object from spacetime describe, got ${decoded.runtimeType}');
    }
    final json = decoded;

    return DatabaseSchema.fromJson(database, json);
  }

  /// Extract schema from a SpacetimeDB project directory
  ///
  /// This will:
  /// 1. Build the Rust module using `spacetime build`
  /// 2. Extract schema from the compiled WASM using `spacetimedb-standalone`
  /// 3. Parse the JSON schema
  ///
  /// Requires:
  /// - `spacetime` CLI installed
  /// - `spacetimedb-standalone` binary available
  static Future<DatabaseSchema> fromProject(String projectPath) async {
    SdkLogger.i('Building SpacetimeDB module at: $projectPath');

    // Build the module
    final buildResult = await Process.run(
      'spacetime',
      ['build', '-p', projectPath],
      runInShell: true,
    );

    if (buildResult.exitCode != 0) {
      throw Exception(
        'Failed to build module:\n${buildResult.stderr}',
      );
    }

    // Extract WASM path from build output
    final wasmPath = _parseWasmPath(buildResult.stdout.toString(), projectPath);
    SdkLogger.i('Module built: $wasmPath');

    // Extract schema from WASM
    return fromWasm(wasmPath);
  }

  /// Extract schema from a compiled WASM binary
  ///
  /// Uses `spacetimedb-standalone extract-schema` to read the schema
  /// embedded in the WASM module.
  static Future<DatabaseSchema> fromWasm(String wasmPath) async {
    SdkLogger.i('Extracting schema from WASM: $wasmPath');

    // Find spacetimedb-standalone binary
    final standalonePath = await _findStandaloneBinary();

    // Extract schema as JSON
    final result = await Process.run(
      standalonePath,
      ['extract-schema', wasmPath],
      runInShell: true,
    );

    if (result.exitCode != 0) {
      throw Exception(
        'Failed to extract schema:\n${result.stderr}',
      );
    }

    // Parse JSON schema
    final jsonString = result.stdout.toString();
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw StateError(
          'Expected JSON object from WASM schema extraction, got ${decoded.runtimeType}');
    }
    final json = decoded;

    // Extract database name from WASM filename or use placeholder
    final dbName = path.basenameWithoutExtension(wasmPath);

    // Unwrap version wrapper (e.g., {"V9": {...}}, {"V10": {...}})
    // SpacetimeDB wraps schemas in version envelopes like {"V9": schema}
    // We need to extract the actual schema from whatever version wrapper exists
    final schemaJson = _unwrapVersionEnvelope(json);

    return DatabaseSchema.fromJson(dbName, schemaJson);
  }

  /// Find the spacetimedb-standalone binary
  ///
  /// Looks in common installation locations:
  /// - Linux/macOS: `~/.local/share/spacetime/bin/current/spacetimedb-standalone`
  /// - Windows: `%LOCALAPPDATA%\spacetime\bin\current\spacetimedb-standalone.exe`
  /// - PATH (all platforms)
  static Future<String> _findStandaloneBinary() async {
    // Check platform-specific installation locations
    if (Platform.isWindows) {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      if (localAppData != null) {
        final standardPath = path.join(
          localAppData,
          'spacetime',
          'bin',
          'current',
          'spacetimedb-standalone.exe',
        );
        if (await File(standardPath).exists()) {
          return standardPath;
        }
      }
    } else {
      final home = Platform.environment['HOME'];
      if (home != null) {
        final standardPath = path.join(
          home,
          '.local',
          'share',
          'spacetime',
          'bin',
          'current',
          'spacetimedb-standalone',
        );
        if (await File(standardPath).exists()) {
          return standardPath;
        }
      }
    }

    // Try to find in PATH
    final whichCommand = Platform.isWindows ? 'where' : 'which';
    final whichResult = await Process.run(
      whichCommand,
      ['spacetimedb-standalone'],
      runInShell: true,
    );

    if (whichResult.exitCode == 0) {
      return whichResult.stdout.toString().trim().split('\n').first.trim();
    }

    throw Exception(
      'Could not find spacetimedb-standalone binary.\n'
      'Please ensure SpacetimeDB is installed: https://spacetimedb.com/install',
    );
  }

  /// Parse WASM path from `spacetime build` output
  ///
  /// The build output contains a line like:
  /// "Created module at: /path/to/module.wasm"
  static String _parseWasmPath(String buildOutput, String projectPath) {
    // Look for "Created module at:" or similar patterns
    final lines = buildOutput.split('\n');
    for (final line in lines) {
      if (line.contains('.wasm')) {
        // Extract path - handles various formats
        final match = RegExp(r'([^\s]+\.wasm)').firstMatch(line);
        if (match != null) {
          final wasmPath = match.group(1)!;
          // If relative path, resolve from project directory
          if (!path.isAbsolute(wasmPath)) {
            return path.join(projectPath, wasmPath);
          }
          return wasmPath;
        }
      }
    }

    // Fallback: check common build output locations
    final targetPath =
        path.join(projectPath, 'target', 'wasm32-unknown-unknown', 'release');
    final dir = Directory(targetPath);
    if (dir.existsSync()) {
      final wasmFiles =
          dir.listSync().where((f) => f.path.endsWith('.wasm')).toList();
      if (wasmFiles.isNotEmpty) {
        return wasmFiles.first.path;
      }
    }

    throw Exception(
      'Could not find compiled WASM file.\n'
      'Build output:\n$buildOutput',
    );
  }

  /// Unwrap version envelope from schema JSON
  ///
  /// SpacetimeDB wraps schemas in version envelopes like:
  /// {"V9": {...schema...}} or {"V10": {...schema...}}
  ///
  /// This method extracts the actual schema, supporting any version.
  static Map<String, dynamic> _unwrapVersionEnvelope(
      Map<String, dynamic> json) {
    // If there's only one top-level key starting with 'V' followed by digits,
    // assume it's a version wrapper and unwrap it
    if (json.length == 1) {
      final key = json.keys.first;
      if (RegExp(r'^V\d+$').hasMatch(key)) {
        final value = json[key];
        if (value is! Map<String, dynamic>) {
          throw StateError(
              'Expected version envelope to contain Map, got ${value.runtimeType}');
        }
        return value;
      }
    }

    return json;
  }
}
