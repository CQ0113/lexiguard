import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _users => _db.collection('users');

  /// Save a new user document to Firestore (used on registration).
  Future<void> createUserDocument(UserModel user) async {
    await _users.doc(user.id).set(user.toFirestore());
  }

  /// Fetch a user document by UID. Returns null if not found.
  Future<UserModel?> getUserById(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
  }

  /// Real-time stream of a user's document.
  Stream<UserModel?> userStream(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc as DocumentSnapshot<Map<String, dynamic>>);
    });
  }

  /// Update specific fields on a user document.
  Future<void> updateUser(String uid, Map<String, dynamic> fields) async {
    await _users.doc(uid).update(fields);
  }
}
