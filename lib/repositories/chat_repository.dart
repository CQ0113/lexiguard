import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/chat_message_model.dart';
import '../models/chat_room_model.dart';
import '../models/user_model.dart' show UserRole;

export '../models/chat_message_model.dart'
    show ChatMessage, MessageType, MessageTypeWire;
export '../models/chat_room_model.dart' show ChatRoom;

/// Signature for the storage-upload step used inside [ChatRepository].
///
/// Returns `(storagePath, downloadUrl)`. Overridable for unit tests without
/// needing a [FirebaseStorage] fake package.
typedef ChatStorageUploader = Future<({String storagePath, String downloadUrl})>
    Function(String path, Uint8List bytes, String mimeType);

/// Repository for reading and writing chat data.
///
/// Constructor accepts optional [FirebaseFirestore] and [ChatStorageUploader]
/// so unit tests can inject fakes without touching real Firebase backends.
/// [FirebaseStorage] is resolved lazily the first time it is needed, so tests
/// that provide [storageUploader] never touch the real storage singleton.
class ChatRepository {
  ChatRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    ChatStorageUploader? storageUploader,
  })  : _db = firestore ?? FirebaseFirestore.instance,
        _storageOverride = storage,
        _storageUploader = storageUploader;

  static const String _roomsCollection = 'chat_rooms';
  static const String _messagesSubcollection = 'messages';
  static const int _maxAttachmentBytes = 10 * 1024 * 1024; // 10 MB

  final FirebaseFirestore _db;

  /// Optional override injected in tests; production code uses lazy instance.
  final FirebaseStorage? _storageOverride;

  /// Lazily resolved storage instance — avoids touching [FirebaseStorage.instance]
  /// in tests that inject a [_storageUploader].
  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  /// Overridable upload step — used by tests to bypass real Firebase Storage.
  final ChatStorageUploader? _storageUploader;

  CollectionReference<Map<String, dynamic>> get _rooms =>
      _db.collection(_roomsCollection);

  CollectionReference<Map<String, dynamic>> _messages(String roomId) =>
      _rooms.doc(roomId).collection(_messagesSubcollection);

  // ── Read streams ────────────────────────────────────────────────────────────

  /// Streams all rooms where [uid] is a participant, newest-message-first.
  Stream<List<ChatRoom>> streamRoomsForUser(String uid) {
    return _rooms
        .where('participants', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(ChatRoom.fromFirestore).toList(),
        );
  }

  /// Streams the most recent [limit] messages in a room, newest-first.
  ///
  /// The caller typically reverses the list before rendering in a
  /// `ListView(reverse: true)` so the latest message appears at the bottom.
  Stream<List<ChatMessage>> streamMessages(
    String roomId, {
    int limit = 50,
  }) {
    return _messages(roomId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs.map(ChatMessage.fromFirestore).toList(),
        );
  }

  // ── Writes ──────────────────────────────────────────────────────────────────

  /// Sends a text message to [roomId] in a single atomic [WriteBatch].
  ///
  /// The batch:
  /// 1. Adds a new message document with `createdAt: serverTimestamp()`.
  /// 2. Updates the room's `lastMessage*` fields and increments the
  ///    recipient's `unreadCounts.<recipientId>` slot by 1.
  ///
  /// Throws [ArgumentError] when the trimmed text is empty.
  Future<void> sendTextMessage({
    required String roomId,
    required String senderId,
    required UserRole senderRole,
    required String text,
    required String recipientId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(text, 'text', 'Chat message text must not be empty.');
    }

    final messageRef = _messages(roomId).doc();
    final roomRef = _rooms.doc(roomId);

    final batch = _db.batch();

    // 1. Add message document.
    batch.set(messageRef, {
      'id': messageRef.id,
      'roomId': roomId,
      'senderId': senderId,
      'senderRole': senderRole == UserRole.lawyer ? 'lawyer' : 'client',
      'type': MessageType.text.wireValue,
      'text': trimmed,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // 2. Update room last-message preview and increment recipient unread slot.
    batch.update(roomRef, {
      'lastMessageText': trimmed,
      'lastMessageType': MessageType.text.wireValue,
      'lastSenderId': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCounts.$recipientId': FieldValue.increment(1),
    });

    await batch.commit();
  }

  /// Uploads [bytes] to Firebase Storage and writes an attachment message doc
  /// in a single atomic [WriteBatch].
  ///
  /// Throws [ArgumentError] when the file exceeds 10 MB.
  /// Storage path: `chat_attachments/{roomId}/{messageId}_{sanitizedFileName}`.
  Future<void> sendAttachmentMessage({
    required String roomId,
    required String senderId,
    required UserRole senderRole,
    required String recipientId,
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    required MessageType type,
  }) async {
    if (bytes.length > _maxAttachmentBytes) {
      throw ArgumentError(
        'Attachment exceeds the 10 MB limit '
        '(${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB).',
      );
    }

    // 1. Reserve a message doc ID without writing yet.
    final messageRef = _messages(roomId).doc();
    final messageId = messageRef.id;

    // 2. Upload to Storage (or use injected uploader for tests).
    final safeName = _sanitize(fileName);
    final storagePath = 'chat_attachments/$roomId/${messageId}_$safeName';

    final String downloadUrl;

    if (_storageUploader != null) {
      final result = await _storageUploader(storagePath, bytes, mimeType);
      downloadUrl = result.downloadUrl;
    } else {
      final storageRef = _storage.ref(storagePath);
      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: mimeType),
      );
      final snapshot = await uploadTask;
      downloadUrl = await snapshot.ref.getDownloadURL();
    }

    // 3. Build last-message preview.
    final String lastMessageText;
    if (type == MessageType.image) {
      lastMessageText = '📷 Photo';
    } else {
      lastMessageText = '📎 $fileName';
    }

    // 4. Atomic batch: write message + update room.
    final roomRef = _rooms.doc(roomId);
    final batch = _db.batch();

    batch.set(messageRef, {
      'id': messageId,
      'roomId': roomId,
      'senderId': senderId,
      'senderRole': senderRole == UserRole.lawyer ? 'lawyer' : 'client',
      'type': type.wireValue,
      'attachmentStoragePath': storagePath,
      'attachmentDownloadUrl': downloadUrl,
      'attachmentName': fileName,
      'attachmentSize': bytes.length,
      'mimeType': mimeType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.update(roomRef, {
      'lastMessageText': lastMessageText,
      'lastMessageType': type.wireValue,
      'lastSenderId': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'unreadCounts.$recipientId': FieldValue.increment(1),
    });

    try {
      await batch.commit();
    } catch (e) {
      // Storage upload already succeeded; leftover blob is harmless.
      // Log and rethrow so the UI can surface the error.
      // ignore: avoid_print
      print('ChatRepository.sendAttachmentMessage: Firestore batch failed: $e');
      rethrow;
    }
  }

  /// Resets the caller's unread counter to zero.
  ///
  /// Uses dot-path notation (`unreadCounts.<uid>`) so only the caller's slot
  /// is touched — the other participant's count is preserved.
  Future<void> markRoomRead(String roomId, String uid) async {
    await _rooms.doc(roomId).update({
      'unreadCounts.$uid': 0,
    });
  }

  /// Fetches a single room document by its [roomId].
  ///
  /// Returns `null` when the document does not exist (e.g. the connection was
  /// approved before SCRUM-17 was deployed) so callers can handle the gap
  /// gracefully.
  Future<ChatRoom?> fetchRoom(String roomId) async {
    final doc = await _rooms.doc(roomId).get();
    if (!doc.exists) return null;
    return ChatRoom.fromFirestore(doc);
  }

  /// Returns the room for [roomId], creating it lazily from the matching
  /// `connection_requests` document if it does not exist yet.
  ///
  /// This handles connections that were approved before SCRUM-17 was deployed
  /// and therefore never had a `chat_rooms` doc written.  Uses
  /// `SetOptions(merge: true)` so the call is idempotent if the room already
  /// exists by the time this runs.
  ///
  /// Throws [StateError] when neither the room nor its backing
  /// `connection_requests` document can be found.
  Future<ChatRoom> ensureRoom(String roomId) async {
    // Fast path — room already exists.
    final existing = await fetchRoom(roomId);
    if (existing != null) return existing;

    // Slow path — read the connection_request to back-fill the room.
    final reqDoc = await _db.collection('connection_requests').doc(roomId).get();
    if (!reqDoc.exists) {
      throw StateError('No connection_request found for room $roomId');
    }

    final data = reqDoc.data()!;
    final clientId = data['clientId'] as String? ?? '';
    final lawyerId = data['lawyerId'] as String? ?? '';
    final caseId   = data['caseId']   as String? ?? '';

    final snap     = (data['lawyerSnapshot'] as Map<String, dynamic>?) ?? {};
    final reveal   = (data['clientReveal']   as Map<String, dynamic>?) ?? {};

    final lawyerName     = snap['name']      as String? ?? 'Lawyer';
    final lawyerAvatarUrl= snap['avatarUrl'] as String? ?? '';
    final clientName     = reveal['name']    as String? ?? 'Client';

    // Look up the case title — best-effort; fall back to caseId if absent.
    String caseTitle = caseId;
    try {
      final caseDoc = await _db.collection('cases').doc(caseId).get();
      if (caseDoc.exists) {
        caseTitle = (caseDoc.data()?['title'] as String?) ?? caseId;
      }
    } catch (_) {/* non-fatal */}

    final now = Timestamp.now();
    final roomData = {
      'caseId':          caseId,
      'clientId':        clientId,
      'lawyerId':        lawyerId,
      'participants':    [clientId, lawyerId],
      'clientName':      clientName,
      'lawyerName':      lawyerName,
      'lawyerAvatarUrl': lawyerAvatarUrl,
      'caseTitle':       caseTitle,
      'lastMessageText': '',
      'lastMessageType': 'text',
      'lastSenderId':    '',
      'lastMessageAt':   now,
      'createdAt':       now,
      'unreadCounts':    {clientId: 0, lawyerId: 0},
    };

    await _rooms.doc(roomId).set(roomData, SetOptions(merge: true));
    return ChatRoom.fromMap(roomId, roomData);
  }

  // ── Private helpers ──────────────────────────────────────────────────────────

  /// Sanitizes [value] for use as a Storage filename segment.
  ///
  /// 1. Strips path-traversal sequences (`..`), forward-slashes, and
  ///    back-slashes by replacing them with `_`.
  /// 2. Replaces any remaining character that is not alphanumeric, `.`, `_`,
  ///    or `-` with `_`.
  ///
  /// The two-pass approach ensures that sequences like `../` or `..\` (which
  /// survive a single character-class pass because `.` is individually allowed)
  /// are neutralised before the safe-character filter runs.
  String _sanitize(String value) {
    // Pass 1: replace traversal sequences and path separators.
    final pass1 = value
        .replaceAll('..', '_')
        .replaceAll('/', '_')
        .replaceAll(r'\', '_');
    // Pass 2: replace any remaining unsafe characters.
    final sanitized = pass1.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    return sanitized.isEmpty ? 'attachment' : sanitized;
  }
}
