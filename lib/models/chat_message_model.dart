import 'package:cloud_firestore/cloud_firestore.dart';

import 'user_model.dart' show UserRole;

// ─── MessageType enum ─────────────────────────────────────────────────────────

enum MessageType { text, image, file }

extension MessageTypeWire on MessageType {
  /// Snake-case string written to / read from Firestore.
  String get wireValue {
    switch (this) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.file:
        return 'file';
    }
  }

  static MessageType fromWire(String? value) {
    switch (value) {
      case 'image':
        return MessageType.image;
      case 'file':
        return MessageType.file;
      default:
        return MessageType.text;
    }
  }
}

// ─── ChatMessage model ────────────────────────────────────────────────────────
//
// Firestore path: chat_rooms/{roomId}/messages/{messageId}
// Append-only — no edit or delete in rules.

class ChatMessage {
  final String id;
  final String roomId;
  final String senderId;

  /// `client` or `lawyer` — stored via [UserRole.wireValue] so the value is
  /// a Firestore-friendly string without depending on enum ordinals.
  final UserRole senderRole;

  final MessageType type;

  /// `null` for non-text messages.
  final String? text;

  // ── Attachment fields — only populated for image/file messages ──────────────

  /// The authoritative Storage reference.
  /// Path: `chat_attachments/{roomId}/{messageId}_{originalFilename}`.
  final String? attachmentStoragePath;

  /// Convenience download URL — populated at upload time and lazily re-issued
  /// if it expires. Do not use as the sole reference.
  final String? attachmentDownloadUrl;

  final String? attachmentName;

  /// Size in bytes.
  final int? attachmentSize;

  final String? mimeType;

  final DateTime createdAt;

  final DateTime? expiresAt;

  const ChatMessage({
    required this.id,
    required this.roomId,
    required this.senderId,
    required this.senderRole,
    required this.type,
    this.text,
    this.attachmentStoragePath,
    this.attachmentDownloadUrl,
    this.attachmentName,
    this.attachmentSize,
    this.mimeType,
    required this.createdAt,
    this.expiresAt,
  });

  // ── Firestore deserialization ───────────────────────────────────────────────

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data();
    if (raw == null) {
      throw StateError('ChatMessage document ${doc.id} has no data.');
    }
    final data = Map<String, dynamic>.from(raw as Map);
    data.putIfAbsent('id', () => doc.id);
    return ChatMessage._fromMap(data);
  }

  factory ChatMessage._fromMap(Map<String, dynamic> map) {
    final roleWire = map['senderRole']?.toString();
    final senderRole =
        roleWire == 'lawyer' ? UserRole.lawyer : UserRole.client;

    return ChatMessage(
      id: map['id']?.toString() ?? '',
      roomId: map['roomId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      senderRole: senderRole,
      type: MessageTypeWire.fromWire(map['type']?.toString()),
      text: map['text']?.toString(),
      attachmentStoragePath: map['attachmentStoragePath']?.toString(),
      attachmentDownloadUrl: map['attachmentDownloadUrl']?.toString(),
      attachmentName: map['attachmentName']?.toString(),
      attachmentSize: _readInt(map['attachmentSize']),
      mimeType: map['mimeType']?.toString(),
      createdAt:
          _readDateTime(map['createdAt']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt: _readDateTime(map['expiresAt']),
    );
  }

  // ── Firestore serialization ─────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'roomId': roomId,
      'senderId': senderId,
      'senderRole': senderRole == UserRole.lawyer ? 'lawyer' : 'client',
      'type': type.wireValue,
      if (text != null) 'text': text,
      if (attachmentStoragePath != null)
        'attachmentStoragePath': attachmentStoragePath,
      if (attachmentDownloadUrl != null)
        'attachmentDownloadUrl': attachmentDownloadUrl,
      if (attachmentName != null) 'attachmentName': attachmentName,
      if (attachmentSize != null) 'attachmentSize': attachmentSize,
      if (mimeType != null) 'mimeType': mimeType,
      'createdAt': Timestamp.fromDate(createdAt),
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    };
  }

  // ── copyWith ────────────────────────────────────────────────────────────────

  ChatMessage copyWith({
    String? id,
    String? roomId,
    String? senderId,
    UserRole? senderRole,
    MessageType? type,
    String? text,
    String? attachmentStoragePath,
    String? attachmentDownloadUrl,
    String? attachmentName,
    int? attachmentSize,
    String? mimeType,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool clearText = false,
    bool clearAttachmentDownloadUrl = false,
    bool clearExpiresAt = false,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      roomId: roomId ?? this.roomId,
      senderId: senderId ?? this.senderId,
      senderRole: senderRole ?? this.senderRole,
      type: type ?? this.type,
      text: clearText ? null : (text ?? this.text),
      attachmentStoragePath:
          attachmentStoragePath ?? this.attachmentStoragePath,
      attachmentDownloadUrl: clearAttachmentDownloadUrl
          ? null
          : (attachmentDownloadUrl ?? this.attachmentDownloadUrl),
      attachmentName: attachmentName ?? this.attachmentName,
      attachmentSize: attachmentSize ?? this.attachmentSize,
      mimeType: mimeType ?? this.mimeType,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
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
