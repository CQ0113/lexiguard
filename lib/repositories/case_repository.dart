import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/case_model.dart';

class CaseRepository {
  CaseRepository({FirebaseFirestore? firestore, FirebaseStorage? storage})
    : _cases = (firestore ?? FirebaseFirestore.instance).collection(
        collectionName,
      ),
      _storageOverride = storage;

  static const String collectionName = 'cases';

  final CollectionReference<Map<String, dynamic>> _cases;
  final FirebaseStorage? _storageOverride;

  FirebaseStorage get _storage => _storageOverride ?? FirebaseStorage.instance;

  Future<void> createCase(CaseModel caseModel) {
    return _cases.doc(caseModel.id).set(caseModel.toFirestore());
  }

  Future<CaseAttachment> uploadCaseAttachmentBytes({
    required String caseId,
    required String clientId,
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    final attachmentId = _cases.doc(caseId).collection('attachments').doc().id;
    final safeName = _sanitize(fileName);
    final storagePath =
        'case_attachments/$clientId/$caseId/${attachmentId}_$safeName';
    final storageRef = _storage.ref(storagePath);

    await storageRef.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        customMetadata: {
          'caseId': caseId,
          'clientId': clientId,
          'fileName': fileName,
        },
      ),
    );

    final downloadUrl = await storageRef.getDownloadURL();
    return CaseAttachment(
      id: attachmentId,
      fileName: fileName,
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      sizeBytes: bytes.lengthInBytes,
      contentType: contentType,
      uploadedAt: DateTime.now(),
    );
  }

  Future<void> deleteCaseAttachment(CaseAttachment attachment) async {
    if (attachment.storagePath.isEmpty) return;
    try {
      await _storage.ref(attachment.storagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  Stream<List<CaseModel>> streamConnectedCasesForLawyer(String lawyerId) {
    return _cases
        .where('lawyerId', isEqualTo: lawyerId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          final cases = snapshot.docs.map(CaseModel.fromFirestore).toList();
          cases.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return cases;
        });
  }

  Stream<List<CaseModel>> streamClientCases({required String clientId}) {
    return _cases.where('clientId', isEqualTo: clientId).snapshots().map((
      snapshot,
    ) {
      final cases = snapshot.docs.map(CaseModel.fromFirestore).toList();
      cases.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return cases;
    });
  }

  Stream<List<CaseModel>> streamOpenCases() {
    // Single-field filter only — composite index not needed.
    // lawyerId == null is checked in Dart after the fetch.
    return _cases.where('status', isEqualTo: 'pending').snapshots().map((
      snapshot,
    ) {
      final cases = snapshot.docs
          .map(CaseModel.fromFirestore)
          .where((c) => c.lawyerId == null)
          .toList();
      cases.sort((left, right) => right.createdAt.compareTo(left.createdAt));
      return cases;
    });
  }

  Stream<CaseModel?> watchCase(String caseId) {
    return _cases.doc(caseId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return CaseModel.fromFirestore(snapshot);
    });
  }

  Future<CaseModel?> getCase(String caseId) async {
    final snapshot = await _cases.doc(caseId).get();
    if (!snapshot.exists) return null;
    return CaseModel.fromFirestore(snapshot);
  }

  Future<void> updateCaseStatus({
    required String caseId,
    required CaseStatus status,
    double? progressPercent,
    DateTime? nextHearing,
  }) {
    final payload = <String, dynamic>{
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (progressPercent != null) {
      payload['progressPercent'] = progressPercent;
    }

    if (nextHearing != null) {
      payload['nextHearing'] = Timestamp.fromDate(nextHearing);
    }

    return _cases.doc(caseId).update(payload);
  }

  Future<void> updateCaseRecommendationStatus(String caseId, String status) {
    return _cases.doc(caseId).update({
      'recommendationStatus': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _sanitize(String value) {
    final sanitized = value.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    if (sanitized.isEmpty) return 'attachment';
    return sanitized;
  }
}
