import 'event_context.dart';

/// Base sealed class for all table change events
///
/// Provides unified access to [EventContext] across all event types,
/// enabling pattern matching and type-safe event handling.
///
/// The sealed class pattern ensures exhaustive handling of all event types:
/// ```dart
/// void handleTableEvent<T>(TableEvent<T> event) {
///   switch (event) {
///     case TableInsertEvent(:final row, :final context):
///       print('Inserted: $row');
///       if (context.isMyTransaction) {
///         print('By me!');
///       }
///     case TableUpdateEvent(:final oldRow, :final newRow):
///       print('Updated: $oldRow → $newRow');
///     case TableDeleteEvent(:final row):
///       print('Deleted: $row');
///   }
/// }
/// ```
sealed class TableEvent<T> {
  /// Context containing the Event and client access
  EventContext get context;
}

/// Event emitted when a row is inserted into a table
///
/// Contains the newly inserted row and the event context with transaction metadata.
///
/// Example:
/// ```dart
/// noteTable.insertEventStream.listen((event) {
///   print('New note: ${event.row.title}');
///
///   if (event.context.isMyTransaction) {
///     print('I created this note!');
///   }
///
///   // Access reducer metadata
///   if (event.context.event is ReducerEvent) {
///     final reducerEvent = event.context.event as ReducerEvent;
///     print('Created by reducer: ${reducerEvent.reducerName}');
///   }
/// });
/// ```
class TableInsertEvent<T> extends TableEvent<T> {
  @override
  final EventContext context;

  /// The newly inserted row
  final T row;

  TableInsertEvent(this.context, this.row);
}

/// Event emitted when a row is updated in a table
///
/// Contains both the old and new versions of the row, allowing handlers
/// to compare what changed.
///
/// Example:
/// ```dart
/// noteTable.updateEventStream.listen((event) {
///   print('Note updated:');
///   print('  Old title: ${event.oldRow.title}');
///   print('  New title: ${event.newRow.title}');
///
///   if (event.oldRow.title != event.newRow.title) {
///     print('Title changed!');
///   }
/// });
/// ```
class TableUpdateEvent<T> extends TableEvent<T> {
  @override
  final EventContext context;

  /// The row before the update
  final T oldRow;

  /// The row after the update
  final T newRow;

  TableUpdateEvent(this.context, this.oldRow, this.newRow);
}

/// Event emitted when a row is deleted from a table
///
/// Contains the deleted row and the event context with transaction metadata.
///
/// Example:
/// ```dart
/// noteTable.deleteEventStream.listen((event) {
///   print('Note deleted: ${event.row.title}');
///
///   if (event.context.isMyTransaction) {
///     print('I deleted this note');
///   } else {
///     print('Someone else deleted this note');
///   }
/// });
/// ```
class TableDeleteEvent<T> extends TableEvent<T> {
  @override
  final EventContext context;

  /// The deleted row (contains data before deletion)
  final T row;

  TableDeleteEvent(this.context, this.row);
}
