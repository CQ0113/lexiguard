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

  Future<List<UserModel>> getUsers(List<String> uids) async {
    if (uids.isEmpty) return [];
    
    List<UserModel> users = [];
    for (var i = 0; i < uids.length; i += 10) {
      final chunk = uids.sublist(i, i + 10 > uids.length ? uids.length : i + 10);
      final snapshot = await _users.where(FieldPath.documentId, whereIn: chunk).get();
      
      for (final doc in snapshot.docs) {
        final map = doc.data();
        map['id'] = doc.id;
        users.add(UserModel.fromMap(map));
      }
    }
    return users;
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
