import 'dart:typed_data';

import 'optimistic_change.dart';

export 'optimistic_change.dart';

/// Represents a mutation that has been queued for synchronization.
///
/// Lifecycle:
/// 1. **Queued**: Created and added to [OfflineStorage] when a reducer is called while offline.
/// 2. **Synced**: Sent to the server when connection is restored.
/// 3. **Dequeued**: Removed from storage after the server confirms success or permanent failure.
class PendingMutation {
  /// Unique identifier for this mutation request.
  final String requestId;

  /// Name of the reducer to be called.
  final String reducerName;

  /// BSATN-encoded arguments for the reducer.
  final Uint8List encodedArgs;

  /// When this mutation was first created.
  final DateTime createdAt;

  /// Optional list of optimistic changes to apply to the local cache.
  final List<OptimisticChange>? optimisticChanges;

  PendingMutation({
    required this.requestId,
    required this.reducerName,
    required this.encodedArgs,
    required this.createdAt,
    this.optimisticChanges,
  });

  /// Creates a copy of this mutation with the given fields replaced.
  PendingMutation copyWith({
    String? requestId,
    String? reducerName,
    Uint8List? encodedArgs,
    DateTime? createdAt,
    List<OptimisticChange>? optimisticChanges,
  }) {
    return PendingMutation(
      requestId: requestId ?? this.requestId,
      reducerName: reducerName ?? this.reducerName,
      encodedArgs: encodedArgs ?? this.encodedArgs,
      createdAt: createdAt ?? this.createdAt,
      optimisticChanges: optimisticChanges ?? this.optimisticChanges,
    );
  }

  /// Converts this mutation to a JSON-compatible map for storage.
  Map<String, dynamic> toJson() {
    return {
      'requestId': requestId,
      'reducerName': reducerName,
      'encodedArgs': encodedArgs.toList(),
      'createdAt': createdAt.toIso8601String(),
      'optimisticChanges': optimisticChanges?.map((c) => c.toJson()).toList(),
    };
  }

  /// Creates a [PendingMutation] from a JSON map.
  factory PendingMutation.fromJson(Map<String, dynamic> json) {
    final changesJson = json['optimisticChanges'] as List?;
    return PendingMutation(
      requestId: json['requestId'] as String,
      reducerName: json['reducerName'] as String,
      encodedArgs: Uint8List.fromList(
        (json['encodedArgs'] as List).cast<int>(),
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      optimisticChanges: changesJson
          ?.map((c) => OptimisticChange.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() {
    return 'PendingMutation(requestId: $requestId, reducer: $reducerName)';
  }
}
