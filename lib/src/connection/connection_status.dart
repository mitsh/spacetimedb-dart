/// Public connection status for UI binding
///
/// Represents the high-level connection state that applications should
/// observe for showing UI feedback to users.
enum ConnectionStatus {
  /// Initial state, not yet attempted to connect
  disconnected,

  /// First connection attempt in progress
  connecting,

  /// Successfully connected and authenticated
  connected,

  /// Connection lost, attempting to reconnect (with attempt count)
  reconnecting,

  /// Authentication failed (401) - token invalid or expired, app should handle
  authError,

  /// Too many reconnection failures, manual intervention required
  fatalError,
}

extension ConnectionStatusExtension on ConnectionStatus {
  /// Whether the connection is currently established
  bool get isConnected => this == ConnectionStatus.connected;

  /// Whether a connection attempt is in progress
  bool get isConnecting =>
      this == ConnectionStatus.connecting ||
      this == ConnectionStatus.reconnecting;

  /// Whether manual retry is possible
  bool get canRetry =>
      this == ConnectionStatus.disconnected ||
      this == ConnectionStatus.fatalError ||
      this == ConnectionStatus.authError;

  /// Human-readable display name for this status
  String get displayName {
    switch (this) {
      case ConnectionStatus.disconnected:
        return 'Disconnected';
      case ConnectionStatus.connecting:
        return 'Connecting...';
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting...';
      case ConnectionStatus.authError:
        return 'Authentication Failed';
      case ConnectionStatus.fatalError:
        return 'Connection Failed';
    }
  }
}
