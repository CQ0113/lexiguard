import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileService {
  ProfileService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore,
      _auth = auth;

  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  FirebaseFirestore get _resolvedFirestore =>
      _firestore ?? FirebaseFirestore.instance;

  FirebaseAuth get _resolvedAuth => _auth ?? FirebaseAuth.instance;

  String? get currentUid => _resolvedAuth.currentUser?.uid;

  String? get currentEmail => _resolvedAuth.currentUser?.email;

  Future<void> updateUserProfile({
    required String uid,
    required Map<String, Object?> fields,
  }) async {
    final payload = Map<String, Object?>.from(fields)
      ..removeWhere((_, value) => value == null);

    payload['updatedAt'] = FieldValue.serverTimestamp();

    await _resolvedFirestore.collection('users').doc(uid).update(payload);
  }

  Future<void> sendPasswordResetEmail({String? email}) async {
    final targetEmail = (email ?? currentEmail)?.trim();
    if (targetEmail == null || targetEmail.isEmpty) {
      throw StateError('No email address is available for password reset.');
    }

    await _resolvedAuth.sendPasswordResetEmail(email: targetEmail);
  }

  Future<void> verifyBeforeUpdateEmail(String newEmail) async {
    final trimmedEmail = newEmail.trim();
    if (trimmedEmail.isEmpty) {
      throw ArgumentError('New email address cannot be empty.');
    }

    final user = _resolvedAuth.currentUser;
    if (user == null) {
      throw StateError('You must be signed in to change your email address.');
    }

    await user.verifyBeforeUpdateEmail(trimmedEmail);
  }
}
