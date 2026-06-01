import 'package:cloud_firestore/cloud_firestore.dart';

// ─── ChatRoom model ───────────────────────────────────────────────────────────
//
// Firestore path: chat_rooms/{roomId}
// roomId == "${caseId}_${lawyerId}" — matches connection_requests doc ID.
//
// Created atomically inside ConnectionRequestRepository.approveRequest so that
// a room always exists once a request is approved. Fields are denormalized at
// creation time to avoid N+1 reads on the chat list screen.

class ChatRoom {
  final String id;
  final String caseId;
  final String clientId;
  final String lawyerId;

  /// Both participant UIDs — `[clientId, lawyerId]`. Used for arrayContains
  /// queries and Firestore security-rule participant checks.
  final List<String> participants;

  // ── Denormalized display fields ─────────────────────────────────────────────
  final String clientName;
  final String lawyerName;
  final String? lawyerAvatarUrl;

  /// Case title copied at creation time so the list screen needs no extra read.
  final String caseTitle;

  // ── Last-message preview ────────────────────────────────────────────────────
  final String lastMessageText;

  /// Wire value: `'text'`, `'image'`, or `'file'`.
  final String lastMessageType;

  final String lastSenderId;

  /// `null` when the room is brand-new and no message has been sent yet.
  final DateTime? lastMessageAt;

  // ── Timestamps ──────────────────────────────────────────────────────────────
  final DateTime createdAt;

  // ── Unread counters — map keyed by UID ─────────────────────────────────────
  /// `{ "<clientId>": n, "<lawyerId>": m }`.
  final Map<String, int> unreadCounts;

  const ChatRoom({
    required this.id,
    required this.caseId,
    required this.clientId,
    required this.lawyerId,
    required this.participants,
    required this.clientName,
    required this.lawyerName,
    this.lawyerAvatarUrl,
    required this.caseTitle,
    required this.lastMessageText,
    required this.lastMessageType,
    required this.lastSenderId,
    this.lastMessageAt,
    required this.createdAt,
    required this.unreadCounts,
  });

  // ── Firestore deserialization ───────────────────────────────────────────────

  factory ChatRoom.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      throw StateError('ChatRoom document ${doc.id} has no data.');
    }
    final data = Map<String, dynamic>.from(raw as Map);
    data.putIfAbsent('id', () => doc.id);
    return ChatRoom._fromMap(data);
  }

  factory ChatRoom.fromMap(String id, Map<String, dynamic> map) {
    final data = Map<String, dynamic>.from(map);
    data['id'] = id;
    return ChatRoom._fromMap(data);
  }

  factory ChatRoom._fromMap(Map<String, dynamic> map) {
    final participantsRaw = map['participants'];
    final participants = participantsRaw is List
        ? List<String>.from(participantsRaw.map((e) => e.toString()))
        : <String>[];

    final countsRaw = map['unreadCounts'];
    final unreadCounts = countsRaw is Map
        ? Map<String, int>.from(
            countsRaw.map(
              (k, v) => MapEntry(k.toString(), _readInt(v) ?? 0),
            ),
          )
        : <String, int>{};

    return ChatRoom(
      id: map['id']?.toString() ?? '',
      caseId: map['caseId']?.toString() ?? '',
      clientId: map['clientId']?.toString() ?? '',
      lawyerId: map['lawyerId']?.toString() ?? '',
      participants: participants,
      clientName: map['clientName']?.toString() ?? '',
      lawyerName: map['lawyerName']?.toString() ?? '',
      lawyerAvatarUrl: map['lawyerAvatarUrl']?.toString(),
      caseTitle: map['caseTitle']?.toString() ?? '',
      lastMessageText: map['lastMessageText']?.toString() ?? '',
      lastMessageType: map['lastMessageType']?.toString() ?? 'text',
      lastSenderId: map['lastSenderId']?.toString() ?? '',
      lastMessageAt: _readDateTime(map['lastMessageAt']),
      createdAt:
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      unreadCounts: unreadCounts,
    );
  }

  // ── Firestore serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'caseId': caseId,
      'clientId': clientId,
      'lawyerId': lawyerId,
      'participants': participants,
      'clientName': clientName,
      'lawyerName': lawyerName,
      if (lawyerAvatarUrl != null) 'lawyerAvatarUrl': lawyerAvatarUrl,
      'caseTitle': caseTitle,
      'lastMessageText': lastMessageText,
      'lastMessageType': lastMessageType,
      'lastSenderId': lastSenderId,
      if (lastMessageAt != null)
        'lastMessageAt': Timestamp.fromDate(lastMessageAt!),
      'createdAt': Timestamp.fromDate(createdAt),
      'unreadCounts': unreadCounts,
    };
  }

  // ── copyWith — used in optimistic local state updates ───────────────────────

  ChatRoom copyWith({
    String? id,
    String? caseId,
    String? clientId,
    String? lawyerId,
    List<String>? participants,
    String? clientName,
    String? lawyerName,
    String? lawyerAvatarUrl,
    String? caseTitle,
    String? lastMessageText,
    String? lastMessageType,
    String? lastSenderId,
    DateTime? lastMessageAt,
    DateTime? createdAt,
    Map<String, int>? unreadCounts,
    bool clearLastMessageAt = false,
    bool clearLawyerAvatarUrl = false,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      caseId: caseId ?? this.caseId,
      clientId: clientId ?? this.clientId,
      lawyerId: lawyerId ?? this.lawyerId,
      participants: participants ?? this.participants,
      clientName: clientName ?? this.clientName,
      lawyerName: lawyerName ?? this.lawyerName,
      lawyerAvatarUrl: clearLawyerAvatarUrl
          ? null
          : (lawyerAvatarUrl ?? this.lawyerAvatarUrl),
      caseTitle: caseTitle ?? this.caseTitle,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageType: lastMessageType ?? this.lastMessageType,
      lastSenderId: lastSenderId ?? this.lastSenderId,
      lastMessageAt:
          clearLastMessageAt ? null : (lastMessageAt ?? this.lastMessageAt),
      createdAt: createdAt ?? this.createdAt,
      unreadCounts: unreadCounts ?? this.unreadCounts,
    );
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

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

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
