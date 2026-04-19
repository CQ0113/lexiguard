import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { client, lawyer }

enum VerificationStatus {
  unsubmitted,
  pending,
  autoVerified,
  manualReviewRequired,
  rejected,
  reverificationDue,
  suspended,
}

extension VerificationStatusWire on VerificationStatus {
  String get wireValue {
    switch (this) {
      case VerificationStatus.unsubmitted:
        return 'unsubmitted';
      case VerificationStatus.pending:
        return 'pending';
      case VerificationStatus.autoVerified:
        return 'auto_verified';
      case VerificationStatus.manualReviewRequired:
        return 'manual_review_required';
      case VerificationStatus.rejected:
        return 'rejected';
      case VerificationStatus.reverificationDue:
        return 'reverification_due';
      case VerificationStatus.suspended:
        return 'suspended';
    }
  }

  String get label {
    switch (this) {
      case VerificationStatus.unsubmitted:
        return 'Unsubmitted';
      case VerificationStatus.pending:
        return 'Pending Verification';
      case VerificationStatus.autoVerified:
        return 'Verified Lawyer';
      case VerificationStatus.manualReviewRequired:
        return 'Manual Review Required';
      case VerificationStatus.rejected:
        return 'Verification Rejected';
      case VerificationStatus.reverificationDue:
        return 'Reverification Due';
      case VerificationStatus.suspended:
        return 'Suspended';
    }
  }
}

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final String? avatarUrl;
  final DateTime? createdAt;

  // Lawyer-specific fields
  final String? barNumber;
  final String? specialization;
  final double? hourlyRate;
  final double? rating;
  final int? yearsExperience;
  // Legacy single-flag field kept for backward compatibility.
  final bool? barCouncilVerified;
  final VerificationStatus verificationStatus;
  final String? verificationProvider;
  final DateTime? verifiedAt;
  final DateTime? lastVerifiedAt;
  final DateTime? nextReverifyAt;
  final bool verificationBadgeVisible;
  final String? legalFullName;
  final String? firmName;
  final String? jurisdiction;
  final String? practiceState;
  final String? practiceCity;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.avatarUrl,
    this.createdAt,
    // Lawyer fields
    this.barNumber,
    this.specialization,
    this.hourlyRate,
    this.rating,
    this.yearsExperience,
    this.barCouncilVerified,
    this.verificationStatus = VerificationStatus.unsubmitted,
    this.verificationProvider,
    this.verifiedAt,
    this.lastVerifiedAt,
    this.nextReverifyAt,
    this.verificationBadgeVisible = false,
    this.legalFullName,
    this.firmName,
    this.jurisdiction,
    this.practiceState,
    this.practiceCity,
  });

  // ─── Firestore Deserialization ───────────────────────────────────────────────

  factory UserModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return UserModel(
      id: doc.id,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      role: data['role'] == 'lawyer' ? UserRole.lawyer : UserRole.client,
      avatarUrl: data['avatarUrl'] as String?,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      barNumber: data['barNumber'] as String?,
      specialization: data['specialization'] as String?,
      hourlyRate: (data['hourlyRate'] as num?)?.toDouble(),
      rating: (data['rating'] as num?)?.toDouble(),
      yearsExperience: data['yearsExperience'] as int?,
      barCouncilVerified: data['barCouncilVerified'] as bool?,
    );
  }

  // ─── Firestore Serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role == UserRole.lawyer ? 'lawyer' : 'client',
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      'createdAt': FieldValue.serverTimestamp(),
      // Lawyer-only fields (only written if non-null)
      if (barNumber != null) 'barNumber': barNumber,
      if (specialization != null) 'specialization': specialization,
      if (hourlyRate != null) 'hourlyRate': hourlyRate,
      if (yearsExperience != null) 'yearsExperience': yearsExperience,
      if (barCouncilVerified != null) 'barCouncilVerified': barCouncilVerified,
    };
  }

  // ─── Legacy Map (kept for DummyData compatibility) ───────────────────────────

  factory UserModel.fromMap(Map<String, dynamic> map) {
    final legacyVerified = map['barCouncilVerified'] as bool?;
    final parsedStatus = _verificationStatusFromWire(
      map['verificationStatus'] as String?,
    );

    return UserModel(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String,
      phone: map['phone'] as String,
      role: map['role'] == 'lawyer' ? UserRole.lawyer : UserRole.client,
      avatarUrl: map['avatarUrl'] as String?,
      barNumber: map['barNumber'] as String?,
      specialization: map['specialization'] as String?,
      hourlyRate: (map['hourlyRate'] as num?)?.toDouble(),
      rating: (map['rating'] as num?)?.toDouble(),
      yearsExperience: map['yearsExperience'] as int?,
      barCouncilVerified: map['barCouncilVerified'] as bool?,
      verificationStatus:
          parsedStatus ??
          (legacyVerified == true
              ? VerificationStatus.autoVerified
              : VerificationStatus.unsubmitted),
      verificationProvider: map['verificationProvider'] as String?,
      verifiedAt: _readDateTime(map['verifiedAt']),
      lastVerifiedAt: _readDateTime(map['lastVerifiedAt']),
      nextReverifyAt: _readDateTime(map['nextReverifyAt']),
      verificationBadgeVisible:
          map['verificationBadgeVisible'] as bool? ?? (legacyVerified ?? false),
      legalFullName: map['legalFullName'] as String?,
      firmName: map['firmName'] as String?,
      jurisdiction: map['jurisdiction'] as String?,
      practiceState: map['practiceState'] as String?,
      practiceCity: map['practiceCity'] as String?,
    );
  }

  static VerificationStatus? _verificationStatusFromWire(String? value) {
    switch (value) {
      case 'unsubmitted':
        return VerificationStatus.unsubmitted;
      case 'pending':
        return VerificationStatus.pending;
      case 'auto_verified':
        return VerificationStatus.autoVerified;
      case 'manual_review_required':
        return VerificationStatus.manualReviewRequired;
      case 'rejected':
        return VerificationStatus.rejected;
      case 'reverification_due':
        return VerificationStatus.reverificationDue;
      case 'suspended':
        return VerificationStatus.suspended;
      default:
        return null;
    }
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) return value;

    if (value is String) {
      return DateTime.tryParse(value);
    }

    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(value.toInt());
    }

    if (value is Map) {
      final seconds = value['_seconds'] ?? value['seconds'];
      final nanoseconds = value['_nanoseconds'] ?? value['nanoseconds'] ?? 0;
      if (seconds is num) {
        final millis =
            seconds.toInt() * 1000 +
            ((nanoseconds is num ? nanoseconds.toInt() : 0) ~/ 1000000);
        return DateTime.fromMillisecondsSinceEpoch(millis);
      }

      final iso = value['iso'] ?? value['timestamp'];
      if (iso is String) {
        return DateTime.tryParse(iso);
      }
    }

    try {
      final dynamic dateValue = value.toDate();
      if (dateValue is DateTime) {
        return dateValue;
      }
    } catch (_) {
      // Ignore unsupported timestamp-like values.
    }

    return null;
  }

  // Convert to Firestore document — replace with:
  // Future<void> save() => FirebaseFirestore.instance.collection('users').doc(id).set(toMap());
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role == UserRole.lawyer ? 'lawyer' : 'client',
      'avatarUrl': avatarUrl,
      'barNumber': barNumber,
      'specialization': specialization,
      'hourlyRate': hourlyRate,
      'rating': rating,
      'yearsExperience': yearsExperience,
      'barCouncilVerified': barCouncilVerified ?? isVerified,
      'verificationStatus': verificationStatus.wireValue,
      'verificationProvider': verificationProvider,
      'verifiedAt': verifiedAt?.toIso8601String(),
      'lastVerifiedAt': lastVerifiedAt?.toIso8601String(),
      'nextReverifyAt': nextReverifyAt?.toIso8601String(),
      'verificationBadgeVisible': verificationBadgeVisible,
      'legalFullName': legalFullName,
      'firmName': firmName,
      'jurisdiction': jurisdiction,
      'practiceState': practiceState,
      'practiceCity': practiceCity,
    };
  }

  bool get isVerified => verificationStatus == VerificationStatus.autoVerified;

  bool get canAccessMarketplace => isVerified;

  bool get isPendingLike {
    return verificationStatus == VerificationStatus.pending ||
        verificationStatus == VerificationStatus.manualReviewRequired ||
        verificationStatus == VerificationStatus.reverificationDue;
  }
}
