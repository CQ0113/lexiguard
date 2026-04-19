import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../core/firebase/firebase_initializer.dart';
import '../models/user_model.dart';
import '../repositories/lawyer_profile_repository.dart';
import '../repositories/user_repository.dart';
import '../repositories/verification_review_repository.dart';

class FirebaseAuthSyncService {
  FirebaseAuthSyncService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    UserRepository? userRepository,
    LawyerProfileRepository? lawyerProfileRepository,
    VerificationReviewRepository? verificationReviewRepository,
  }) : _auth = auth,
       _functions = functions,
       _userRepository = userRepository,
       _lawyerProfileRepository = lawyerProfileRepository,
       _verificationReviewRepository = verificationReviewRepository;

  final FirebaseAuth? _auth;
  final FirebaseFunctions? _functions;
  final UserRepository? _userRepository;
  final LawyerProfileRepository? _lawyerProfileRepository;
  final VerificationReviewRepository? _verificationReviewRepository;

  FirebaseAuth get _resolvedAuth => _auth ?? FirebaseAuth.instance;

  FirebaseFunctions get _resolvedFunctions =>
      _functions ?? FirebaseFunctions.instance;

  UserRepository get _resolvedUserRepository =>
      _userRepository ?? UserRepository();

  LawyerProfileRepository get _resolvedLawyerProfileRepository =>
      _lawyerProfileRepository ?? LawyerProfileRepository();

  VerificationReviewRepository get _resolvedVerificationReviewRepository =>
      _verificationReviewRepository ?? VerificationReviewRepository();

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

      if (lawyerProfile.isPendingLike) {
        await _resolvedVerificationReviewRepository.enqueueRegistrationReview(
          uid: uid,
          profile: lawyerProfile,
        );
      }

      await _triggerVerificationScaffold(uid: uid, profile: lawyerProfile);

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

  Future<void> _triggerVerificationScaffold({
    required String uid,
    required UserModel profile,
  }) async {
    try {
      final callable = _resolvedFunctions.httpsCallable('startVerification');

      await callable.call({
        'uid': uid,
        'legalFullName': profile.legalFullName ?? profile.name,
        'barOrRollNumber': profile.barNumber,
        'firmName': profile.firmName,
        'jurisdiction': profile.jurisdiction ?? 'peninsular',
        'practiceState': profile.practiceState,
        'practiceCity': profile.practiceCity,
      });
    } catch (error) {
      // Keep registration resilient while Functions backend is still scaffolded.
      debugPrint('Verification callable trigger skipped: $error');
    }
  }
}
