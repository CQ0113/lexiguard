import 'package:cloud_firestore/cloud_firestore.dart';

class VaultDocumentModel {
  final String id;
  final String fileName;
  final String downloadUrl;
  final String ownerUserId;
  final String ownerRole;
  final String storagePath;
  final List<String> allowedUserIds;
  final DateTime? createdAt;
  final int? sizeBytes;
  final String? contentType;

  const VaultDocumentModel({
    required this.id,
    required this.fileName,
    required this.downloadUrl,
    required this.ownerUserId,
    required this.ownerRole,
    required this.storagePath,
    required this.allowedUserIds,
    this.createdAt,
    this.sizeBytes,
    this.contentType,
  });

  factory VaultDocumentModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Vault document ${doc.id} has no data.');
    }

    return VaultDocumentModel(
      id: doc.id,
      fileName: data['fileName']?.toString() ?? '',
      downloadUrl: data['downloadUrl']?.toString() ?? '',
      ownerUserId: data['ownerUserId']?.toString() ?? '',
      ownerRole: data['ownerRole']?.toString() ?? 'client',
      storagePath: data['storagePath']?.toString() ?? '',
      allowedUserIds: List<String>.from(data['allowedUserIds'] as List? ?? []),
      createdAt: _readDateTime(data['createdAt']),
      sizeBytes: _readInt(data['sizeBytes']),
      contentType: data['contentType']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fileName': fileName,
      'downloadUrl': downloadUrl,
      'ownerUserId': ownerUserId,
      'ownerRole': ownerRole,
      'storagePath': storagePath,
      'allowedUserIds': allowedUserIds,
      'createdAt': createdAt == null
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(createdAt!),
      if (sizeBytes != null) 'sizeBytes': sizeBytes,
      if (contentType != null) 'contentType': contentType,
    };
  }

  bool canDelete(String currentUserId) => currentUserId == ownerUserId;

  static DateTime? _readDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }

  static int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
