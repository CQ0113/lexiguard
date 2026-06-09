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

  // New Contract fields
  final bool isContract;
  final String? contractStatus;
  final String? contractType;
  final DateTime? signedAt;
  final Map<String, dynamic>? contractTerms;
  final List<Map<String, dynamic>>? signaturePoints;

  VaultDocumentModel({
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
    this.isContract = false,
    this.contractStatus,
    this.contractType,
    this.signedAt,
    this.contractTerms,
    this.signaturePoints,
  });

  // Convert from Firestore Document to Dart Object
  factory VaultDocumentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return VaultDocumentModel(
      id: doc.id,
      fileName: data['fileName'] as String? ?? 'Unknown',
      downloadUrl: data['downloadUrl'] as String? ?? '',
      ownerUserId: data['ownerUserId'] as String? ?? '',
      ownerRole: data['ownerRole'] as String? ?? 'client',
      storagePath: data['storagePath'] as String? ?? '',
      allowedUserIds: List<String>.from(data['allowedUserIds'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      sizeBytes: data['sizeBytes'] as int?,
      contentType: data['contentType'] as String?,
      isContract: data['isContract'] as bool? ?? false,
      contractStatus: data['contractStatus'] as String?,
      contractType: data['contractType'] as String?,
      signedAt: (data['signedAt'] as Timestamp?)?.toDate(),
      contractTerms: data['contractTerms'] as Map<String, dynamic>?,
      signaturePoints: (data['signaturePoints'] as List?)?.map((p) => Map<String, dynamic>.from(p)).toList(),
    );
  }

  // Convert from Dart Object to Firestore Map
  Map<String, dynamic> toFirestore() {
    return {
      'fileName': fileName,
      'downloadUrl': downloadUrl,
      'ownerUserId': ownerUserId,
      'ownerRole': ownerRole,
      'storagePath': storagePath,
      'allowedUserIds': allowedUserIds,
      // If createdAt is null (like when first uploading), tell Firebase to insert the server time
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'sizeBytes': sizeBytes,
      'contentType': contentType,
      'isContract': isContract,
      'contractStatus': contractStatus,
      'contractType': contractType,
      'signedAt': signedAt != null ? Timestamp.fromDate(signedAt!) : null,
      'contractTerms': contractTerms,
      'signaturePoints': signaturePoints,
    };
  }

  // Helper method used by the UI screens to determine if the delete button should show
  bool canDelete(String userId) {
    return ownerUserId == userId;
  }
}