import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/vault_document_model.dart';

typedef VaultUploadProgress = void Function(double value);

class VaultDocumentRepository {
  VaultDocumentRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;

  static const String collectionName = 'vault_documents';

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _documents =>
      _firestore.collection(collectionName);

  Stream<List<VaultDocumentModel>> streamClientDocuments({
    required String clientUserId,
  }) {
    return _documents
        .where('ownerUserId', isEqualTo: clientUserId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map(VaultDocumentModel.fromFirestore)
              .toList();
          items.sort((a, b) {
            final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
          return items;
        });
  }

  Stream<List<VaultDocumentModel>> streamAccessibleDocuments({
    required String userId,
  }) {
    return _documents
        .where('allowedUserIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map(VaultDocumentModel.fromFirestore)
              .toList();
          items.sort((a, b) {
            final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return right.compareTo(left);
          });
          return items;
        });
  }

  Future<VaultDocumentModel> uploadDocumentBytes({
    required Uint8List bytes,
    required String fileName,
    required String ownerUserId,
    required String ownerRole,
    required List<String> allowedUserIds,
    String? contentType,
    VaultUploadProgress? onProgress,
  }) async {
    final documentRef = _documents.doc();
    // 使用 Set 去重
    final normalizedAllowedIds = {...allowedUserIds, ownerUserId}.toList();
    final safeName = _sanitize(fileName);
    final storagePath = 'vault/$ownerUserId/${documentRef.id}_$safeName';
    final storageRef = _storage.ref(storagePath);

    // 核心修改：Web / Android 通用上传方法，必须用 putData
    final task = storageRef.putData(
      bytes,
      SettableMetadata(
        contentType: contentType, // 设置了类型，Web端就能直接在线预览
        customMetadata: {
          'ownerUserId': ownerUserId,
          'ownerRole': ownerRole,
          'fileName': fileName,
        },
      ),
    );

    final subscription = task.snapshotEvents.listen(
      (snapshot) {
        if (snapshot.totalBytes <= 0 || onProgress == null) return;
        onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
      },
      onError: (_) {
        // Ignore stream errors here; await task surfaces the same failure.
      },
    );

    try {
      await task;
      onProgress?.call(1);
      final downloadUrl = await storageRef.getDownloadURL();

      final payload = VaultDocumentModel(
        id: documentRef.id,
        fileName: fileName,
        downloadUrl: downloadUrl,
        ownerUserId: ownerUserId,
        ownerRole: ownerRole,
        storagePath: storagePath,
        allowedUserIds: normalizedAllowedIds,
        createdAt: null, // 💡 注意：请确保你的 VaultDocumentModel.toFirestore() 中，把 null 转成了 FieldValue.serverTimestamp()
        sizeBytes: bytes.lengthInBytes,
        contentType: contentType,
      );

      await documentRef.set(payload.toFirestore());
      final saved = await documentRef.get();
      return VaultDocumentModel.fromFirestore(saved);
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> deleteDocument(VaultDocumentModel document) async {
    try {
      if (document.storagePath.isNotEmpty) {
        await _storage.ref(document.storagePath).delete();
      } else if (document.downloadUrl.isNotEmpty) {
        await _storage.refFromURL(document.downloadUrl).delete();
      }
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }

    await _documents.doc(document.id).delete();
  }

  String _sanitize(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (sanitized.isEmpty) return 'document';
    return sanitized;
  }
}