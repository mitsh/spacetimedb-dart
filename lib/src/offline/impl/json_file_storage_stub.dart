import '../offline_storage.dart';
import '../pending_mutation.dart';

/// Stub implementation of [JsonFileStorage] for web platform.
///
/// File-based offline storage is not available on web.
/// Use [InMemoryOfflineStorage] instead.
class JsonFileStorage implements OfflineStorage {
  final String basePath;

  JsonFileStorage({required this.basePath});

  @override
  Future<void> initialize() async {
    throw UnsupportedError(
      'JsonFileStorage is not available on web. Use InMemoryOfflineStorage instead.',
    );
  }

  @override
  Future<void> dispose() async {}

  @override
  Future<void> saveTableSnapshot(
          String tableName, List<Map<String, dynamic>> rows) async =>
      throw UnsupportedError('JsonFileStorage is not available on web.');

  @override
  Future<List<Map<String, dynamic>>?> loadTableSnapshot(
          String tableName) async =>
      throw UnsupportedError('JsonFileStorage is not available on web.');

  @override
  Future<void> enqueueMutation(PendingMutation mutation) async =>
      throw UnsupportedError('JsonFileStorage is not available on web.');

  @override
  Future<List<PendingMutation>> getPendingMutations() async =>
      throw UnsupportedError('JsonFileStorage is not available on web.');

  @override
  Future<void> dequeueMutation(String requestId) async =>
      throw UnsupportedError('JsonFileStorage is not available on web.');

  @override
  Future<void> setLastSyncTime(String tableName, DateTime time) async =>
      throw UnsupportedError('JsonFileStorage is not available on web.');

  @override
  Future<DateTime?> getLastSyncTime(String tableName) async =>
      throw UnsupportedError('JsonFileStorage is not available on web.');

  @override
  Future<void> clearAll() async =>
      throw UnsupportedError('JsonFileStorage is not available on web.');

  @override
  Future<void> clearTableSnapshot(String tableName) async =>
      throw UnsupportedError('JsonFileStorage is not available on web.');

  @override
  Future<void> clearMutationQueue() async =>
      throw UnsupportedError('JsonFileStorage is not available on web.');
}
