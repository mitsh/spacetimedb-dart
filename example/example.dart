// ignore_for_file: avoid_print
import 'package:spacetimedb/spacetimedb.dart';

/// Example showing how to use the SpacetimeDB Dart SDK.
///
/// Before running, generate client code:
/// ```bash
/// dart run spacetimedb:generate -s http://localhost:3000 -d your_database -o lib/generated
/// ```
///
/// Then use the generated `SpacetimeDbClient` class to connect:
void main() async {
  // 1. BSATN Encoding/Decoding
  final encoder = BsatnEncoder();
  encoder.writeString('Hello SpacetimeDB');
  encoder.writeU32(42);
  encoder.writeBool(true);
  encoder.writeOption<String>('optional value', (v) => encoder.writeString(v));

  final bytes = encoder.toBytes();
  final decoder = BsatnDecoder(bytes);
  print('String: ${decoder.readString()}');
  print('U32: ${decoder.readU32()}');
  print('Bool: ${decoder.readBool()}');
  print('Option: ${decoder.readOption<String>(() => decoder.readString())}');

  // 2. Identity
  // Identities are 32-byte public key hashes
  // In a real app, you get these from the SpacetimeDB connection
  print('Identity size: 32 bytes');

  // 3. Connection (requires a running SpacetimeDB instance)
  // final client = await SpacetimeDbClient.connect(
  //   host: 'localhost:3000',
  //   database: 'your_database',
  //   ssl: false,
  //   authStorage: InMemoryTokenStore(),
  //   initialSubscriptions: ['SELECT * FROM users'],
  // );
  //
  // // Access tables
  // for (final user in client.users.iter()) {
  //   print('User: ${user.name}');
  // }
  //
  // // Call reducers
  // final result = await client.reducers.createUser(name: 'Alice');
  // print('Success: ${result.isSuccess}');
  //
  // // Listen to changes
  // client.users.insertStream.listen((user) => print('New user: ${user.name}'));
  //
  // // Disconnect
  // await client.disconnect();
}
