/// Platform-agnostic interface for storing authentication tokens.
///
/// Implementations can use any storage backend:
/// - Flutter: SharedPreferences, FlutterSecureStorage
/// - CLI: File system
/// - Server: Database, Redis
/// - Testing: In-memory
///
/// Example usage:
/// ```dart
/// class SecureTokenStore implements AuthTokenStore {
///   final _storage = const FlutterSecureStorage();
///   static const _key = 'spacetimedb_token';
///
///   @override
///   Future<String?> loadToken() async {
///     return await _storage.read(key: _key);
///   }
///
///   @override
///   Future<void> saveToken(String token) async {
///     await _storage.write(key: _key, value: token);
///   }
///
///   @override
///   Future<void> clearToken() async {
///     await _storage.delete(key: _key);
///   }
/// }
/// ```
abstract class AuthTokenStore {
  /// Load the stored authentication token, if any.
  ///
  /// Returns null if no token is stored or if loading fails.
  Future<String?> loadToken();

  /// Save an authentication token.
  ///
  /// This is called automatically when the server sends a new identity token.
  Future<void> saveToken(String token);

  /// Clear the stored token (e.g., on logout).
  Future<void> clearToken();
}
