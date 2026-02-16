# SpacetimeDB Dart SDK — Example

## Prerequisites

1. A running SpacetimeDB instance (see [SpacetimeDB docs](https://spacetimedb.com/docs))
2. A published SpacetimeDB module (database)
3. The `spacetime` CLI installed

## Setup

### 1. Generate typed client

```bash
dart run spacetimedb:generate \
  -s http://localhost:3000 \
  -d your_database \
  -o lib/generated
```

### 2. Run the example

The `example.dart` file demonstrates basic connection, table iteration, and reducer calls. Update the host, database, and subscription queries to match your module.

```bash
dart run example/example.dart
```

## Notes

- This example uses `InMemoryTokenStore` for simplicity. For production apps, implement a persistent `AuthTokenStore`.
- The example requires a running SpacetimeDB instance. Without one, the connection will fail.
- For offline-first support, pass `offlineStorage: JsonFileStorage(basePath: '/tmp/cache')` to `connect()` (IO platforms only).
