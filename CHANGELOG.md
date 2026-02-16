# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-02-16

### Added
- Offline-first mutation queue with `PendingMutation` model and replay support
- `SyncState` for tracking pending mutation count and sync status
- `OfflineStorage` abstract interface for pluggable storage backends
- `JsonFileStorage` with web-safe conditional imports (stub on web, `dart:io` on native)
- `InMemoryOfflineStorage` for web platform and testing
- View code generation support (server-side filtered queries via `ViewContext`)
- Example project with `README.md` and BSATN demo
- Full pub.dev metadata: topics, homepage, repository, issue tracker, documentation

### Changed
- Migrated from legacy `Subscribe` to modern `SubscribeMulti` protocol
- `SubscriptionManager` now uses multi-query subscription batching
- `ReducerCaller` extended with offline queue support (enqueue when disconnected)
- `SdkLogger` refactored: `enableDeveloperLog()`, custom `onLog` callback, level-based filtering
- `ClientGenerator` improved: better typed table accessors, view getter generation
- `SchemaExtractor` improved: robust column type mapping, nullable/optional handling
- `SpacetimeDbConnection` improved: cleaner reconnect lifecycle, status stream reliability
- `ReducerInfo` updated for SubscribeMulti message format compatibility

### Fixed
- Web platform crash when importing `dart:io` via `JsonFileStorage`
- Subscription deduplication on rapid subscribe/unsubscribe cycles

## [0.1.0] - 2025-02-13

### Added
- WebSocket connection with auto-reconnect and SSL/TLS support
- Connection status monitoring and quality metrics
- BSATN binary encoding/decoding (all SpacetimeDB types)
- Client-side table cache with real-time change streams
- Subscription management with SQL queries
- Type-safe reducer calling with transaction results
- Code generation from SpacetimeDB modules (tables, reducers, sum types, views)
- Authentication with Identity, token persistence, and OIDC support
- Offline-first support with optimistic updates and mutation queue
- Brotli compression for WebSocket messages
