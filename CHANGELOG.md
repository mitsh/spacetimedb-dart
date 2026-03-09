# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.0] - 2026-03-09

### Fixed
- **Code generator**: View-only types now use their actual TypeDef name (e.g. `ActiveGamePlayer`, `RecentMatchDisplay`) instead of opaque `Type1`, `Type26` identifiers
- **Code generator**: Synthetic table files for view row types use proper snake_case naming derived from TypeDef names
- **Code generator**: Client imports for view row types resolve to correct file names (e.g. `recent_match_display.dart`)
- **Code generator**: Stale `.dart` files in output directory are cleaned up before writing new ones, preventing orphaned type files from previous generations
## [1.2.0] - 2026-02-26

### Changed
- **Stable release for SpacetimeDB v2** — version bump from 0.1.x to 1.2.0 to signal production-ready v2 compatibility
- README comprehensively rewritten: compatibility matrix, architecture diagram, full API reference, security considerations, logging guide
- Updated `uuid` dependency to ^4.5.3

### Fixed
- All 8 `StreamController.broadcast()` in `TableCache` now use `sync: true` to prevent event delivery race condition where async microtask scheduling allowed reducer Future completions to cancel subscriptions before listeners received events

## [0.1.2] - 2026-02-19

### Fixed
- Sync broadcast controllers in TableCache (backported to 0.1.x)
- Debug logging for update stream delivery

### Changed
- README updated to document SpacetimeDB v2 compatibility

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
