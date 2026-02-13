import 'package:spacetimedb/src/connection/connection_status.dart';

/// Connection quality metrics
///
/// Provides detailed information about the connection health,
/// including reconnection attempts, latency, and error information.
class ConnectionQuality {
  /// Current connection status
  final ConnectionStatus status;

  /// Number of reconnection attempts (0 if never disconnected)
  final int reconnectAttempts;

  /// Time since last successful connection
  final Duration? timeSinceLastConnection;

  /// Average round-trip time for messages (if available)
  final Duration? averageLatency;

  /// Last error message, if any
  final String? lastError;

  /// Time when last ping was sent
  final DateTime? lastPingSent;

  /// Time when last pong was received
  final DateTime? lastPongReceived;

  ConnectionQuality({
    required this.status,
    this.reconnectAttempts = 0,
    this.timeSinceLastConnection,
    this.averageLatency,
    this.lastError,
    this.lastPingSent,
    this.lastPongReceived,
  });

  /// Compute connection health score (0.0 to 1.0)
  double get healthScore {
    if (status == ConnectionStatus.connected) {
      // Factor in latency and time since last pong
      if (lastPongReceived != null) {
        final timeSincePong = DateTime.now().difference(lastPongReceived!);
        if (timeSincePong.inSeconds > 60) return 0.5; // Stale
      }
      return 1.0; // Good
    }
    if (status == ConnectionStatus.reconnecting) {
      return 0.3; // Poor
    }
    return 0.0; // Disconnected or error
  }

  /// Human-readable quality description
  String get qualityDescription {
    if (healthScore >= 0.8) return 'Excellent';
    if (healthScore >= 0.5) return 'Good';
    if (healthScore >= 0.3) return 'Poor';
    return 'Disconnected';
  }

  @override
  String toString() {
    return 'ConnectionQuality(status: $status, quality: $qualityDescription, '
        'reconnectAttempts: $reconnectAttempts, healthScore: ${healthScore.toStringAsFixed(2)})';
  }
}
