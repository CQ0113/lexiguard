import 'dart:typed_data';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lei_guard/models/user_model.dart' show UserRole;
import 'package:lei_guard/repositories/chat_repository.dart';

// ─── Fixtures ─────────────────────────────────────────────────────────────────

const _clientId = 'client_1';
const _lawyerId = 'lawyer_1';
const _roomId = 'case_1_lawyer_1';

/// Seed a chat room doc into fake Firestore (mirrors the helper in
/// chat_repository_test.dart so both test files stay consistent).
Future<void> _seedRoom(
  FakeFirebaseFirestore db, {
  String roomId = _roomId,
  String clientId = _clientId,
  String lawyerId = _lawyerId,
}) async {
  await db.collection('chat_rooms').doc(roomId).set({
    'id': roomId,
    'caseId': 'case_1',
    'clientId': clientId,
    'lawyerId': lawyerId,
    'participants': [clientId, lawyerId],
    'clientName': 'Lim Mei Ling',
    'lawyerName': 'Ahmad Zaki',
    'lawyerAvatarUrl': '',
    'caseTitle': 'Property dispute',
    'lastMessageText': '',
    'lastMessageType': 'text',
    'lastSenderId': '',
    'lastMessageAt': null,
    'createdAt': DateTime.utc(2026, 5, 1),
    'unreadCounts': {clientId: 0, lawyerId: 0},
  });
}

/// A no-op storage uploader that immediately returns a fake download URL.
/// Used to verify the Firestore side of [ChatRepository.sendAttachmentMessage]
/// without requiring a real [FirebaseStorage] instance.
Future<({String storagePath, String downloadUrl})> _fakeUploader(
  String storagePath,
  Uint8List bytes,
  String mimeType,
) async {
  return (
    storagePath: storagePath,
    downloadUrl: 'https://fake.storage/$storagePath',
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late FakeFirebaseFirestore fakeDb;
  late ChatRepository repo;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = ChatRepository(firestore: fakeDb, storageUploader: _fakeUploader);
  });

  // ── Size validation ─────────────────────────────────────────────────────────

  group('sendAttachmentMessage — size guard', () {
    test('throws ArgumentError when bytes exceed 10 MB', () async {
      await _seedRoom(fakeDb);

      // 10 MB + 1 byte
      final oversized = Uint8List(10 * 1024 * 1024 + 1);

      await expectLater(
        repo.sendAttachmentMessage(
          roomId: _roomId,
          senderId: _clientId,
          senderRole: UserRole.client,
          recipientId: _lawyerId,
          bytes: oversized,
          fileName: 'big_file.pdf',
          mimeType: 'application/pdf',
          type: MessageType.file,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('does not throw for a file exactly at the 10 MB limit', () async {
      await _seedRoom(fakeDb);

      final exactLimit = Uint8List(10 * 1024 * 1024);

      await expectLater(
        repo.sendAttachmentMessage(
          roomId: _roomId,
          senderId: _clientId,
          senderRole: UserRole.client,
          recipientId: _lawyerId,
          bytes: exactLimit,
          fileName: 'exactly_10mb.pdf',
          mimeType: 'application/pdf',
          type: MessageType.file,
        ),
        completes,
      );
    });
  });

  // ── Happy path — Firestore writes ───────────────────────────────────────────

  group('sendAttachmentMessage — Firestore writes (image)', () {
    test('writes message doc with all attachment fields', () async {
      await _seedRoom(fakeDb);

      final imageBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF]); // JPEG header
      await repo.sendAttachmentMessage(
        roomId: _roomId,
        senderId: _lawyerId,
        senderRole: UserRole.lawyer,
        recipientId: _clientId,
        bytes: imageBytes,
        fileName: 'contract_photo.jpg',
        mimeType: 'image/jpeg',
        type: MessageType.image,
      );

      final msgSnap = await fakeDb
          .collection('chat_rooms')
          .doc(_roomId)
          .collection('messages')
          .get();

      expect(msgSnap.docs.length, 1);
      final data = msgSnap.docs.first.data();

      expect(data['type'], 'image');
      expect(data['senderId'], _lawyerId);
      expect(data['senderRole'], 'lawyer');
      expect(data['mimeType'], 'image/jpeg');
      expect(data['attachmentName'], 'contract_photo.jpg');
      expect(data['attachmentSize'], imageBytes.length);

      // Storage path must contain the room ID and sanitized filename.
      final path = data['attachmentStoragePath'] as String;
      expect(path, startsWith('chat_attachments/$_roomId/'));
      expect(path, contains('contract_photo.jpg'));

      // Download URL must be non-empty.
      expect(data['attachmentDownloadUrl'], isNotEmpty);
    });

    test('sets attachmentStoragePath correctly', () async {
      await _seedRoom(fakeDb);

      final bytes = Uint8List(100);
      await repo.sendAttachmentMessage(
        roomId: _roomId,
        senderId: _clientId,
        senderRole: UserRole.client,
        recipientId: _lawyerId,
        bytes: bytes,
        fileName: 'scan.pdf',
        mimeType: 'application/pdf',
        type: MessageType.file,
      );

      final msgSnap = await fakeDb
          .collection('chat_rooms')
          .doc(_roomId)
          .collection('messages')
          .get();

      final data = msgSnap.docs.first.data();
      final storagePath = data['attachmentStoragePath'] as String;

      // Path format: chat_attachments/{roomId}/{messageId}_{sanitizedFileName}
      expect(storagePath, startsWith('chat_attachments/$_roomId/'));
      expect(storagePath, endsWith('_scan.pdf'));
    });
  });

  // ── Room last-message fields ────────────────────────────────────────────────

  group('sendAttachmentMessage — room update', () {
    test('sets lastMessageType and lastSenderId on room', () async {
      await _seedRoom(fakeDb);

      await repo.sendAttachmentMessage(
        roomId: _roomId,
        senderId: _clientId,
        senderRole: UserRole.client,
        recipientId: _lawyerId,
        bytes: Uint8List(50),
        fileName: 'photo.png',
        mimeType: 'image/png',
        type: MessageType.image,
      );

      final roomSnap =
          await fakeDb.collection('chat_rooms').doc(_roomId).get();
      final roomData = roomSnap.data()!;

      expect(roomData['lastMessageType'], 'image');
      expect(roomData['lastSenderId'], _clientId);
      expect(roomData['lastMessageText'], '📷 Photo');
    });

    test('uses file preview text for file type', () async {
      await _seedRoom(fakeDb);

      await repo.sendAttachmentMessage(
        roomId: _roomId,
        senderId: _lawyerId,
        senderRole: UserRole.lawyer,
        recipientId: _clientId,
        bytes: Uint8List(200),
        fileName: 'tenancy_agreement.docx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        type: MessageType.file,
      );

      final roomSnap =
          await fakeDb.collection('chat_rooms').doc(_roomId).get();
      expect(
        roomSnap.data()!['lastMessageText'],
        '📎 tenancy_agreement.docx',
      );
    });

    test('increments recipient unreadCounts slot', () async {
      await _seedRoom(fakeDb);

      await repo.sendAttachmentMessage(
        roomId: _roomId,
        senderId: _clientId,
        senderRole: UserRole.client,
        recipientId: _lawyerId,
        bytes: Uint8List(64),
        fileName: 'img.jpg',
        mimeType: 'image/jpeg',
        type: MessageType.image,
      );

      final roomSnap =
          await fakeDb.collection('chat_rooms').doc(_roomId).get();
      final counts =
          Map<String, dynamic>.from(roomSnap.data()!['unreadCounts'] as Map);

      expect(counts[_lawyerId], 1);
      expect(counts[_clientId], 0);
    });
  });

  // ── Filename sanitization (via storage path) ────────────────────────────────

  group('sendAttachmentMessage — filename sanitization', () {
    test('replaces path-traversal characters in storage path', () async {
      await _seedRoom(fakeDb);

      await repo.sendAttachmentMessage(
        roomId: _roomId,
        senderId: _clientId,
        senderRole: UserRole.client,
        recipientId: _lawyerId,
        bytes: Uint8List(10),
        fileName: '../../../etc/passwd',
        mimeType: 'text/plain',
        type: MessageType.file,
      );

      final msgSnap = await fakeDb
          .collection('chat_rooms')
          .doc(_roomId)
          .collection('messages')
          .get();

      final path = msgSnap.docs.first.data()['attachmentStoragePath'] as String;
      // Must not contain literal slashes in the filename segment.
      final fileNameSegment = path.split('/').last;
      expect(fileNameSegment, isNot(contains('/')));
      expect(fileNameSegment, isNot(contains('..')));
    });
  });
}
