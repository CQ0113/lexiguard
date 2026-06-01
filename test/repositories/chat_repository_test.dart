import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lei_guard/models/user_model.dart' show UserRole;
import 'package:lei_guard/repositories/chat_repository.dart';

// ─── Fixtures ─────────────────────────────────────────────────────────────────

const _clientId = 'client_1';
const _lawyerId = 'lawyer_1';
const _roomId = 'case_1_lawyer_1';

/// Seed a chat room doc into fake Firestore.
Future<void> _seedRoom(
  FakeFirebaseFirestore db, {
  String roomId = _roomId,
  String clientId = _clientId,
  String lawyerId = _lawyerId,
  Map<String, int>? unreadCounts,
}) async {
  final room = ChatRoom(
    id: roomId,
    caseId: 'case_1',
    clientId: clientId,
    lawyerId: lawyerId,
    participants: [clientId, lawyerId],
    clientName: 'Lim Mei Ling',
    lawyerName: 'Ahmad Zaki',
    caseTitle: 'Property dispute',
    lastMessageText: '',
    lastMessageType: 'text',
    lastSenderId: '',
    createdAt: DateTime.utc(2026, 5, 1),
    unreadCounts: unreadCounts ?? {clientId: 0, lawyerId: 0},
  );
  await db.collection('chat_rooms').doc(roomId).set(room.toMap());
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late FakeFirebaseFirestore fakeDb;
  late ChatRepository repo;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    repo = ChatRepository(firestore: fakeDb);
  });

  // ── streamRoomsForUser ──────────────────────────────────────────────────────

  group('streamRoomsForUser', () {
    test('returns rooms where uid is a participant', () async {
      await _seedRoom(fakeDb);

      final stream = repo.streamRoomsForUser(_clientId);
      final rooms = await stream.first;

      expect(rooms.length, 1);
      expect(rooms.first.id, _roomId);
      expect(rooms.first.participants, contains(_clientId));
    });

    test('does not return rooms where uid is not a participant', () async {
      await _seedRoom(fakeDb, clientId: 'other_client', lawyerId: _lawyerId);

      final stream = repo.streamRoomsForUser(_clientId);
      final rooms = await stream.first;

      expect(rooms, isEmpty);
    });

    test('returns multiple rooms for the same user', () async {
      await _seedRoom(fakeDb, roomId: 'room_a');
      await _seedRoom(fakeDb, roomId: 'room_b');

      final stream = repo.streamRoomsForUser(_clientId);
      final rooms = await stream.first;

      expect(rooms.length, 2);
    });

    test('emits updated list when a new room is added', () async {
      final stream = repo.streamRoomsForUser(_clientId);

      // Collect two events: empty then one room.
      final eventsFuture = stream.take(2).toList();

      await _seedRoom(fakeDb);

      final events = await eventsFuture;
      expect(events[0], isEmpty);
      expect(events[1].length, 1);
    });
  });

  // ── streamMessages ──────────────────────────────────────────────────────────

  group('streamMessages', () {
    test('returns empty list when no messages exist', () async {
      final stream = repo.streamMessages(_roomId);
      final messages = await stream.first;
      expect(messages, isEmpty);
    });

    test('returns messages ordered newest-first', () async {
      await _seedRoom(fakeDb);

      // Write two messages directly so we control the order.
      final ref = fakeDb
          .collection('chat_rooms')
          .doc(_roomId)
          .collection('messages');
      await ref.doc('m1').set({
        'id': 'm1',
        'roomId': _roomId,
        'senderId': _clientId,
        'senderRole': 'client',
        'type': 'text',
        'text': 'First',
        'createdAt': DateTime.utc(2026, 5, 10, 9, 0),
      });
      await ref.doc('m2').set({
        'id': 'm2',
        'roomId': _roomId,
        'senderId': _lawyerId,
        'senderRole': 'lawyer',
        'type': 'text',
        'text': 'Second',
        'createdAt': DateTime.utc(2026, 5, 10, 9, 1),
      });

      final stream = repo.streamMessages(_roomId);
      final messages = await stream.first;

      // newest-first → m2 before m1
      expect(messages.length, 2);
      expect(messages.first.id, 'm2');
      expect(messages.last.id, 'm1');
    });
  });

  // ── sendTextMessage ─────────────────────────────────────────────────────────

  group('sendTextMessage', () {
    test('writes a message doc and updates the room atomically', () async {
      await _seedRoom(fakeDb);

      await repo.sendTextMessage(
        roomId: _roomId,
        senderId: _clientId,
        senderRole: UserRole.client,
        text: 'Hello lawyer',
        recipientId: _lawyerId,
      );

      // Verify message subcollection has one doc.
      final msgSnap = await fakeDb
          .collection('chat_rooms')
          .doc(_roomId)
          .collection('messages')
          .get();
      expect(msgSnap.docs.length, 1);

      final msgData = msgSnap.docs.first.data();
      expect(msgData['text'], 'Hello lawyer');
      expect(msgData['senderId'], _clientId);
      expect(msgData['senderRole'], 'client');
      expect(msgData['type'], 'text');

      // Verify room's lastMessage fields were updated.
      final roomSnap =
          await fakeDb.collection('chat_rooms').doc(_roomId).get();
      final roomData = roomSnap.data()!;
      expect(roomData['lastMessageText'], 'Hello lawyer');
      expect(roomData['lastMessageType'], 'text');
      expect(roomData['lastSenderId'], _clientId);
    });

    test('increments recipient unreadCounts slot', () async {
      await _seedRoom(
        fakeDb,
        unreadCounts: {_clientId: 0, _lawyerId: 0},
      );

      await repo.sendTextMessage(
        roomId: _roomId,
        senderId: _clientId,
        senderRole: UserRole.client,
        text: 'Hey',
        recipientId: _lawyerId,
      );

      final roomSnap =
          await fakeDb.collection('chat_rooms').doc(_roomId).get();
      final counts =
          Map<String, dynamic>.from(roomSnap.data()!['unreadCounts'] as Map);
      // Lawyer's slot incremented; client's stays at 0.
      expect(counts[_lawyerId], 1);
      expect(counts[_clientId], 0);
    });

    test('trims whitespace before writing', () async {
      await _seedRoom(fakeDb);

      await repo.sendTextMessage(
        roomId: _roomId,
        senderId: _clientId,
        senderRole: UserRole.client,
        text: '  trimmed  ',
        recipientId: _lawyerId,
      );

      final msgSnap = await fakeDb
          .collection('chat_rooms')
          .doc(_roomId)
          .collection('messages')
          .get();
      expect(msgSnap.docs.first.data()['text'], 'trimmed');
    });

    test('throws ArgumentError for empty text', () async {
      await _seedRoom(fakeDb);

      await expectLater(
        repo.sendTextMessage(
          roomId: _roomId,
          senderId: _clientId,
          senderRole: UserRole.client,
          text: '   ',
          recipientId: _lawyerId,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('multiple sends accumulate unread count', () async {
      await _seedRoom(fakeDb, unreadCounts: {_clientId: 0, _lawyerId: 0});

      for (var i = 0; i < 3; i++) {
        await repo.sendTextMessage(
          roomId: _roomId,
          senderId: _clientId,
          senderRole: UserRole.client,
          text: 'Message ${i + 1}',
          recipientId: _lawyerId,
        );
      }

      final roomSnap =
          await fakeDb.collection('chat_rooms').doc(_roomId).get();
      final counts =
          Map<String, dynamic>.from(roomSnap.data()!['unreadCounts'] as Map);
      expect(counts[_lawyerId], 3);
    });
  });

  // ── markRoomRead ────────────────────────────────────────────────────────────

  group('markRoomRead', () {
    test('zeroes the caller uid slot and leaves the other untouched', () async {
      await _seedRoom(
        fakeDb,
        unreadCounts: {_clientId: 5, _lawyerId: 2},
      );

      await repo.markRoomRead(_roomId, _clientId);

      final roomSnap =
          await fakeDb.collection('chat_rooms').doc(_roomId).get();
      final counts =
          Map<String, dynamic>.from(roomSnap.data()!['unreadCounts'] as Map);
      expect(counts[_clientId], 0);
      expect(counts[_lawyerId], 2); // untouched
    });

    test('is idempotent — zeroing an already-zero slot is a no-op', () async {
      await _seedRoom(fakeDb, unreadCounts: {_clientId: 0, _lawyerId: 0});

      // Should not throw.
      await expectLater(
        repo.markRoomRead(_roomId, _clientId),
        completes,
      );

      final roomSnap =
          await fakeDb.collection('chat_rooms').doc(_roomId).get();
      final counts =
          Map<String, dynamic>.from(roomSnap.data()!['unreadCounts'] as Map);
      expect(counts[_clientId], 0);
    });
  });
}
