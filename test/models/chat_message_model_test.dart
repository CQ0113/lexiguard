import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lei_guard/models/chat_message_model.dart';
import 'package:lei_guard/models/user_model.dart' show UserRole;

// ─── Helpers ──────────────────────────────────────────────────────────────────

Future<DocumentSnapshot> _writeAndRead(
  FakeFirebaseFirestore fakeDb,
  Map<String, dynamic> data,
) async {
  final ref =
      fakeDb.collection('chat_rooms').doc('r1').collection('messages').doc('m1');
  await ref.set(data);
  return ref.get();
}

ChatMessage _makeTextMessage({
  String id = 'msg_1',
  String roomId = 'room_1',
  String senderId = 'client_1',
  UserRole senderRole = UserRole.client,
  String text = 'Hello world',
  DateTime? createdAt,
}) {
  return ChatMessage(
    id: id,
    roomId: roomId,
    senderId: senderId,
    senderRole: senderRole,
    type: MessageType.text,
    text: text,
    createdAt: createdAt ?? DateTime.utc(2026, 5, 10, 9, 0),
  );
}

ChatMessage _makeFileMessage() {
  return ChatMessage(
    id: 'msg_file',
    roomId: 'room_1',
    senderId: 'lawyer_1',
    senderRole: UserRole.lawyer,
    type: MessageType.file,
    attachmentStoragePath: 'chat_attachments/room_1/msg_file_contract.pdf',
    attachmentDownloadUrl: 'https://storage.example.com/contract.pdf',
    attachmentName: 'contract.pdf',
    attachmentSize: 204800,
    mimeType: 'application/pdf',
    createdAt: DateTime.utc(2026, 5, 10, 10, 0),
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  // ── MessageType wire values ─────────────────────────────────────────────────

  group('MessageType wire values', () {
    test('each enum value round-trips through wire format', () {
      final cases = {
        MessageType.text: 'text',
        MessageType.image: 'image',
        MessageType.file: 'file',
      };
      for (final entry in cases.entries) {
        expect(entry.key.wireValue, entry.value,
            reason: 'wireValue for ${entry.key}');
        expect(
          MessageTypeWire.fromWire(entry.value),
          entry.key,
          reason: 'fromWire for ${entry.value}',
        );
      }
    });

    test('fromWire falls back to text for unknown string', () {
      expect(MessageTypeWire.fromWire('bogus'), MessageType.text);
      expect(MessageTypeWire.fromWire(null), MessageType.text);
    });
  });

  // ── toMap / fromFirestore round-trip ────────────────────────────────────────

  group('ChatMessage toMap / fromFirestore round-trip', () {
    Future<ChatMessage> roundTrip(ChatMessage message) async {
      final snap = await _writeAndRead(fakeDb, message.toMap());
      return ChatMessage.fromFirestore(snap);
    }

    test('round-trips a text message', () async {
      final msg = _makeTextMessage();
      final restored = await roundTrip(msg);

      expect(restored.id, msg.id);
      expect(restored.roomId, msg.roomId);
      expect(restored.senderId, msg.senderId);
      expect(restored.senderRole, msg.senderRole);
      expect(restored.type, MessageType.text);
      expect(restored.text, msg.text);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        msg.createdAt.millisecondsSinceEpoch,
      );
      // Attachment fields absent on a text message.
      expect(restored.attachmentStoragePath, isNull);
      expect(restored.attachmentDownloadUrl, isNull);
    });

    test('round-trips a file message with all attachment fields', () async {
      final msg = _makeFileMessage();
      final restored = await roundTrip(msg);

      expect(restored.type, MessageType.file);
      expect(restored.senderRole, UserRole.lawyer);
      expect(restored.attachmentStoragePath,
          'chat_attachments/room_1/msg_file_contract.pdf');
      expect(restored.attachmentDownloadUrl,
          'https://storage.example.com/contract.pdf');
      expect(restored.attachmentName, 'contract.pdf');
      expect(restored.attachmentSize, 204800);
      expect(restored.mimeType, 'application/pdf');
      expect(restored.text, isNull);
    });

    test('round-trips an image message', () async {
      final msg = ChatMessage(
        id: 'msg_img',
        roomId: 'room_1',
        senderId: 'client_1',
        senderRole: UserRole.client,
        type: MessageType.image,
        attachmentStoragePath: 'chat_attachments/room_1/msg_img_photo.jpg',
        attachmentName: 'photo.jpg',
        attachmentSize: 512000,
        mimeType: 'image/jpeg',
        createdAt: DateTime.utc(2026, 5, 11),
      );
      final restored = await roundTrip(msg);

      expect(restored.type, MessageType.image);
      expect(restored.mimeType, 'image/jpeg');
    });

    test('senderRole lawyer round-trips correctly', () async {
      final msg = _makeTextMessage(senderRole: UserRole.lawyer);
      final restored = await roundTrip(msg);
      expect(restored.senderRole, UserRole.lawyer);
    });

    test('missing optional fields fall back gracefully', () async {
      // Minimal doc — just enough for the factory not to throw.
      final snap = await _writeAndRead(fakeDb, {
        'roomId': 'r1',
        'senderId': 'u1',
        'senderRole': 'client',
        'type': 'text',
      });
      final restored = ChatMessage.fromFirestore(snap);

      expect(restored.text, isNull);
      expect(restored.attachmentStoragePath, isNull);
      expect(restored.mimeType, isNull);
      // createdAt falls back to epoch when absent.
      expect(restored.createdAt, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  // ── copyWith ────────────────────────────────────────────────────────────────

  group('ChatMessage.copyWith', () {
    test('copyWith updates only specified fields', () {
      final msg = _makeTextMessage();
      final updated = msg.copyWith(text: 'Updated text');

      expect(updated.text, 'Updated text');
      expect(updated.id, msg.id);     // unchanged
      expect(updated.roomId, msg.roomId); // unchanged
    });

    test('clearText sets text to null', () {
      final msg = _makeTextMessage(text: 'Some text');
      final cleared = msg.copyWith(clearText: true);
      expect(cleared.text, isNull);
    });

    test('clearAttachmentDownloadUrl sets it to null', () {
      final msg = _makeFileMessage();
      expect(msg.attachmentDownloadUrl, isNotNull);

      final cleared = msg.copyWith(clearAttachmentDownloadUrl: true);
      expect(cleared.attachmentDownloadUrl, isNull);
      // storagePath should still be present.
      expect(cleared.attachmentStoragePath, msg.attachmentStoragePath);
    });

    test('copyWith with no arguments returns equivalent message', () {
      final msg = _makeTextMessage();
      final copy = msg.copyWith();

      expect(copy.id, msg.id);
      expect(copy.text, msg.text);
      expect(copy.senderRole, msg.senderRole);
    });

    test('copyWith can change senderRole', () {
      final msg = _makeTextMessage(senderRole: UserRole.client);
      final updated = msg.copyWith(senderRole: UserRole.lawyer);
      expect(updated.senderRole, UserRole.lawyer);
    });
  });
}
