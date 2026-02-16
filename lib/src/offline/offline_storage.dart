import 'pending_mutation.dart';

/// Interface for persistent storage of table snapshots and pending mutations.
///
/// Implementations handle the physical storage of data for offline-first support.
/// The SDK includes two built-in implementations:
/// - [InMemoryOfflineStorage] — volatile storage for testing or web
/// - `JsonFileStorage` — file-based storage for mobile/desktop (IO platforms only)
///
/// ## Security Note
///
/// Data is stored **unencrypted** in plaintext. Do not persist sensitive
/// information (passwords, tokens, PII) without app-level encryption.
/// Consider using platform secure storage for sensitive fields.
abstract class OfflineStorage {
  /// Initialize storage backend. Must be called before other operations.
  Future<void> initialize();

  /// Release resources. Waits for pending operations to complete.
  Future<void> dispose();

  /// Persist a snapshot of all rows for [tableName].
  Future<void> saveTableSnapshot(
    String tableName,
    List<Map<String, dynamic>> rows,
  );

  /// Load previously saved snapshot for [tableName]. Returns null if none exists.
  Future<List<Map<String, dynamic>>?> loadTableSnapshot(String tableName);

  /// Add a pending mutation to the offline queue.
  Future<void> enqueueMutation(PendingMutation mutation);

  /// Retrieve all pending mutations awaiting sync.
  Future<List<PendingMutation>> getPendingMutations();

  /// Remove a mutation from the queue after successful sync.
  Future<void> dequeueMutation(String requestId);

  /// Record the last successful sync timestamp for [tableName].
  Future<void> setLastSyncTime(String tableName, DateTime time);

  /// Get the last successful sync timestamp for [tableName].
  Future<DateTime?> getLastSyncTime(String tableName);

  /// Remove all persisted data (snapshots, mutations, sync times).
  Future<void> clearAll();

  /// Remove saved snapshot for [tableName].
  Future<void> clearTableSnapshot(String tableName);

  /// Remove all pending mutations from the queue.
  Future<void> clearMutationQueue();
}

/// In-memory implementation of [OfflineStorage] for testing and web platform.
///
/// All data is lost when the process exits. Suitable for:
/// - Unit testing
/// - Web platform (where file I/O is unavailable)
/// - Scenarios where persistence is not required
class InMemoryOfflineStorage implements OfflineStorage {
  final Map<String, List<Map<String, dynamic>>> _snapshots = {};
  final List<PendingMutation> _mutations = [];
  final Map<String, DateTime> _syncTimes = {};

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<void> saveTableSnapshot(
    String tableName,
    List<Map<String, dynamic>> rows,
  ) async {
    _snapshots[tableName] = List.from(rows);
  }

  @override
  Future<List<Map<String, dynamic>>?> loadTableSnapshot(
    String tableName,
  ) async {
    final snapshot = _snapshots[tableName];
    return snapshot != null ? List.from(snapshot) : null;
  }

  @override
  Future<void> enqueueMutation(PendingMutation mutation) async {
    _mutations.add(mutation);
  }

  @override
  Future<List<PendingMutation>> getPendingMutations() async {
    return List.from(_mutations);
  }

  @override
  Future<void> dequeueMutation(String requestId) async {
    _mutations.removeWhere((m) => m.requestId == requestId);
  }

  @override
  Future<void> setLastSyncTime(String tableName, DateTime time) async {
    _syncTimes[tableName] = time;
  }

  @override
  Future<DateTime?> getLastSyncTime(String tableName) async {
    return _syncTimes[tableName];
  }

  @override
  Future<void> clearAll() async {
    _snapshots.clear();
    _mutations.clear();
    _syncTimes.clear();
  }

  @override
  Future<void> clearTableSnapshot(String tableName) async {
    _snapshots.remove(tableName);
  }

  @override
  Future<void> clearMutationQueue() async {
    _mutations.clear();
  }
}
