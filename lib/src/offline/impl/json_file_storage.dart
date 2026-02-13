import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../offline_storage.dart';
import '../pending_mutation.dart';
import '../../utils/sdk_logger.dart';

class _AsyncLock {
  Completer<void>? _completer;

  Future<T> synchronized<T>(Future<T> Function() action) async {
    while (_completer != null) {
      await _completer!.future;
    }
    _completer = Completer<void>();
    try {
      return await action();
    } finally {
      final c = _completer!;
      _completer = null;
      c.complete();
    }
  }
}

class JsonFileStorage implements OfflineStorage {
  final String basePath;

  Directory? _baseDir;
  File? _mutationsFile;
  File? _syncTimesFile;
  bool _initialized = false;
  bool _disposed = false;
  int _pendingOperations = 0;
  Completer<void>? _allOperationsComplete;

  final _AsyncLock _mutationsLock = _AsyncLock();
  final _AsyncLock _syncTimesLock = _AsyncLock();
  final Map<String, _AsyncLock> _tableLocks = {};
  final _AsyncLock _globalLock = _AsyncLock();

  JsonFileStorage({required this.basePath});

  Future<T> _tracked<T>(Future<T> Function() operation) async {
    if (_disposed) {
      SdkLogger.w('Operation attempted after dispose, ignoring');
      throw StateError('Storage has been disposed');
    }
    _pendingOperations++;
    try {
      return await operation();
    } finally {
      _pendingOperations--;
      if (_pendingOperations == 0 && _allOperationsComplete != null) {
        _allOperationsComplete!.complete();
        _allOperationsComplete = null;
      }
    }
  }

  _AsyncLock _getTableLock(String tableName) {
    return _tableLocks.putIfAbsent(tableName, () => _AsyncLock());
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    _baseDir = Directory(basePath);
    if (!await _baseDir!.exists()) {
      await _baseDir!.create(recursive: true);
    }
    _mutationsFile = File('$basePath/pending_mutations.json');
    _syncTimesFile = File('$basePath/sync_times.json');

    await _recoverFromTempFiles();
    _initialized = true;
  }

  Future<void> _recoverFromTempFiles() async {
    await for (final entity in _baseDir!.list()) {
      if (entity is File && entity.path.endsWith('.tmp')) {
        final originalPath = entity.path.substring(0, entity.path.length - 4);
        final originalFile = File(originalPath);
        if (!await originalFile.exists()) {
          try {
            await entity.rename(originalPath);
          } catch (e) {
            SdkLogger.e('Failed to recover temp file: $e');
          }
        } else {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    }
  }

  File _tableFile(String tableName) => File('$basePath/table_$tableName.json');

  Future<void> _atomicWrite(File file, String content) async {
    final tempFile = File('${file.path}.tmp');
    final backupFile = File('${file.path}.bak');

    await tempFile.writeAsString(content, flush: true);

    if (await file.exists()) {
      try {
        await file.copy(backupFile.path);
      } catch (_) {}
    }

    await tempFile.rename(file.path);
  }

  Future<String?> _readWithFallback(File file) async {
    if (await file.exists()) {
      try {
        return await file.readAsString();
      } catch (e) {
        SdkLogger.e('Failed to read ${file.path}: $e');
      }
    }

    final backupFile = File('${file.path}.bak');
    if (await backupFile.exists()) {
      try {
        SdkLogger.i('Recovering from backup: ${backupFile.path}');
        return await backupFile.readAsString();
      } catch (e) {
        SdkLogger.e('Failed to read backup ${backupFile.path}: $e');
      }
    }

    return null;
  }

  @override
  Future<void> saveTableSnapshot(
    String tableName,
    List<Map<String, dynamic>> rows,
  ) async {
    await _tracked(() async {
      await _ensureInitialized();
      await _getTableLock(tableName).synchronized(() async {
        final file = _tableFile(tableName);
        final json = jsonEncode(rows);
        await _atomicWrite(file, json);
        await _cleanupBackup(file);
      });
    });
  }

  @override
  Future<List<Map<String, dynamic>>?> loadTableSnapshot(
    String tableName,
  ) async {
    return _getTableLock(tableName).synchronized(() async {
      final file = _tableFile(tableName);
      final content = await _readWithFallback(file);
      if (content == null) return null;

      try {
        final data = jsonDecode(content) as List;
        await _cleanupBackup(file);
        return data.cast<Map<String, dynamic>>();
      } catch (e) {
        SdkLogger.e('Failed to parse table snapshot for "$tableName": $e');
        return null;
      }
    });
  }

  Future<void> _cleanupBackup(File file) async {
    final backupFile = File('${file.path}.bak');
    if (await backupFile.exists()) {
      try {
        await backupFile.delete();
      } catch (_) {}
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await initialize();
    }
  }

  @override
  Future<void> enqueueMutation(PendingMutation mutation) async {
    await _tracked(() async {
      await _ensureInitialized();
      await _mutationsLock.synchronized(() async {
        final mutations = await _loadMutationsUnsafe();
        mutations.add(mutation);
        await _saveMutationsUnsafe(mutations);
      });
    });
  }

  @override
  Future<List<PendingMutation>> getPendingMutations() async {
    await _ensureInitialized();
    return _mutationsLock.synchronized(() => _loadMutationsUnsafe());
  }

  Future<List<PendingMutation>> _loadMutationsUnsafe() async {
    final content = await _readWithFallback(_mutationsFile!);
    if (content == null) return [];

    try {
      final data = jsonDecode(content) as List;
      return data
          .map((e) => PendingMutation.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      SdkLogger.e('Failed to parse pending mutations: $e');
      return [];
    }
  }

  @override
  Future<void> dequeueMutation(String requestId) async {
    await _tracked(() async {
      await _mutationsLock.synchronized(() async {
        final mutations = await _loadMutationsUnsafe();
        mutations.removeWhere((m) => m.requestId == requestId);
        await _saveMutationsUnsafe(mutations);
      });
    });
  }

  Future<void> _saveMutationsUnsafe(List<PendingMutation> mutations) async {
    final json = jsonEncode(mutations.map((m) => m.toJson()).toList());
    await _atomicWrite(_mutationsFile!, json);
  }

  @override
  Future<void> setLastSyncTime(String tableName, DateTime time) async {
    await _tracked(() async {
      await _ensureInitialized();
      await _syncTimesLock.synchronized(() async {
        final times = await _loadSyncTimesUnsafe();
        times[tableName] = time.toIso8601String();
        await _saveSyncTimesUnsafe(times);
      });
    });
  }

  @override
  Future<DateTime?> getLastSyncTime(String tableName) async {
    return _syncTimesLock.synchronized(() async {
      final times = await _loadSyncTimesUnsafe();
      final timeStr = times[tableName];
      if (timeStr == null) return null;
      return DateTime.tryParse(timeStr);
    });
  }

  Future<Map<String, String>> _loadSyncTimesUnsafe() async {
    final content = await _readWithFallback(_syncTimesFile!);
    if (content == null) return {};

    try {
      final data = jsonDecode(content) as Map<String, dynamic>;
      return data.cast<String, String>();
    } catch (e) {
      SdkLogger.e('Failed to parse sync times: $e');
      return {};
    }
  }

  Future<void> _saveSyncTimesUnsafe(Map<String, String> times) async {
    final json = jsonEncode(times);
    await _atomicWrite(_syncTimesFile!, json);
  }

  @override
  Future<void> clearAll() async {
    await _tracked(() async {
      await _globalLock.synchronized(() async {
        await _mutationsLock.synchronized(() async {
          await _syncTimesLock.synchronized(() async {
            if (await _baseDir!.exists()) {
              await _baseDir!.delete(recursive: true);
              await _baseDir!.create(recursive: true);
            }
            _tableLocks.clear();
          });
        });
      });
    });
  }

  @override
  Future<void> clearTableSnapshot(String tableName) async {
    await _tracked(() async {
      await _getTableLock(tableName).synchronized(() async {
        final file = _tableFile(tableName);
        if (await file.exists()) {
          await file.delete();
        }
        await _cleanupBackup(file);
      });
    });
  }

  @override
  Future<void> clearMutationQueue() async {
    await _tracked(() async {
      await _mutationsLock.synchronized(() async {
        if (await _mutationsFile!.exists()) {
          await _mutationsFile!.delete();
        }
      });
    });
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    if (_pendingOperations > 0) {
      _allOperationsComplete = Completer<void>();
      await _allOperationsComplete!.future;
    }
  }
}
