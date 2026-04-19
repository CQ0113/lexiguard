import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase/firebase_initializer.dart';
import '../models/user_model.dart';
import '../repositories/lawyer_profile_repository.dart';
import '../repositories/user_repository.dart';

class FirebaseAuthSyncService {
  FirebaseAuthSyncService({
    FirebaseAuth? auth,
    UserRepository? userRepository,
    LawyerProfileRepository? lawyerProfileRepository,
  }) : _auth = auth,
       _userRepository = userRepository,
       _lawyerProfileRepository = lawyerProfileRepository;

  final FirebaseAuth? _auth;
  final UserRepository? _userRepository;
  final LawyerProfileRepository? _lawyerProfileRepository;

  FirebaseAuth get _resolvedAuth => _auth ?? FirebaseAuth.instance;

  UserRepository get _resolvedUserRepository =>
      _userRepository ?? UserRepository();

  LawyerProfileRepository get _resolvedLawyerProfileRepository =>
      _lawyerProfileRepository ?? LawyerProfileRepository();

  Future<void> syncSession({
    required bool isLogin,
    required String email,
    required String password,
    required UserRole role,
    UserModel? lawyerProfile,
  }) async {
    if (!FirebaseInitializer.isReady) {
      return;
    }

    try {
      final credential = await _resolveCredential(
        isLogin: isLogin,
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return;
      }

      if (!isLogin) {
        await _persistInitialProfile(
          uid: user.uid,
          email: email,
          role: role,
          lawyerProfile: lawyerProfile,
        );
      }
    } catch (error) {
      // Keep UX uninterrupted while backend wiring is being finalized.
      debugPrint('Firebase sync skipped: $error');
    }
  }

  Future<UserCredential> _resolveCredential({
    required bool isLogin,
    required String email,
    required String password,
  }) async {
    if (isLogin) {
      return _resolvedAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    }

    try {
      return await _resolvedAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'email-already-in-use') {
        return _resolvedAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
      rethrow;
    }
  }

  Future<void> _persistInitialProfile({
    required String uid,
    required String email,
    required UserRole role,
    UserModel? lawyerProfile,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();

    if (role == UserRole.lawyer && lawyerProfile != null) {
      final baseMap = lawyerProfile.toMap();

      await _resolvedUserRepository.upsertUser(
        uid: uid,
        payload: {
          ...baseMap,
          'id': uid,
          'email': email,
          'role': 'lawyer',
          'updatedAt': now,
          'createdAt': now,
        },
      );

      await _resolvedLawyerProfileRepository.upsertProfile(
        uid: uid,
        profile: lawyerProfile,
      );

      return;
    }

    await _resolvedUserRepository.upsertUser(
      uid: uid,
      payload: {
        'id': uid,
        'email': email,
        'role': role == UserRole.client ? 'client' : 'lawyer',
        'updatedAt': now,
        'createdAt': now,
      },
    );
  }
}
