import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class LawyerProfileRepository {
  LawyerProfileRepository({FirebaseFirestore? firestore})
    : _profiles = (firestore ?? FirebaseFirestore.instance).collection(
        'lawyer_profiles',
      );

  final CollectionReference<Map<String, dynamic>> _profiles;

  Future<void> upsertProfile({
    required String uid,
    required UserModel profile,
  }) {
    return _profiles.doc(uid).set({
      'uid': uid,
      'legalFullName': profile.legalFullName,
      'firmName': profile.firmName,
      'jurisdiction': profile.jurisdiction,
      'practiceState': profile.practiceState,
      'practiceCity': profile.practiceCity,
      'barOrRollNumber': profile.barNumber,
      'verificationStatus': profile.verificationStatus.wireValue,
      'verificationProvider': profile.verificationProvider,
      'verificationBadgeVisible': profile.verificationBadgeVisible,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    return _profiles.doc(uid).snapshots().map((snapshot) => snapshot.data());
  }
}
