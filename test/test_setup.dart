// ignore_for_file: avoid_print
import 'dart:io';

const _testServerUrl = 'http://localhost:3000';

Future<bool> _isServerReachable() async {
  try {
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 2);
    final request = await client.getUrl(Uri.parse('$_testServerUrl/database'));
    final response = await request.close();
    client.close();
    return response.statusCode < 500;
  } catch (e) {
    return false;
  }
}

/// Global test setup that runs once before all tests
///
/// This ensures SpacetimeDB is running and the test module is published.
/// Call this from dart_test.yaml's setupAll hook.
Future<void> setupTestEnvironment() async {
  final marker = File('.test_setup_done');

  // First, check if server is already reachable (fast path)
  if (await _isServerReachable()) {
    print('✅ SpacetimeDB server is reachable at $_testServerUrl');

    // Check marker for full setup (build/publish/generate)
    if (await marker.exists()) {
      final timestamp = await marker.readAsString();
      final setupTime = DateTime.parse(timestamp);
      if (DateTime.now().difference(setupTime).inMinutes < 5) {
        print('✅ Test environment already set up ($setupTime)');
        return;
      }
    }
  } else {
    print('⚠️ SpacetimeDB server not reachable at $_testServerUrl');

    // Check if spacetime CLI is installed
    try {
      final result = await Process.run('spacetime', ['--version']);
      if (result.exitCode != 0) throw Exception('CLI check failed');
    } catch (e) {
      throw Exception(
        'SpacetimeDB CLI not found. Install from https://spacetimedb.com/install'
      );
    }

    // Try to start the server
    print('Starting SpacetimeDB server...');
    Process.start('spacetime', ['start'], mode: ProcessStartMode.detached);

    // Wait for server to become reachable
    for (var i = 0; i < 10; i++) {
      await Future.delayed(const Duration(seconds: 1));
      if (await _isServerReachable()) {
        print('✅ SpacetimeDB server started');
        break;
      }
      if (i == 9) {
        throw Exception(
          'SpacetimeDB server failed to start. Run "spacetime start" manually.'
        );
      }
    }
  }

  print('🚀 Setting up SpacetimeDB test environment...');

  // Login to local server (required for publish and schema fetch)
  print('Logging into local server...');
  final loginResult = await Process.run(
    'spacetime',
    ['login', '--server-issued-login', 'http://localhost:3000'],
  );
  if (loginResult.exitCode != 0) {
    print('Warning: Login failed: ${loginResult.stderr}');
  }

  // Build and publish test module
  final testModuleDir = Directory('spacetime_test_module');
  if (!await testModuleDir.exists()) {
    throw Exception('Test module directory not found: ${testModuleDir.path}');
  }

  // Build
  print('Building test module...');
  final buildResult = await Process.run(
    'spacetime',
    ['build'],
    workingDirectory: testModuleDir.path,
  );
  if (buildResult.exitCode != 0) {
    throw Exception('Build failed: ${buildResult.stderr}');
  }

  // Publish (use --clear-database to reset if it exists)
  print('Publishing test module...');
  final publishResult = await Process.run(
    'spacetime',
    ['publish', '--clear-database', 'notesdb'],
    workingDirectory: testModuleDir.path,
  );
  if (publishResult.exitCode != 0) {
    print('Publish stdout: ${publishResult.stdout}');
    print('Publish stderr: ${publishResult.stderr}');
    throw Exception('Publish failed: ${publishResult.stderr}');
  }
  print('✅ Published notesdb');

  // Generate test code from local project (no network auth needed)
  print('Generating test code from local project...');
  final generateResult = await Process.run(
    'dart',
    ['run', 'spacetimedb:generate', '--project-path', 'spacetime_test_module', '--output', 'test/generated'],
  );
  if (generateResult.exitCode != 0) {
    print('Generate stdout: ${generateResult.stdout}');
    print('Generate stderr: ${generateResult.stderr}');
    throw Exception('Code generation failed: ${generateResult.stderr}');
  }
  print('✅ Generated test code in test/generated/');

  // Mark setup as done
  await marker.writeAsString(DateTime.now().toIso8601String());

  print('✅ Test environment ready\n');
}
