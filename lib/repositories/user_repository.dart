import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_model.dart';

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _users = (firestore ?? FirebaseFirestore.instance).collection('users');

  final CollectionReference<Map<String, dynamic>> _users;

  Future<void> upsertUser({
    required String uid,
    required Map<String, dynamic> payload,
  }) {
    return _users.doc(uid).set(payload, SetOptions(merge: true));
  }

  Stream<UserModel?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;

      final map = snapshot.data();
      if (map == null) return null;

      final normalized = Map<String, dynamic>.from(map);
      normalized.putIfAbsent('id', () => uid);

      return UserModel.fromMap(normalized);
    });
  }
}
