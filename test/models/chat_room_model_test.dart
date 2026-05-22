import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lei_guard/models/chat_room_model.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Writes [data] to fake Firestore and returns its [DocumentSnapshot].
Future<DocumentSnapshot> _writeAndRead(
  FakeFirebaseFirestore fakeDb,
  Map<String, dynamic> data,
) async {
  final ref = fakeDb.collection('chat_rooms').doc('room1');
  await ref.set(data);
  return ref.get();
}

ChatRoom _makeRoom({
  String id = 'case_1_lawyer_1',
  String lastMessageText = '',
  DateTime? lastMessageAt,
  Map<String, int>? unreadCounts,
}) {
  return ChatRoom(
    id: id,
    caseId: 'case_1',
    clientId: 'client_1',
    lawyerId: 'lawyer_1',
    participants: const ['client_1', 'lawyer_1'],
    clientName: 'Lim Mei Ling',
    lawyerName: 'Ahmad Zaki',
    lawyerAvatarUrl: 'https://example.com/avatar.jpg',
    caseTitle: 'Property dispute',
    lastMessageText: lastMessageText,
    lastMessageType: 'text',
    lastSenderId: '',
    lastMessageAt: lastMessageAt,
    createdAt: DateTime.utc(2026, 5, 1),
    unreadCounts: unreadCounts ?? {'client_1': 0, 'lawyer_1': 0},
  );
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  // ── toMap / fromFirestore round-trip ────────────────────────────────────────

  group('ChatRoom toMap / fromFirestore round-trip', () {
    Future<ChatRoom> roundTrip(ChatRoom room) async {
      final snap = await _writeAndRead(fakeDb, room.toMap());
      return ChatRoom.fromFirestore(snap);
    }

    test('round-trips all required fields', () async {
      final room = _makeRoom();
      final restored = await roundTrip(room);

      expect(restored.id, room.id);
      expect(restored.caseId, room.caseId);
      expect(restored.clientId, room.clientId);
      expect(restored.lawyerId, room.lawyerId);
      expect(restored.participants, room.participants);
      expect(restored.clientName, room.clientName);
      expect(restored.lawyerName, room.lawyerName);
      expect(restored.lawyerAvatarUrl, room.lawyerAvatarUrl);
      expect(restored.caseTitle, room.caseTitle);
      expect(restored.lastMessageText, room.lastMessageText);
      expect(restored.lastMessageType, room.lastMessageType);
      expect(restored.lastSenderId, room.lastSenderId);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        room.createdAt.millisecondsSinceEpoch,
      );
      expect(restored.unreadCounts, room.unreadCounts);
    });

    test('round-trips lastMessageAt when set', () async {
      final at = DateTime.utc(2026, 5, 10, 12, 30);
      final room = _makeRoom(
        lastMessageText: 'Hello',
        lastMessageAt: at,
        unreadCounts: {'client_1': 1, 'lawyer_1': 0},
      );
      final restored = await roundTrip(room);

      expect(
        restored.lastMessageAt!.millisecondsSinceEpoch,
        at.millisecondsSinceEpoch,
      );
      expect(restored.lastMessageText, 'Hello');
      expect(restored.unreadCounts['client_1'], 1);
      expect(restored.unreadCounts['lawyer_1'], 0);
    });

    test('lastMessageAt is null when absent', () async {
      final room = _makeRoom();
      // Explicitly omit lastMessageAt from the stored map.
      final data = room.toMap()..remove('lastMessageAt');
      final snap = await _writeAndRead(fakeDb, data);
      final restored = ChatRoom.fromFirestore(snap);

      expect(restored.lastMessageAt, isNull);
    });

    test('lawyerAvatarUrl is null when absent', () async {
      final room = ChatRoom(
        id: 'r2',
        caseId: 'c2',
        clientId: 'cl2',
        lawyerId: 'l2',
        participants: const ['cl2', 'l2'],
        clientName: 'Client',
        lawyerName: 'Lawyer',
        caseTitle: 'Dispute',
        lastMessageText: '',
        lastMessageType: 'text',
        lastSenderId: '',
        createdAt: DateTime.utc(2026, 5, 1),
        unreadCounts: const {'cl2': 0, 'l2': 0},
      );
      final snap = await _writeAndRead(fakeDb, room.toMap());
      final restored = ChatRoom.fromFirestore(snap);

      expect(restored.lawyerAvatarUrl, isNull);
    });

    test('missing fields fall back gracefully', () async {
      // Write a minimal document — simulates old data without all fields.
      final snap = await _writeAndRead(fakeDb, {
        'caseId': 'c3',
        'clientId': 'cl3',
        'lawyerId': 'l3',
      });
      final restored = ChatRoom.fromFirestore(snap);

      expect(restored.participants, isEmpty);
      expect(restored.clientName, '');
      expect(restored.lawyerName, '');
      expect(restored.caseTitle, '');
      expect(restored.unreadCounts, isEmpty);
      expect(restored.lastMessageAt, isNull);
    });
  });

  // ── copyWith ────────────────────────────────────────────────────────────────

  group('ChatRoom.copyWith', () {
    test('copyWith updates only specified fields', () {
      final room = _makeRoom();
      final updated = room.copyWith(lastMessageText: 'Updated msg');

      expect(updated.lastMessageText, 'Updated msg');
      expect(updated.caseId, room.caseId);     // unchanged
      expect(updated.clientName, room.clientName); // unchanged
    });

    test('copyWith updates unreadCounts independently', () {
      final room = _makeRoom(unreadCounts: {'client_1': 0, 'lawyer_1': 0});
      final updated = room.copyWith(
        unreadCounts: {'client_1': 3, 'lawyer_1': 0},
      );

      expect(updated.unreadCounts['client_1'], 3);
      expect(updated.unreadCounts['lawyer_1'], 0);
    });

    test('clearLastMessageAt sets it to null', () {
      final at = DateTime.utc(2026, 5, 10);
      final room = _makeRoom(lastMessageAt: at);
      expect(room.lastMessageAt, isNotNull);

      final cleared = room.copyWith(clearLastMessageAt: true);
      expect(cleared.lastMessageAt, isNull);
    });

    test('clearLawyerAvatarUrl sets it to null', () {
      final room = _makeRoom();
      expect(room.lawyerAvatarUrl, isNotNull);

      final cleared = room.copyWith(clearLawyerAvatarUrl: true);
      expect(cleared.lawyerAvatarUrl, isNull);
    });

    test('copyWith with no arguments returns equivalent room', () {
      final room = _makeRoom();
      final copy = room.copyWith();

      expect(copy.id, room.id);
      expect(copy.caseId, room.caseId);
      expect(copy.participants, room.participants);
      expect(copy.unreadCounts, room.unreadCounts);
    });
  });
}
