import 'dart:developer' as developer;

/// Callback type for custom log handling.
typedef SdkLogCallback = void Function(String level, String message);

/// SDK logger with no-op default behavior.
///
/// By default, all log methods are no-ops. To enable logging, set [onLog]
/// to a custom callback, or call [enableDeveloperLog] to route logs through
/// `dart:developer`.
///
/// Example:
/// ```dart
/// // Option 1: Custom callback
/// SdkLogger.onLog = (level, msg) => print('[$level] $msg');
///
/// // Option 2: Use dart:developer (shows in DevTools)
/// SdkLogger.enableDeveloperLog();
/// ```
class SdkLogger {
  /// Custom log callback. When set, all log methods route here.
  /// When null (default), all log methods are no-ops.
  static SdkLogCallback? onLog;

  /// Enable logging via `dart:developer` (visible in DevTools/Observatory).
  static void enableDeveloperLog() {
    onLog = (level, msg) {
      final logLevel = switch (level) {
        'E' => 1000, // SEVERE
        'W' => 900, // WARNING
        'I' => 800, // INFO
        _ => 500, // FINE (debug)
      };
      developer.log(msg, name: 'spacetimedb', level: logLevel);
    };
  }

  /// Debug log — no-op unless [onLog] is set.
  static void d(String msg) => onLog?.call('D', msg);

  /// Info log — no-op unless [onLog] is set.
  static void i(String msg) => onLog?.call('I', msg);

  /// Warning log — no-op unless [onLog] is set.
  static void w(String msg) => onLog?.call('W', msg);

  /// Error log — no-op unless [onLog] is set.
  static void e(String msg) => onLog?.call('E', msg);
}
