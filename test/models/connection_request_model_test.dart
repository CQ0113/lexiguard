import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lei_guard/models/connection_request_model.dart';
import 'package:lei_guard/models/user_model.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

UserModel _verifiedLawyer({String id = 'lawyer_1'}) {
  return UserModel(
    id: id,
    name: 'Ahmad Zaki',
    email: 'zaki@lawfirm.my',
    phone: '+60123456789',
    role: UserRole.lawyer,
    avatarUrl: 'https://example.com/avatar.jpg',
    barNumber: 'B/MY/12345',
    specialization: 'Property Law',
    firmName: 'Zaki & Partners',
    jurisdiction: 'peninsular',
    yearsExperience: 8,
    rating: 4.7,
    verificationStatus: VerificationStatus.autoVerified,
    legalFullName: 'Ahmad Zaki bin Ibrahim',
  );
}

/// Write a document to a fake Firestore and return its [DocumentSnapshot].
Future<DocumentSnapshot> _writeAndRead(
  FakeFirebaseFirestore fakeDb,
  Map<String, dynamic> data,
) async {
  final ref = fakeDb.collection('connection_requests').doc('doc1');
  await ref.set(data);
  return ref.get();
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late FakeFirebaseFirestore fakeDb;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
  });

  // ── Status enum serialization ──────────────────────────────────────────────

  group('ConnectionRequestStatus wire values', () {
    test('each enum value round-trips through wire format', () {
      final cases = {
        ConnectionRequestStatus.pending: 'pending',
        ConnectionRequestStatus.approved: 'approved',
        ConnectionRequestStatus.declined: 'declined',
        ConnectionRequestStatus.withdrawn: 'withdrawn',
        ConnectionRequestStatus.expired: 'expired',
      };

      for (final entry in cases.entries) {
        expect(entry.key.wireValue, entry.value,
            reason: 'wireValue for ${entry.key}');
        expect(
          ConnectionRequestStatusWire.fromWire(entry.value),
          entry.key,
          reason: 'fromWire for ${entry.value}',
        );
      }
    });

    test('fromWire falls back to pending for unknown string', () {
      expect(
        ConnectionRequestStatusWire.fromWire('bogus'),
        ConnectionRequestStatus.pending,
      );
      expect(
        ConnectionRequestStatusWire.fromWire(null),
        ConnectionRequestStatus.pending,
      );
    });
  });

  // ── LawyerSnapshot.fromUser ────────────────────────────────────────────────

  group('LawyerSnapshot.fromUser', () {
    test('extracts all lawyer fields from a fully-populated UserModel', () {
      final lawyer = _verifiedLawyer();
      final snap = LawyerSnapshot.fromUser(lawyer);

      // Uses legalFullName when available
      expect(snap.name, 'Ahmad Zaki bin Ibrahim');
      expect(snap.firmName, 'Zaki & Partners');
      expect(snap.avatarUrl, 'https://example.com/avatar.jpg');
      expect(snap.specialization, 'Property Law');
      expect(snap.yearsExperience, 8);
      expect(snap.rating, 4.7);
      expect(snap.barNumber, 'B/MY/12345');
      expect(snap.jurisdiction, 'peninsular');
      expect(snap.verificationStatus, 'auto_verified');
    });

    test('falls back to name when legalFullName is null', () {
      const lawyer = UserModel(
        id: 'l2',
        name: 'Tan Wei',
        email: 'tan@law.my',
        phone: '+60111111111',
        role: UserRole.lawyer,
        verificationStatus: VerificationStatus.autoVerified,
      );
      final snap = LawyerSnapshot.fromUser(lawyer);
      expect(snap.name, 'Tan Wei');
    });

    test('toMap / fromMap round-trip preserves all fields', () {
      final lawyer = _verifiedLawyer();
      final original = LawyerSnapshot.fromUser(lawyer);
      final restored = LawyerSnapshot.fromMap(original.toMap());

      expect(restored.name, original.name);
      expect(restored.firmName, original.firmName);
      expect(restored.avatarUrl, original.avatarUrl);
      expect(restored.specialization, original.specialization);
      expect(restored.yearsExperience, original.yearsExperience);
      expect(restored.rating, original.rating);
      expect(restored.barNumber, original.barNumber);
      expect(restored.jurisdiction, original.jurisdiction);
      expect(restored.verificationStatus, original.verificationStatus);
    });
  });

  // ── ClientReveal.fromUser ──────────────────────────────────────────────────

  group('ClientReveal.fromUser', () {
    test('extracts name, email, and phone from client UserModel', () {
      const client = UserModel(
        id: 'client_1',
        name: 'Lim Mei Ling',
        email: 'mei@gmail.com',
        phone: '+60198765432',
        role: UserRole.client,
      );
      final reveal = ClientReveal.fromUser(client);

      expect(reveal.name, 'Lim Mei Ling');
      expect(reveal.email, 'mei@gmail.com');
      expect(reveal.phone, '+60198765432');
    });

    test('email and phone are null when empty strings', () {
      const client = UserModel(
        id: 'client_2',
        name: 'Anonymous Client',
        email: '',
        phone: '',
        role: UserRole.client,
      );
      final reveal = ClientReveal.fromUser(client);

      expect(reveal.email, isNull);
      expect(reveal.phone, isNull);
    });

    test('toMap / fromMap round-trip preserves all fields', () {
      const original = ClientReveal(
        name: 'Lim Mei',
        email: 'mei@x.com',
        phone: '+60111',
      );
      final restored = ClientReveal.fromMap(original.toMap());

      expect(restored.name, 'Lim Mei');
      expect(restored.email, 'mei@x.com');
      expect(restored.phone, '+60111');
    });
  });

  // ── Model round-trip ───────────────────────────────────────────────────────

  group('ConnectionRequestModel fromFirestore / toFirestore round-trip', () {
    Future<ConnectionRequestModel> roundTrip(
      ConnectionRequestModel model,
    ) async {
      final snap = await _writeAndRead(fakeDb, model.toFirestore());
      return ConnectionRequestModel.fromFirestore(snap);
    }

    ConnectionRequestModel makeModel({
      ConnectionRequestStatus status = ConnectionRequestStatus.pending,
      DateTime? respondedAt,
      String? declineReason,
      ClientReveal? clientReveal,
    }) {
      return ConnectionRequestModel(
        id: 'case1_lawyer_1',
        caseId: 'case1',
        clientId: 'client_1',
        lawyerId: 'lawyer_1',
        message: 'I can help with your property dispute matter.',
        status: status,
        createdAt: DateTime.utc(2026, 5, 1, 9, 0),
        updatedAt: DateTime.utc(2026, 5, 1, 9, 0),
        respondedAt: respondedAt,
        declineReason: declineReason,
        lawyerSnapshot: LawyerSnapshot.fromUser(_verifiedLawyer()),
        clientReveal: clientReveal,
      );
    }

    test('round-trips all required fields (no optionals)', () async {
      final model = makeModel();
      final restored = await roundTrip(model);

      expect(restored.id, model.id);
      expect(restored.caseId, model.caseId);
      expect(restored.clientId, model.clientId);
      expect(restored.lawyerId, model.lawyerId);
      expect(restored.message, model.message);
      expect(restored.status, model.status);
      expect(
        restored.createdAt.millisecondsSinceEpoch,
        model.createdAt.millisecondsSinceEpoch,
      );
      expect(
        restored.updatedAt.millisecondsSinceEpoch,
        model.updatedAt.millisecondsSinceEpoch,
      );
      expect(restored.respondedAt, isNull);
      expect(restored.declineReason, isNull);
      expect(restored.clientReveal, isNull);
    });

    test('round-trips respondedAt and declineReason when set', () async {
      final responded = DateTime.utc(2026, 5, 2, 10, 30);
      final model = makeModel(
        status: ConnectionRequestStatus.declined,
        respondedAt: responded,
        declineReason: 'Not a fit',
      );
      final restored = await roundTrip(model);

      expect(restored.status, ConnectionRequestStatus.declined);
      expect(
        restored.respondedAt!.millisecondsSinceEpoch,
        responded.millisecondsSinceEpoch,
      );
      expect(restored.declineReason, 'Not a fit');
    });

    test('round-trips clientReveal when present (approved)', () async {
      const reveal = ClientReveal(
        name: 'Lim Mei',
        email: 'mei@x.my',
        phone: '+601234',
      );
      final model = makeModel(
        status: ConnectionRequestStatus.approved,
        respondedAt: DateTime.utc(2026, 5, 3),
        clientReveal: reveal,
      );
      final restored = await roundTrip(model);

      expect(restored.status, ConnectionRequestStatus.approved);
      expect(restored.clientReveal, isNotNull);
      expect(restored.clientReveal!.name, 'Lim Mei');
      expect(restored.clientReveal!.email, 'mei@x.my');
      expect(restored.clientReveal!.phone, '+601234');
    });

    test('round-trips lawyerSnapshot correctly', () async {
      final model = makeModel();
      final restored = await roundTrip(model);

      expect(restored.lawyerSnapshot.name, 'Ahmad Zaki bin Ibrahim');
      expect(restored.lawyerSnapshot.firmName, 'Zaki & Partners');
      expect(restored.lawyerSnapshot.barNumber, 'B/MY/12345');
      expect(restored.lawyerSnapshot.verificationStatus, 'auto_verified');
    });

    for (final status in ConnectionRequestStatus.values) {
      test('round-trips status: ${status.wireValue}', () async {
        final model = makeModel(status: status);
        final restored = await roundTrip(model);
        expect(restored.status, status);
      });
    }
  });

  // ── copyWith ───────────────────────────────────────────────────────────────

  group('ConnectionRequestModel.copyWith', () {
    test('copyWith updates status and updatedAt', () {
      final base = ConnectionRequestModel(
        id: 'x',
        caseId: 'c',
        clientId: 'cl',
        lawyerId: 'l',
        message: 'msg ' * 10,
        status: ConnectionRequestStatus.pending,
        createdAt: DateTime.utc(2026, 5, 1),
        updatedAt: DateTime.utc(2026, 5, 1),
        lawyerSnapshot: const LawyerSnapshot(
          name: 'Lawyer',
          verificationStatus: 'auto_verified',
        ),
      );

      final now = DateTime.utc(2026, 5, 2);
      final updated = base.copyWith(
        status: ConnectionRequestStatus.withdrawn,
        updatedAt: now,
      );

      expect(updated.status, ConnectionRequestStatus.withdrawn);
      expect(updated.updatedAt, now);
      expect(updated.caseId, 'c'); // unchanged
    });

    test('clearRespondedAt sets it to null', () {
      final base = ConnectionRequestModel(
        id: 'x',
        caseId: 'c',
        clientId: 'cl',
        lawyerId: 'l',
        message: 'msg ' * 10,
        status: ConnectionRequestStatus.declined,
        createdAt: DateTime.utc(2026, 5, 1),
        updatedAt: DateTime.utc(2026, 5, 1),
        respondedAt: DateTime.utc(2026, 5, 2),
        lawyerSnapshot: const LawyerSnapshot(
          name: 'Lawyer',
          verificationStatus: 'auto_verified',
        ),
      );

      final updated = base.copyWith(clearRespondedAt: true);
      expect(updated.respondedAt, isNull);
    });
  });
}
