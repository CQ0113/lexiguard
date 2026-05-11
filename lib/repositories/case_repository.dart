import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/case_model.dart';

class CaseRepository {
  CaseRepository({FirebaseFirestore? firestore})
    : _cases = (firestore ?? FirebaseFirestore.instance).collection(
        collectionName,
      );

  static const String collectionName = 'cases';

  final CollectionReference<Map<String, dynamic>> _cases;

  Future<void> createCase(CaseModel caseModel) {
    return _cases.doc(caseModel.id).set(caseModel.toFirestore());
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

  Stream<CaseModel?> watchCase(String caseId) {
    return _cases.doc(caseId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return CaseModel.fromFirestore(snapshot);
    });
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
}
