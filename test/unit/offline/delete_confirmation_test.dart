import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:spacetimedb/spacetimedb.dart';
import 'package:spacetimedb/src/cache/table_cache.dart';
import 'package:spacetimedb/src/messages/shared_types.dart';
import 'package:spacetimedb/src/events/event_context.dart';

import '../../generated/note.dart';
import '../../generated/note_status.dart';

Note createNote(int id, String title) => Note(
      id: id,
      title: title,
      content: '',
      timestamp: Int64(0),
      status: const NoteStatusDraft(),
    );

BsatnRowList createRowList(List<Note> notes) {
  if (notes.isEmpty) {
    return BsatnRowList.empty();
  }

  final encodedRows = notes.map((note) {
    final encoder = BsatnEncoder();
    note.encodeBsatn(encoder);
    return encoder.toBytes();
  }).toList();

  final offsets = <int>[];
  var currentOffset = 0;

  for (final row in encodedRows) {
    offsets.add(currentOffset);
    currentOffset += row.length;
  }

  final combinedData = Uint8List(currentOffset);
  var writeOffset = 0;
  for (final row in encodedRows) {
    combinedData.setRange(writeOffset, writeOffset + row.length, row);
    writeOffset += row.length;
  }

  return BsatnRowList(
    sizeHint: RowSizeHint.rowOffsets(offsets),
    rowsData: combinedData,
  );
}

void main() {
  group('Delete Confirmation Bug Fix', () {
    late TableCache<Note> cache;
    late EventContext dummyContext;

    setUp(() {
      cache = TableCache<Note>(
        tableId: 1,
        tableName: 'note',
        decoder: NoteDecoder(),
      );
      dummyContext = EventContext.optimistic(requestId: 'dummy');
    });

    tearDown(() => cache.dispose());

    group('Test 1: Zombie Resurrection Check', () {
      test(
          'optimistic delete + server confirms = row stays deleted (THE BUG FIX)',
          () async {
        final note = createNote(100, 'To Delete');
        cache.insertRow(note);
        expect(cache.find(100)?.id, equals(100), reason: 'Setup: note exists');

        cache.applyOptimisticDelete('req-delete-100', note);
        expect(cache.find(100), isNull,
            reason: 'Row should be removed immediately by optimistic delete');
        expect(cache.hasOptimisticChange('req-delete-100'), isTrue);

        final deletes = createRowList([note]);
        final inserts = BsatnRowList.empty();
        final touchedKeys =
            cache.applyTransactionUpdateAndCollectKeys(deletes, inserts, dummyContext);

        expect(touchedKeys.contains(100), isTrue,
            reason:
                'CRITICAL: Delete PK must be in touchedKeys even though row was already gone from cache');

        cache.confirmOrRollbackOptimisticChange('req-delete-100', touchedKeys);

        await Future.delayed(Duration(milliseconds: 10));

        expect(cache.find(100), isNull,
            reason:
                'CRITICAL: Row must NOT reappear after server confirmation. '
                'This is the bug we fixed - touchedKeys must be extracted from server message, not local cache.');
      });

      test('without fix, row would be incorrectly restored', () {
        final note = createNote(101, 'Ghost Note');
        cache.insertRow(note);

        cache.applyOptimisticDelete('req-delete-101', note);
        expect(cache.find(101), isNull);

        final emptyTouchedKeys = <dynamic>{};
        cache.confirmOrRollbackOptimisticChange(
            'req-delete-101', emptyTouchedKeys);

        expect(cache.find(101)?.id, equals(101),
            reason:
                'With empty touchedKeys (simulating the bug), the delete gets rolled back');
      });
    });

    group('Test 2: Safety Net - Rollback Check', () {
      test('optimistic delete + server rejects = row is restored', () {
        final note = createNote(200, 'Keep Me');
        cache.insertRow(note);

        cache.applyOptimisticDelete('req-delete-200', note);
        expect(cache.find(200), isNull,
            reason: 'Optimistically removed');

        final emptyDeletes = BsatnRowList.empty();
        final emptyInserts = BsatnRowList.empty();
        final touchedKeys = cache.applyTransactionUpdateAndCollectKeys(
            emptyDeletes, emptyInserts, dummyContext);

        expect(touchedKeys.isEmpty, isTrue,
            reason: 'Server did nothing - empty transaction');

        cache.confirmOrRollbackOptimisticChange('req-delete-200', touchedKeys);

        expect(cache.find(200)?.id, equals(200),
            reason: 'Row should be restored since server did not confirm delete');
      });
    });

    group('Test 3: Batch Check - Rapid Fire Deletes', () {
      test('multiple parallel deletes all stay deleted', () async {
        final noteA = createNote(301, 'A');
        final noteB = createNote(302, 'B');
        final noteC = createNote(303, 'C');

        cache.insertRow(noteA);
        cache.insertRow(noteB);
        cache.insertRow(noteC);

        cache.applyOptimisticDelete('req-batch', noteA);
        cache.applyOptimisticDelete('req-batch', noteB);
        cache.applyOptimisticDelete('req-batch', noteC);

        expect(cache.find(301), isNull);
        expect(cache.find(302), isNull);
        expect(cache.find(303), isNull);

        final deletes = createRowList([noteA, noteB, noteC]);
        final inserts = BsatnRowList.empty();
        final touchedKeys =
            cache.applyTransactionUpdateAndCollectKeys(deletes, inserts, dummyContext);

        expect(touchedKeys.contains(301), isTrue);
        expect(touchedKeys.contains(302), isTrue);
        expect(touchedKeys.contains(303), isTrue);

        cache.confirmOrRollbackOptimisticChange('req-batch', touchedKeys);

        await Future.delayed(Duration(milliseconds: 10));

        expect(cache.find(301), isNull,
            reason: 'Note A must stay deleted');
        expect(cache.find(302), isNull,
            reason: 'Note B must stay deleted');
        expect(cache.find(303), isNull,
            reason: 'Note C must stay deleted');
      });

      test('partial batch - some confirmed, some rolled back', () {
        final noteA = createNote(304, 'A');
        final noteB = createNote(305, 'B');

        cache.insertRow(noteA);
        cache.insertRow(noteB);

        cache.applyOptimisticDelete('req-partial', noteA);
        cache.applyOptimisticDelete('req-partial', noteB);

        final deletes = createRowList([noteA]);
        final inserts = BsatnRowList.empty();
        final touchedKeys =
            cache.applyTransactionUpdateAndCollectKeys(deletes, inserts, dummyContext);

        expect(touchedKeys.contains(304), isTrue);
        expect(touchedKeys.contains(305), isFalse);

        cache.confirmOrRollbackOptimisticChange('req-partial', touchedKeys);

        expect(cache.find(304), isNull,
            reason: 'Note A was confirmed deleted');
        expect(cache.find(305)?.id, equals(305),
            reason: 'Note B was not touched, should be rolled back');
      });
    });

    group('Test 4: Already Gone Check (Offline Sync)', () {
      test('delete on row not in cache still collects PK', () {
        final note = createNote(400, 'Server Only');

        final deletes = createRowList([note]);
        final inserts = BsatnRowList.empty();
        final touchedKeys =
            cache.applyTransactionUpdateAndCollectKeys(deletes, inserts, dummyContext);

        expect(touchedKeys.contains(400), isTrue,
            reason:
                'Even when row was not in cache, the PK from server message should be collected');
      });

      test('offline sync with pending delete - row stays deleted', () async {
        final note = createNote(401, 'Offline Delete');

        cache.applyOptimisticInsert('req-create', note);
        expect(cache.find(401)?.id, equals(401));

        cache.applyOptimisticDelete('req-delete', note);
        expect(cache.find(401), isNull,
            reason: 'Optimistically deleted');

        cache.loadFromSerializable([]);

        expect(cache.hasOptimisticChange('req-delete'), isTrue,
            reason: 'Optimistic change should survive cache reload');

        final deletes = createRowList([note]);
        final inserts = BsatnRowList.empty();
        final touchedKeys =
            cache.applyTransactionUpdateAndCollectKeys(deletes, inserts, dummyContext);

        cache.confirmOrRollbackOptimisticChange('req-delete', touchedKeys);

        await Future.delayed(Duration(milliseconds: 10));

        expect(cache.find(401), isNull,
            reason: 'Row must remain deleted after sync confirmation');
      });
    });

    group('Edge Cases', () {
      test('update followed by delete - final state is deleted', () {
        final note = createNote(500, 'Original');
        final updated = createNote(500, 'Updated');

        cache.insertRow(note);

        cache.applyOptimisticUpdate('req-update', note, updated);
        expect(cache.find(500)?.title, equals('Updated'));

        cache.applyOptimisticDelete('req-delete', updated);
        expect(cache.find(500), isNull);

        final deletes = createRowList([updated]);
        final inserts = BsatnRowList.empty();
        final touchedKeys =
            cache.applyTransactionUpdateAndCollectKeys(deletes, inserts, dummyContext);

        cache.confirmOrRollbackOptimisticChange('req-delete', touchedKeys);

        expect(cache.find(500), isNull,
            reason: 'Delete should win over update');
      });

      test('delete with server sending different row version', () {
        final clientNote = createNote(600, 'Client Version');
        final serverNote = createNote(600, 'Server Version');

        cache.insertRow(clientNote);
        cache.applyOptimisticDelete('req-delete', clientNote);

        final deletes = createRowList([serverNote]);
        final touchedKeys = cache.applyTransactionUpdateAndCollectKeys(
            deletes, BsatnRowList.empty(), dummyContext);

        expect(touchedKeys.contains(600), isTrue,
            reason: 'PK 600 should be touched regardless of title mismatch');

        cache.confirmOrRollbackOptimisticChange('req-delete', touchedKeys);

        expect(cache.find(600), isNull,
            reason: 'Row should stay deleted');
      });
    });
  });
}
