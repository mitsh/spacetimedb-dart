import 'pending_mutation.dart';

abstract class OfflineStorage {
  Future<void> initialize();

  Future<void> dispose();

  Future<void> saveTableSnapshot(
    String tableName,
    List<Map<String, dynamic>> rows,
  );

  Future<List<Map<String, dynamic>>?> loadTableSnapshot(String tableName);

  Future<void> enqueueMutation(PendingMutation mutation);

  Future<List<PendingMutation>> getPendingMutations();

  Future<void> dequeueMutation(String requestId);

  Future<void> setLastSyncTime(String tableName, DateTime time);

  Future<DateTime?> getLastSyncTime(String tableName);

  Future<void> clearAll();

  Future<void> clearTableSnapshot(String tableName);

  Future<void> clearMutationQueue();
}

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
