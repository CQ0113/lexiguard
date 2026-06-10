import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_model.dart';

// ─── Status enum ─────────────────────────────────────────────────────────────

enum ConnectionRequestStatus { pending, approved, declined, withdrawn, expired }

extension ConnectionRequestStatusWire on ConnectionRequestStatus {
  /// Snake-case string written to / read from Firestore.
  String get wireValue {
    switch (this) {
      case ConnectionRequestStatus.pending:
        return 'pending';
      case ConnectionRequestStatus.approved:
        return 'approved';
      case ConnectionRequestStatus.declined:
        return 'declined';
      case ConnectionRequestStatus.withdrawn:
        return 'withdrawn';
      case ConnectionRequestStatus.expired:
        return 'expired';
    }
  }

  static ConnectionRequestStatus fromWire(String? value) {
    switch (value) {
      case 'pending':
        return ConnectionRequestStatus.pending;
      case 'approved':
        return ConnectionRequestStatus.approved;
      case 'declined':
        return ConnectionRequestStatus.declined;
      case 'withdrawn':
        return ConnectionRequestStatus.withdrawn;
      case 'expired':
        return ConnectionRequestStatus.expired;
      default:
        return ConnectionRequestStatus.pending;
    }
  }
}

// ─── Nested helper: LawyerSnapshot ───────────────────────────────────────────

/// Denormalized lawyer card — captured at EOI time so the client's pending-list
/// can render without N+1 reads against `lawyer_profiles`.
class LawyerSnapshot {
  final String name;
  final String? firmName;
  final String? avatarUrl;
  final String? specialization;
  final int? yearsExperience;
  final double? rating;
  final String? practiceState;
  final String? practiceCity;
  final List<String> languages;
  final double? hourlyRate;
  final String? barNumber;
  final String? jurisdiction;

  /// Stored as the raw wire string (e.g. `'auto_verified'`) for forward-compat.
  final String verificationStatus;

  const LawyerSnapshot({
    required this.name,
    this.firmName,
    this.avatarUrl,
    this.specialization,
    this.yearsExperience,
    this.rating,
    this.practiceState,
    this.practiceCity,
    this.languages = const [],
    this.hourlyRate,
    this.barNumber,
    this.jurisdiction,
    required this.verificationStatus,
  });

  factory LawyerSnapshot.fromMap(Map<String, dynamic> map) {
    return LawyerSnapshot(
      name: map['name']?.toString() ?? '',
      firmName: map['firmName']?.toString(),
      avatarUrl: map['avatarUrl']?.toString(),
      specialization: map['specialization']?.toString(),
      yearsExperience: _readInt(map['yearsExperience']),
      rating: _readDouble(map['rating']),
      practiceState: map['practiceState']?.toString(),
      practiceCity: map['practiceCity']?.toString(),
      languages: List<String>.from(map['languages'] as List? ?? []),
      hourlyRate: _readDouble(map['hourlyRate']),
      barNumber: map['barNumber']?.toString(),
      jurisdiction: map['jurisdiction']?.toString(),
      verificationStatus:
          map['verificationStatus']?.toString() ?? 'unsubmitted',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (firmName != null) 'firmName': firmName,
      if (avatarUrl != null) 'avatarUrl': avatarUrl,
      if (specialization != null) 'specialization': specialization,
      if (yearsExperience != null) 'yearsExperience': yearsExperience,
      if (rating != null) 'rating': rating,
      if (practiceState != null) 'practiceState': practiceState,
      if (practiceCity != null) 'practiceCity': practiceCity,
      'languages': languages,
      if (hourlyRate != null) 'hourlyRate': hourlyRate,
      if (barNumber != null) 'barNumber': barNumber,
      if (jurisdiction != null) 'jurisdiction': jurisdiction,
      'verificationStatus': verificationStatus,
    };
  }

  /// Build a snapshot from a live [UserModel] at send-time.
  factory LawyerSnapshot.fromUser(UserModel user) {
    return LawyerSnapshot(
      name: user.legalFullName ?? user.name,
      firmName: user.firmName,
      avatarUrl: user.avatarUrl,
      specialization: user.specialization,
      yearsExperience: user.yearsExperience,
      rating: user.rating,
      practiceState: user.practiceState,
      practiceCity: user.practiceCity,
      languages: user.languages,
      hourlyRate: user.hourlyRate,
      barNumber: user.barNumber,
      jurisdiction: user.jurisdiction,
      verificationStatus: user.verificationStatus.wireValue,
    );
  }

  static double? _readDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}

// ─── Nested helper: ClientReveal ─────────────────────────────────────────────

/// Written to the request doc on `approve` — gives the approved lawyer access
/// to the client's contact info without exposing the full user document.
class ClientReveal {
  final String name;
  final String? email;
  final String? phone;

  const ClientReveal({required this.name, this.email, this.phone});

  factory ClientReveal.fromMap(Map<String, dynamic> map) {
    return ClientReveal(
      name: map['name']?.toString() ?? '',
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      if (email != null) 'email': email,
      if (phone != null) 'phone': phone,
    };
  }

  /// Build a reveal block from the client's [UserModel].
  factory ClientReveal.fromUser(UserModel user) {
    return ClientReveal(
      name: user.name,
      email: user.email.isNotEmpty ? user.email : null,
      phone: user.phone.isNotEmpty ? user.phone : null,
    );
  }
}

// ─── Nested helper: CaseSnapshot ─────────────────────────────────────────────

/// Denormalized case summary captured when a client requests a recommended
/// lawyer, so the lawyer dashboard can render incoming requests cheaply.
class CaseSnapshot {
  final String title;
  final String category;
  final String? location;
  final String? budgetRange;
  final String urgency;

  const CaseSnapshot({
    required this.title,
    required this.category,
    this.location,
    this.budgetRange,
    required this.urgency,
  });

  factory CaseSnapshot.fromMap(Map<String, dynamic> map) {
    return CaseSnapshot(
      title: map['title']?.toString() ?? '',
      category: map['category']?.toString() ?? '',
      location: map['location']?.toString(),
      budgetRange: map['budgetRange']?.toString(),
      urgency: map['urgency']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'category': category,
      if (location != null) 'location': location,
      if (budgetRange != null) 'budgetRange': budgetRange,
      'urgency': urgency,
    };
  }
}

// ─── Main model ───────────────────────────────────────────────────────────────

class ConnectionRequestModel {
  final String id;
  final String caseId;
  final String clientId;
  final String lawyerId;
  final String message;
  final ConnectionRequestStatus status;
  final String initiatedByRole;
  final String requestDirection;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? respondedAt;
  final String? declineReason;
  final LawyerSnapshot lawyerSnapshot;
  final CaseSnapshot? caseSnapshot;

  /// `null` until the client approves the request.
  final ClientReveal? clientReveal;

  const ConnectionRequestModel({
    required this.id,
    required this.caseId,
    required this.clientId,
    required this.lawyerId,
    required this.message,
    required this.status,
    this.initiatedByRole = 'lawyer',
    this.requestDirection = 'lawyer_to_client',
    required this.createdAt,
    required this.updatedAt,
    this.respondedAt,
    this.declineReason,
    required this.lawyerSnapshot,
    this.caseSnapshot,
    this.clientReveal,
  });

  // ── Firestore deserialization ───────────────────────────────────────────────

  factory ConnectionRequestModel.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      throw StateError('ConnectionRequest document ${doc.id} has no data.');
    }
    final data = Map<String, dynamic>.from(raw as Map);
    data.putIfAbsent('id', () => doc.id);
    return ConnectionRequestModel._fromMap(data);
  }

  factory ConnectionRequestModel._fromMap(Map<String, dynamic> map) {
    final snapshotRaw = map['lawyerSnapshot'];
    final lawyerSnapshot = snapshotRaw is Map
        ? LawyerSnapshot.fromMap(Map<String, dynamic>.from(snapshotRaw))
        : const LawyerSnapshot(name: '', verificationStatus: 'unsubmitted');

    final revealRaw = map['clientReveal'];
    final clientReveal = revealRaw is Map
        ? ClientReveal.fromMap(Map<String, dynamic>.from(revealRaw))
        : null;

    final caseSnapshotRaw = map['caseSnapshot'];
    final caseSnapshot = caseSnapshotRaw is Map
        ? CaseSnapshot.fromMap(Map<String, dynamic>.from(caseSnapshotRaw))
        : null;

    return ConnectionRequestModel(
      id: map['id']?.toString() ?? '',
      caseId: map['caseId']?.toString() ?? '',
      clientId: map['clientId']?.toString() ?? '',
      lawyerId: map['lawyerId']?.toString() ?? '',
      message: map['message']?.toString() ?? '',
      status: ConnectionRequestStatusWire.fromWire(map['status']?.toString()),
      initiatedByRole: map['initiatedByRole']?.toString() ?? 'lawyer',
      requestDirection:
          map['requestDirection']?.toString() ?? 'lawyer_to_client',
      createdAt:
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          _readDateTime(map['updatedAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      respondedAt: _readDateTime(map['respondedAt']),
      declineReason: map['declineReason']?.toString(),
      lawyerSnapshot: lawyerSnapshot,
      caseSnapshot: caseSnapshot,
      clientReveal: clientReveal,
    );
  }

  // ── Firestore serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'caseId': caseId,
      'clientId': clientId,
      'lawyerId': lawyerId,
      'message': message,
      'status': status.wireValue,
      'initiatedByRole': initiatedByRole,
      'requestDirection': requestDirection,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      if (respondedAt != null) 'respondedAt': Timestamp.fromDate(respondedAt!),
      if (declineReason != null) 'declineReason': declineReason,
      'lawyerSnapshot': lawyerSnapshot.toMap(),
      if (caseSnapshot != null) 'caseSnapshot': caseSnapshot!.toMap(),
      if (clientReveal != null) 'clientReveal': clientReveal!.toMap(),
    };
  }

  // ── copyWith — used in transactions ─────────────────────────────────────────

  ConnectionRequestModel copyWith({
    String? id,
    String? caseId,
    String? clientId,
    String? lawyerId,
    String? message,
    ConnectionRequestStatus? status,
    String? initiatedByRole,
    String? requestDirection,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? respondedAt,
    String? declineReason,
    LawyerSnapshot? lawyerSnapshot,
    CaseSnapshot? caseSnapshot,
    ClientReveal? clientReveal,
    bool clearRespondedAt = false,
    bool clearDeclineReason = false,
    bool clearClientReveal = false,
  }) {
    return ConnectionRequestModel(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      clientId: clientId ?? this.clientId,
      lawyerId: lawyerId ?? this.lawyerId,
      message: message ?? this.message,
      status: status ?? this.status,
      initiatedByRole: initiatedByRole ?? this.initiatedByRole,
      requestDirection: requestDirection ?? this.requestDirection,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      respondedAt: clearRespondedAt ? null : (respondedAt ?? this.respondedAt),
      declineReason: clearDeclineReason
          ? null
          : (declineReason ?? this.declineReason),
      lawyerSnapshot: lawyerSnapshot ?? this.lawyerSnapshot,
      caseSnapshot: caseSnapshot ?? this.caseSnapshot,
      clientReveal: clearClientReveal
          ? null
          : (clientReveal ?? this.clientReveal),
    );
  }

  bool get isClientInitiated =>
      initiatedByRole == 'client' || requestDirection == 'client_to_lawyer';

  bool get isLawyerInitiated => !isClientInitiated;

  // ── Private date helper (mirrors CaseModel._readDateTime) ──────────────────

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
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
    }
    try {
      final dynamic d = value.toDate();
      if (d is DateTime) return d;
    } catch (_) {}
    return null;
  }
}

// ─── Typed exceptions ─────────────────────────────────────────────────────────

/// Thrown when a non-terminal request already exists for this lawyer+case pair.
class DuplicateRequestException implements Exception {
  final ConnectionRequestStatus existingStatus;
  const DuplicateRequestException(this.existingStatus);

  @override
  String toString() =>
      'DuplicateRequestException: request already exists with status '
      '${existingStatus.wireValue}';
}

/// Thrown when the lawyer tries to re-send after a `declined` request.
/// Per plan §7, declined is terminal — no re-requests allowed.
class RequestDeclinedException implements Exception {
  const RequestDeclinedException();

  @override
  String toString() =>
      'RequestDeclinedException: this request was declined and cannot be re-sent';
}

/// Thrown when [sendRequest] is called but the case already has an assigned lawyer.
class CaseAlreadyConnectedException implements Exception {
  const CaseAlreadyConnectedException();

  @override
  String toString() =>
      'CaseAlreadyConnectedException: this case already has an assigned lawyer';
}

/// Thrown when [sendRequest] is called with a lawyer who is not yet verified.
class LawyerNotVerifiedException implements Exception {
  const LawyerNotVerifiedException();

  @override
  String toString() =>
      'LawyerNotVerifiedException: lawyer must be auto_verified to send requests';
}

/// Thrown when a status transition is not permitted by the workflow.
class InvalidStatusTransitionException implements Exception {
  final ConnectionRequestStatus from;
  final ConnectionRequestStatus to;
  const InvalidStatusTransitionException(this.from, this.to);

  @override
  String toString() =>
      'InvalidStatusTransitionException: cannot transition from '
      '${from.wireValue} to ${to.wireValue}';
}

/// Thrown when the EOI message length is outside [50, 500].
class MessageLengthException implements Exception {
  final int length;
  const MessageLengthException(this.length);

  @override
  String toString() =>
      'MessageLengthException: message length $length is outside [50, 500]';
}
