# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
