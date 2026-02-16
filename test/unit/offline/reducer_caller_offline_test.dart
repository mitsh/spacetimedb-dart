import 'dart:async';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:spacetimedb/spacetimedb.dart';

const _timeout = Duration(seconds: 5);

class MockOfflineConnection implements SpacetimeDbConnection {
  final List<Uint8List> sentMessages = [];
  ConnectionState _state = ConnectionState.disconnected;
  ConnectionStatus _status = ConnectionStatus.disconnected;

  final _stateController = StreamController<ConnectionState>.broadcast();
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  final _incomingController = StreamController<Uint8List>.broadcast();
  final _qualityController = StreamController<ConnectionQuality>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  @override
  Stream<Uint8List> get onMessage => _incomingController.stream;
  @override
  Stream<ConnectionState> get onStateChanged => _stateController.stream;
  @override
  ConnectionState get state => _state;
  @override
  bool get isConnected => _state == ConnectionState.connected;
  @override
  ConnectionStatus get status => _status;
  @override
  Stream<ConnectionStatus> get connectionStatus => _statusController.stream;
  @override
  Stream<ConnectionQuality> get connectionQuality => _qualityController.stream;
  @override
  Stream<String> get onError => _errorController.stream;

  @override
  void send(Uint8List data) => sentMessages.add(data);

  @override
  Future<void> connect() async {
    _state = ConnectionState.connected;
    _status = ConnectionStatus.connected;
    _stateController.add(_state);
    _statusController.add(_status);
  }

  @override
  Future<void> disconnect() async {
    _state = ConnectionState.disconnected;
    _status = ConnectionStatus.disconnected;
    _stateController.add(_state);
    _statusController.add(_status);
  }

  @override
  Future<void> dispose() async {
    await _incomingController.close();
    await _stateController.close();
    await _statusController.close();
    await _qualityController.close();
    await _errorController.close();
  }

  @override
  Future<void> reconnect() async => connect();
  @override
  Future<void> retryConnection() async => connect();
  @override
  void enableAutoReconnect(bool enabled) {}
  @override
  void updateToken(String token) {}
  @override
  String get host => 'mock://localhost';
  @override
  String get database => 'mock_db';
  @override
  String? get initialToken => null;
  @override
  String? get token => null;
  @override
  bool get ssl => false;
  @override
  ConnectionConfig get config => const ConnectionConfig();
  @override
  Future<void> callReducer(String reducerName, Uint8List args,
      {int? requestId}) async {
    throw UnimplementedError();
  }

  void setOnline() {
    _state = ConnectionState.connected;
    _status = ConnectionStatus.connected;
    _stateController.add(_state);
    _statusController.add(_status);
  }

  void setOffline() {
    _state = ConnectionState.disconnected;
    _status = ConnectionStatus.disconnected;
    _stateController.add(_state);
    _statusController.add(_status);
  }
}

void main() {
  group('ReducerCaller Offline Queue', () {
    late MockOfflineConnection connection;
    late InMemoryOfflineStorage storage;
    late ReducerCaller caller;

    setUp(() {
      connection = MockOfflineConnection();
      storage = InMemoryOfflineStorage();
      caller = ReducerCaller(connection, offlineStorage: storage);
    });

    tearDown(() async {
      caller.dispose();
      await connection.dispose();
      await storage.dispose();
    });

    test('queues first then triggers sync when online (offline-first)',
        () async {
      connection.setOnline();

      var syncTriggered = false;
      caller.onTrySyncNow = () => syncTriggered = true;

      final result =
          await caller.call('create_note', Uint8List.fromList([1, 2, 3]));

      expect(result.isPending, isTrue);
      expect(syncTriggered, isTrue);
      final pending = await storage.getPendingMutations().timeout(_timeout);
      expect(pending.length, equals(1));
    });

    test('queues mutation when offline', () async {
      connection.setOffline();

      final result = await caller
          .call('create_note', Uint8List.fromList([1, 2, 3]))
          .timeout(_timeout);

      expect(result.isPending, isTrue);
      expect(result.pendingRequestId, isNotNull);
      expect(connection.sentMessages, isEmpty);

      final pending = await storage.getPendingMutations().timeout(_timeout);
      expect(pending.length, equals(1));
      expect(pending.first.reducerName, equals('create_note'));
    });

    test('offline-first always queues mutations', () async {
      connection.setOffline();

      final result =
          await caller.call('create_note', Uint8List.fromList([1, 2, 3]));

      expect(result.isPending, isTrue);
      final pending = await storage.getPendingMutations().timeout(_timeout);
      expect(pending.length, equals(1));
    });

    test('stores optimistic changes with queued mutation', () async {
      connection.setOffline();

      await caller.call(
        'create_note',
        Uint8List.fromList([1, 2, 3]),
        optimisticChanges: [
          OptimisticChange.insert('notes', {'id': 1, 'title': 'Test'}),
        ],
      ).timeout(_timeout);

      final pending = await storage.getPendingMutations().timeout(_timeout);
      expect(pending.first.optimisticChanges, isNotNull);
      expect(pending.first.optimisticChanges!.length, equals(1));
    });

    test('without storage sends directly even when offline', () async {
      final noStorageCaller = ReducerCaller(connection);
      connection.setOffline();

      final future =
          noStorageCaller.call('create_note', Uint8List.fromList([1, 2, 3]));

      expect(connection.sentMessages.length, equals(1));

      noStorageCaller.dispose();
      future.ignore();
    });

    test('generates unique request IDs for queued mutations', () async {
      connection.setOffline();

      final r1 =
          await caller.call('r1', Uint8List.fromList([1])).timeout(_timeout);
      final r2 =
          await caller.call('r2', Uint8List.fromList([2])).timeout(_timeout);

      expect(r1.pendingRequestId, isNot(equals(r2.pendingRequestId)));
    });
  });
}
