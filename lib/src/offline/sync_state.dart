/// Current status of the offline synchronization process.
enum SyncStatus {
  /// No synchronization is currently in progress.
  idle,

  /// Actively sending pending mutations to the server.
  syncing,

  /// The last synchronization attempt failed.
  error,
}

/// Result of a single mutation synchronization attempt.
class MutationSyncResult {
  /// Unique identifier for the mutation request.
  final String requestId;

  /// Name of the reducer that was called.
  final String reducerName;

  /// Whether the mutation was successfully applied on the server.
  final bool success;

  /// Error message if the mutation failed.
  final String? error;

  const MutationSyncResult({
    required this.requestId,
    required this.reducerName,
    required this.success,
    this.error,
  });

  @override
  String toString() {
    return 'MutationSyncResult(requestId: $requestId, reducer: $reducerName, success: $success)';
  }
}

/// Represents the overall state of the offline synchronization system.
class SyncState {
  /// Current status of the sync process.
  final SyncStatus status;

  /// Number of mutations currently waiting to be synchronized.
  final int pendingCount;

  /// Error message from the last failed sync attempt, if any.
  final String? lastError;

  /// Timestamp of the last successful synchronization.
  final DateTime? lastSyncTime;

  const SyncState({
    this.status = SyncStatus.idle,
    this.pendingCount = 0,
    this.lastError,
    this.lastSyncTime,
  });

  /// Whether there are any mutations waiting to be synced.
  bool get hasPending => pendingCount > 0;

  /// Whether a sync process is currently active.
  bool get isSyncing => status == SyncStatus.syncing;

  /// Whether the sync system is currently idle.
  bool get isIdle => status == SyncStatus.idle;

  /// Whether the last sync attempt resulted in an error.
  bool get hasError => status == SyncStatus.error;

  /// Creates a copy of this state with the given fields replaced.
  SyncState copyWith({
    SyncStatus? status,
    int? pendingCount,
    String? lastError,
    DateTime? lastSyncTime,
  }) {
    return SyncState(
      status: status ?? this.status,
      pendingCount: pendingCount ?? this.pendingCount,
      lastError: lastError ?? this.lastError,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  @override
  String toString() {
    return 'SyncState(status: $status, pending: $pendingCount)';
  }
}
