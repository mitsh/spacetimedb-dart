import 'dart:async';
import '../events/event_context.dart';

/// Broadcasts reducer completion events to registered listeners
///
/// This class acts as a central event bus for reducer completions.
/// When a `TransactionUpdate` message arrives with reducer info, the
/// SubscriptionManager creates an EventContext and broadcasts it through
/// this emitter to all registered listeners.
///
/// Each reducer can have multiple listeners (broadcast stream). The typical
/// usage pattern is:
///
/// ```dart
/// // Generated code creates typed callbacks:
/// StreamSubscription<void> onCreateNote(
///   void Function(EventContext ctx, String title, String content) callback
/// ) {
///   return reducerEmitter.on('create_note').listen((ctx) {
///     if (ctx.event is! ReducerEvent) return;
///     final event = ctx.event as ReducerEvent;
///     final args = event.reducerArgs;
///     if (args is! CreateNoteArgs) return;
///
///     // Type-safe callback invocation
///     callback(ctx, args.title, args.content);
///   });
/// }
/// ```
///
/// **Key Design Principles:**
/// - Broadcast pattern: All clients receive all reducer events
/// - Zero-overhead: No listeners = no work
/// - Type-safe: Generated code enforces type safety
/// - Cancellable: Returns StreamSubscription for cleanup
class ReducerEmitter {
  /// Map of reducer name → broadcast stream controller
  ///
  /// Controllers are created lazily when first listener registers.
  /// This keeps memory usage low for reducers that are never listened to.
  final Map<String, StreamController<EventContext>> _controllers = {};

  /// Get a stream of completion events for a specific reducer
  ///
  /// The stream is broadcast, meaning multiple listeners can subscribe
  /// to the same reducer without affecting each other.
  ///
  /// Example:
  /// ```dart
  /// // Listen for create_note completions
  /// final subscription = emitter.on('create_note').listen((ctx) {
  ///   print('create_note completed');
  ///   if (ctx.event is ReducerEvent) {
  ///     final event = ctx.event as ReducerEvent;
  ///     print('Status: ${event.status}');
  ///   }
  /// });
  ///
  /// // Cancel when done
  /// subscription.cancel();
  /// ```
  ///
  /// **Parameters:**
  /// - `reducerName`: The exact reducer name from the schema (e.g., 'create_note')
  ///
  /// **Returns:**
  /// A broadcast stream that emits EventContext whenever the reducer completes.
  Stream<EventContext> on(String reducerName) {
    // Lazily create controller if it doesn't exist
    if (!_controllers.containsKey(reducerName)) {
      _controllers[reducerName] = StreamController<EventContext>.broadcast();
    }

    return _controllers[reducerName]!.stream;
  }

  /// Emit a reducer completion event to all listeners
  ///
  /// Called by SubscriptionManager when a TransactionUpdate message
  /// arrives with reducer metadata.
  ///
  /// This broadcasts the EventContext to all listeners registered via `on()`.
  ///
  /// Example (internal usage):
  /// ```dart
  /// // In SubscriptionManager._handleTransactionUpdate:
  /// if (message.reducerInfo != null) {
  ///   final context = EventContext(...);
  ///   reducerEmitter.emit(message.reducerInfo.reducerName, context);
  /// }
  /// ```
  ///
  /// **Parameters:**
  /// - `reducerName`: The reducer that completed
  /// - `context`: EventContext containing the event and client reference
  void emit(String reducerName, EventContext context) {
    final controller = _controllers[reducerName];

    // If no one is listening to this reducer, don't create a controller
    if (controller == null) return;

    // Broadcast to all listeners
    controller.add(context);
  }

  /// Check if anyone is listening to a specific reducer
  ///
  /// Useful for debugging or optimization (avoid work if no listeners).
  ///
  /// Example:
  /// ```dart
  /// if (emitter.hasListeners('create_note')) {
  ///   print('Someone is listening for create_note completions');
  /// }
  /// ```
  bool hasListeners(String reducerName) {
    final controller = _controllers[reducerName];
    return controller != null && controller.hasListener;
  }

  /// Get list of all reducer names being listened to
  ///
  /// Useful for debugging to see which reducers have active listeners.
  ///
  /// Example:
  /// ```dart
  /// print('Active listeners: ${emitter.activeReducers}');
  /// // Output: Active listeners: [create_note, update_note]
  /// ```
  List<String> get activeReducers => _controllers.keys.toList();

  /// Dispose all stream controllers
  ///
  /// Call this when shutting down the connection to clean up resources.
  ///
  /// Example:
  /// ```dart
  /// // On disconnect:
  /// reducerEmitter.dispose();
  /// ```
  void dispose() {
    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }
}
