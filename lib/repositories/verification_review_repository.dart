import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class VerificationReviewRepository {
  VerificationReviewRepository({FirebaseFirestore? firestore})
    : _requests = (firestore ?? FirebaseFirestore.instance).collection(
        'verification_requests',
      );

  final CollectionReference<Map<String, dynamic>> _requests;

  Future<void> enqueueRegistrationReview({
    required String uid,
    required UserModel profile,
  }) {
    return _requests.doc(uid).set({
      'uid': uid,
      'requestType': 'lawyer_registration',
      'queueStatus': 'queued',
      'queueReason': _queueReason(profile),
      'verificationStatus': profile.verificationStatus.wireValue,
      'verificationProvider': profile.verificationProvider,
      'verificationBadgeVisible': profile.verificationBadgeVisible,
      'legalFullName': profile.legalFullName ?? profile.name,
      'barOrRollNumber': profile.barNumber,
      'firmName': profile.firmName,
      'jurisdiction': profile.jurisdiction,
      'practiceState': profile.practiceState,
      'practiceCity': profile.practiceCity,
      'source': 'app_registration',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  String _queueReason(UserModel profile) {
    if (profile.verificationStatus == VerificationStatus.manualReviewRequired) {
      return 'jurisdiction_requires_manual_review';
    }

    return 'initial_verification_pending';
  }
}
