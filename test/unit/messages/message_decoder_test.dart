import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:spacetimedb/src/messages/message_decoder.dart';
import 'package:spacetimedb/src/messages/server_messages.dart';
import 'package:spacetimedb/src/codec/bsatn_encoder.dart';

void main() {
  group('MessageDecoder', () {
    test('decodes IdentityTokenMessage', () {
      // Create a mock IdentityToken message
      final encoder = BsatnEncoder();
      encoder.writeU8(0); // Compression tag: none
      encoder.writeU8(3); // IdentityToken tag
      encoder.writeBytes(Uint8List(32)); // 32-byte identity (256-bit)
      encoder.writeString('test-token'); // Token string
      encoder.writeBytes(Uint8List(16)); // 16-byte connectionId

      final bytes = encoder.toBytes();
      final message = MessageDecoder.decode(bytes);

      expect(message, isA<IdentityTokenMessage>());
      final identityMsg = message as IdentityTokenMessage;
      expect(identityMsg.token, equals('test-token'));
    });

    test('throws on unsupported message type', () {
      final encoder = BsatnEncoder();
      encoder.writeU8(0); // Compression tag: none
      encoder.writeU8(99); // Invalid message tag

      final bytes = encoder.toBytes();

      expect(
        () => MessageDecoder.decode(bytes),
        throwsA(isA<ArgumentError>()), // fromTag throws ArgumentError
      );
    });
  });
}
