# spacetimedb

[![pub package](https://img.shields.io/pub/v/spacetimedb.svg)](https://pub.dev/packages/spacetimedb)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

> Dart SDK for SpacetimeDB. Real-time sync, BSATN codec, code generation, and offline-first support.

`spacetimedb` provides the runtime client, BSATN codec, and generator tooling needed to build type-safe Flutter/Dart apps on top of SpacetimeDB. It supports live table updates, reducer calls, authentication, and offline mutation replay.

## Features

- WebSocket connection with reconnect handling and TLS support
- BSATN binary encoding/decoding for SpacetimeDB data types
- Generated, type-safe APIs for tables, reducers, enums, and views
- Real-time table cache with insert/update/delete streams
- Subscription API for SQL-based live queries
- Authentication utilities with token persistence support
- Offline-first mutation queue with optimistic updates

## Installation

```yaml
dependencies:
  spacetimedb: ^0.1.0
```

Then install dependencies:

```bash
dart pub get
```

## Quick Start

Generate a typed client from your SpacetimeDB module:

```bash
dart run spacetimedb:generate -s http://localhost:3000 -d your_database -o lib/generated
```

Use the generated client in your app:

```dart
import 'package:spacetimedb/spacetimedb.dart';
import 'generated/client.dart';

final client = await SpacetimeDbClient.connect(
  host: 'localhost:3000',
  database: 'your_database',
  ssl: false,
  authStorage: InMemoryTokenStore(),
  initialSubscriptions: ['SELECT * FROM users'],
);
```

## Usage

### Connection

```dart
final client = await SpacetimeDbClient.connect(
  host: 'localhost:3000',
  database: 'your_database',
  ssl: false,
  authStorage: InMemoryTokenStore(),
);

client.connection.connectionStatus.listen((status) {
  print('Connection status: $status');
});
```

### Tables

```dart
for (final user in client.users.iter()) {
  print('User: ${user.name}');
}

client.users.insertStream.listen((user) {
  print('Inserted user: ${user.name}');
});
```

### Reducers

```dart
final result = await client.reducers.createUser(name: 'Alice');
if (result.isSuccess) {
  print('Reducer call succeeded');
}
```

### Subscriptions

```dart
await client.subscriptions.subscribe([
  'SELECT * FROM users WHERE active = true',
]);
```

### Authentication

```dart
final client = await SpacetimeDbClient.connect(
  host: 'spacetimedb.example.com',
  database: 'app_db',
  ssl: true,
  authStorage: InMemoryTokenStore(),
);

print(client.identity?.toHexString);
```

### Offline Support

```dart
final client = await SpacetimeDbClient.connect(
  host: 'localhost:3000',
  database: 'your_database',
  offlineStorage: JsonFileStorage(basePath: '/tmp/spacetimedb_cache'),
);

print('Pending mutations: ${client.syncState.pendingCount}');
```

## Code Generation

Use the bundled executable to generate strongly-typed Dart APIs:

```bash
dart run spacetimedb:generate -s http://localhost:3000 -d your_database -o lib/generated
```

You can also generate from a local module path:

```bash
dart run spacetimedb:generate -p path/to/spacetimedb-module -o lib/generated
```

## API Overview

| API | Purpose |
| --- | --- |
| `SpacetimeDbClient.connect(...)` | Connect to a SpacetimeDB database and initialize generated APIs |
| `client.<table>.iter()` | Read cached table rows with typed iteration |
| `client.<table>.insertStream` | Listen for real-time inserts |
| `client.reducers.<name>(...)` | Call reducers with typed parameters/results |
| `client.subscriptions.subscribe([...])` | Start additional live SQL subscriptions |
| `BsatnEncoder` / `BsatnDecoder` | Encode/decode BSATN payloads |
| `AuthTokenStore` | Plug in custom token persistence |
| `OfflineStorage` | Persist cached data and mutation queue for offline-first flows |

## Platform Support

| Platform | Runtime | Code Generation | Offline (File) |
| --- | --- | --- | --- |
| Android | Yes | Yes | Yes |
| iOS | Yes | Yes | Yes |
| macOS | Yes | Yes | Yes |
| Windows | Yes | Yes | Yes |
| Linux | Yes | Yes | Yes |
| Web | Yes | N/A | No* |

\* Web builds use `InMemoryOfflineStorage`. File-based `JsonFileStorage` requires `dart:io` and is not available on web. The SDK automatically provides a web-compatible stub that throws `UnsupportedError` if you try to use `JsonFileStorage` on web.

## Security Considerations

- **Offline storage is unencrypted.** Table snapshots and pending mutations are stored as plaintext JSON. Do not persist sensitive data (passwords, tokens, PII) without app-level encryption.
- **Use `ssl: true` in production.** Without SSL, authentication tokens are sent in plaintext over the network.
- **Web platform auth tokens** are passed as URL query parameters (WebSocket API limitation). These tokens are short-lived, but may appear in proxy logs. Always use SSL in production.
- **Token storage** is pluggable via `AuthTokenStore`. For production apps, implement a secure storage backend (e.g., `flutter_secure_storage`).

## Logging

By default, the SDK produces no log output. To enable logging:

```dart
// Option 1: Route to dart:developer (visible in DevTools)
SdkLogger.enableDeveloperLog();

// Option 2: Custom callback
SdkLogger.onLog = (level, message) {
  // 'D' = debug, 'I' = info, 'W' = warning, 'E' = error
  print('[$level] $message');
};
```

## License

Apache License 2.0. See [LICENSE](LICENSE).

---

## Attribution

This project was originally forked from [spacetimedb-dart-sdk](https://github.com/mikaelwills/spacetimedb-dart-sdk) by [Mikael Wills](https://github.com/mikaelwills). The original work provided the foundation for the WebSocket connection, BSATN codec, and initial code generation architecture.
