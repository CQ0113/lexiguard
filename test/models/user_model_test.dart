import 'package:flutter_test/flutter_test.dart';
import 'package:lei_guard/models/user_model.dart';

class _FakeTimestamp {
  final DateTime value;
  const _FakeTimestamp(this.value);

  DateTime toDate() => value;
}

void main() {
  group('UserModel verification lifecycle', () {
    test('fromMap parses verificationStatus wire value', () {
      final user = UserModel.fromMap({
        'id': 'lawyer_100',
        'name': 'Test Lawyer',
        'email': 'lawyer@example.com',
        'phone': '+60000000000',
        'role': 'lawyer',
        'barCouncilVerified': false,
        'verificationStatus': 'manual_review_required',
      });

      expect(user.verificationStatus, VerificationStatus.manualReviewRequired);
      expect(user.canAccessMarketplace, isFalse);
    });

    test('fromMap falls back to legacy barCouncilVerified=true', () {
      final user = UserModel.fromMap({
        'id': 'lawyer_101',
        'name': 'Legacy Lawyer',
        'email': 'legacy@example.com',
        'phone': '+60000000001',
        'role': 'lawyer',
        'barCouncilVerified': true,
      });

      expect(user.verificationStatus, VerificationStatus.autoVerified);
      expect(user.canAccessMarketplace, isTrue);
      expect(user.isVerified, isTrue);
    });

    test('toMap writes verification wire field and legacy boolean', () {
      const user = UserModel(
        id: 'lawyer_102',
        name: 'Pending Lawyer',
        email: 'pending@example.com',
        phone: '+60000000002',
        role: UserRole.lawyer,
        verificationStatus: VerificationStatus.pending,
      );

      final map = user.toMap();

      expect(map['verificationStatus'], 'pending');
      expect(map['barCouncilVerified'], isFalse);
      expect(map['role'], 'lawyer');
    });

    test('fromMap parses timestamp-like and firestore map dates', () {
      final user = UserModel.fromMap({
        'id': 'lawyer_103',
        'name': 'Timestamp Lawyer',
        'email': 'time@example.com',
        'phone': '+60000000003',
        'role': 'lawyer',
        'createdAt': '2026-04-18T10:00:00.000Z',
        'verifiedAt': _FakeTimestamp(DateTime.utc(2026, 4, 18, 12, 0)),
        'lastVerifiedAt': '2026-04-18T12:00:00.000Z',
        'nextReverifyAt': {'_seconds': 1776484800, '_nanoseconds': 0},
      });

      expect(user.createdAt?.toUtc(), DateTime.utc(2026, 4, 18, 10, 0));
      expect(user.verifiedAt, DateTime.utc(2026, 4, 18, 12, 0));
      expect(user.lastVerifiedAt?.toUtc(), DateTime.utc(2026, 4, 18, 12, 0));
      expect(user.nextReverifyAt?.millisecondsSinceEpoch, 1776484800000);
    });

    test('toFirestore writes verification lifecycle fields', () {
      final user = UserModel(
        id: 'lawyer_104',
        name: 'Scaffold Lawyer',
        email: 'scaffold@example.com',
        phone: '+60000000004',
        role: UserRole.lawyer,
        barNumber: 'B/MY/12345',
        legalFullName: 'Scaffold Lawyer',
        firmName: 'Scaffold & Co',
        jurisdiction: 'sabah',
        practiceState: 'Sabah',
        practiceCity: 'Kota Kinabalu',
        verificationStatus: VerificationStatus.manualReviewRequired,
        verificationProvider: 'manual_review_sabah',
        verificationBadgeVisible: false,
        createdAt: DateTime.utc(2026, 4, 19, 0, 0),
        lastVerifiedAt: DateTime.utc(2026, 4, 19, 0, 5),
      );

      final firestoreMap = user.toFirestore();

      expect(
        firestoreMap['verificationStatus'],
        'manual_review_required',
      );
      expect(firestoreMap['verificationProvider'], 'manual_review_sabah');
      expect(firestoreMap['verificationBadgeVisible'], isFalse);
      expect(firestoreMap['legalFullName'], 'Scaffold Lawyer');
      expect(firestoreMap['firmName'], 'Scaffold & Co');
      expect(firestoreMap['jurisdiction'], 'sabah');
      expect(firestoreMap['barCouncilVerified'], isFalse);
      expect(firestoreMap.containsKey('createdAt'), isTrue);
      expect(firestoreMap.containsKey('lastVerifiedAt'), isTrue);
    });
  });
}
