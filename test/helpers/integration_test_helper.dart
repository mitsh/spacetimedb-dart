import 'dart:io';
import '../test_setup.dart';

/// Helper for integration tests that require SpacetimeDB and generated code
///
/// Usage:
/// ```dart
/// import '../helpers/integration_test_helper.dart';
///
/// void main() {
///   setUpAll(ensureTestEnvironment);
///
///   test('my test', () {
///     // Your test code
///   });
/// }
/// ```
///
/// This ensures the test environment is ready with:
/// - SpacetimeDB running
/// - Test module published to 'notesdb'
/// - Generated code in test/generated/
Future<void> ensureTestEnvironment() async {
  await setupTestEnvironment();
}

/// Check if generated code exists and is recent
bool isGeneratedCodeFresh() {
  final generatedDir = Directory('test/generated');
  if (!generatedDir.existsSync()) return false;

  final files = generatedDir
      .listSync()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  if (files.isEmpty) return false;

  // Check if any generated file is older than 10 minutes
  final now = DateTime.now();
  for (final file in files) {
    final stat = (file as File).statSync();
    if (now.difference(stat.modified).inMinutes > 10) {
      return false;
    }
  }

  return true;
}
