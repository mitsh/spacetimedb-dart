import 'package:test/test.dart';
import 'package:spacetimedb/spacetimedb.dart';
import 'package:spacetimedb/src/cache/table_cache.dart';

import '../../generated/note.dart';
import '../../generated/note_status.dart';

Note createNote(int id, String title) => Note(
      id: id,
      title: title,
      content: '',
      timestamp: Int64(0),
      status: const NoteStatusDraft(),
    );

void main() {
  group('TableCache Optimistic Changes', () {
    late TableCache<Note> cache;

    setUp(() {
      cache = TableCache<Note>(
        tableId: 1,
        tableName: 'note',
        decoder: NoteDecoder(),
      );
    });

    tearDown(() => cache.dispose());

    test('optimistic insert adds row and tracks change', () {
      final note = createNote(1, 'Test');

      cache.applyOptimisticInsert('req-1', note);

      expect(cache.find(1)?.id, equals(1));
      expect(cache.hasOptimisticChange('req-1'), isTrue);
    });

    test('optimistic update replaces row and tracks old value', () {
      final oldNote = createNote(1, 'Old');
      final newNote = createNote(1, 'New');

      cache.insertRow(oldNote);
      cache.applyOptimisticUpdate('req-1', oldNote, newNote);

      expect(cache.find(1)?.title, equals('New'));
      expect(cache.hasOptimisticChange('req-1'), isTrue);
    });

    test('optimistic delete removes row and tracks deleted value', () {
      final note = createNote(1, 'Test');

      cache.insertRow(note);
      cache.applyOptimisticDelete('req-1', note);

      expect(cache.find(1), isNull);
      expect(cache.hasOptimisticChange('req-1'), isTrue);
    });

    test('confirm removes tracking but keeps changes', () {
      final note = createNote(1, 'Test');

      cache.applyOptimisticInsert('req-1', note);
      cache.confirmOptimisticChange('req-1');

      expect(cache.find(1)?.id, equals(1));
      expect(cache.hasOptimisticChange('req-1'), isFalse);
    });

    group('rollback', () {
      test('rollback insert removes row', () {
        final note = createNote(1, 'Test');

        cache.applyOptimisticInsert('req-1', note);
        cache.rollbackOptimisticChange('req-1');

        expect(cache.find(1), isNull);
        expect(cache.hasOptimisticChange('req-1'), isFalse);
      });

      test('rollback update restores old value', () {
        final oldNote = createNote(1, 'Old');
        final newNote = createNote(1, 'New');

        cache.insertRow(oldNote);
        cache.applyOptimisticUpdate('req-1', oldNote, newNote);
        cache.rollbackOptimisticChange('req-1');

        expect(cache.find(1)?.title, equals('Old'));
      });

      test('rollback delete restores row', () {
        final note = createNote(1, 'Test');

        cache.insertRow(note);
        cache.applyOptimisticDelete('req-1', note);
        cache.rollbackOptimisticChange('req-1');

        expect(cache.find(1)?.id, equals(1));
      });

      test('rollback multiple changes in reverse order', () {
        final note1 = createNote(1, 'Note 1');
        final note2 = createNote(2, 'Note 2');
        final note3 = createNote(3, 'Note 3');

        cache.applyOptimisticInsert('req-1', note1);
        cache.applyOptimisticInsert('req-1', note2);
        cache.applyOptimisticInsert('req-1', note3);

        cache.rollbackOptimisticChange('req-1');

        expect(cache.count(), equals(0));
      });

      test('rollback only affects specified request', () {
        final note1 = createNote(1, 'Note 1');
        final note2 = createNote(2, 'Note 2');

        cache.applyOptimisticInsert('req-1', note1);
        cache.applyOptimisticInsert('req-2', note2);

        cache.rollbackOptimisticChange('req-1');

        expect(cache.find(1), isNull);
        expect(cache.find(2)?.id, equals(2));
        expect(cache.hasOptimisticChange('req-2'), isTrue);
      });
    });

    test('loadFromSerializable preserves optimistic changes', () {
      final note = createNote(1, 'Optimistic');
      cache.applyOptimisticInsert('req-1', note);

      cache.loadFromSerializable([
        createNote(2, 'Server Note').toJson(),
      ]);

      expect(cache.hasOptimisticChange('req-1'), isTrue);
    });

    test('optimisticChangeCount reflects total changes', () {
      cache.applyOptimisticInsert('req-1', createNote(1, 'A'));
      cache.applyOptimisticInsert('req-1', createNote(2, 'B'));
      cache.applyOptimisticInsert('req-2', createNote(3, 'C'));

      expect(cache.optimisticChangeCount, equals(3));

      cache.confirmOptimisticChange('req-1');

      expect(cache.optimisticChangeCount, equals(1));
    });
  });
}
