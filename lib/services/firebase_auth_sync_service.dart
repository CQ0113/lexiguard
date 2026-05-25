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

  Future<SyncSessionResult> syncSession({
    required bool isLogin,
    required String email,
    required String password,
    required UserRole role,
    UserModel? lawyerProfile,
  }) async {
    if (!FirebaseInitializer.isReady) {
      return const SyncSessionResult(firebaseUnavailable: true);
    }

    try {
      final credential = await _resolveCredential(
        isLogin: isLogin,
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return const SyncSessionResult();
      }

      if (!isLogin) {
        return await _persistInitialProfile(
          uid: user.uid,
          email: email,
          role: role,
          lawyerProfile: lawyerProfile,
        );
      }
    } on FirebaseAuthException {
      // Always re-throw auth credential errors (wrong password, invalid email,
      // user-not-found, etc.) so the UI can show the correct error message.
      rethrow;
    } catch (error) {
      debugPrint('Firebase sync skipped: $error');
      return SyncSessionResult(syncError: error.toString());
    }
    return const SyncSessionResult();
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

  Future<SyncSessionResult> _persistInitialProfile({
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

      return await _triggerVerificationScaffold(uid: uid, profile: lawyerProfile);
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
    return const SyncSessionResult();
  }

  Future<SyncSessionResult> _triggerVerificationScaffold({
    required String uid,
    required UserModel profile,
  }) async {
    try {
      final callable = _resolvedFunctions.httpsCallable('startVerification');

      final result = await callable.call({
        'uid': uid,
        'legalFullName': profile.legalFullName ?? profile.name,
        'barOrRollNumber': profile.barNumber,
        'firmName': profile.firmName,
        'jurisdiction': profile.jurisdiction ?? 'peninsular',
        'practiceState': profile.practiceState,
        'practiceCity': profile.practiceCity,
      });

      final adapterStatus =
          (result.data as Map<Object?, Object?>?)?['adapterStatus'] as String?;
      if (adapterStatus == 'request_failed') {
        debugPrint(
          'Verification adapter failed for $uid — queued for manual review.',
        );
        return const SyncSessionResult(adapterFailed: true);
      }
      return const SyncSessionResult();
    } catch (error) {
      debugPrint('Verification callable trigger skipped: $error');
      return SyncSessionResult(verificationCallError: error.toString());
    }
  }
}

/// Outcome of [FirebaseAuthSyncService.syncSession].
///
/// The flags are not mutually exclusive: e.g. an authenticated user may still
/// hit `adapterFailed` if the Cloud Function ran but the Bar API request
/// failed downstream.
class SyncSessionResult {
  const SyncSessionResult({
    this.adapterFailed = false,
    this.firebaseUnavailable = false,
    this.syncError,
    this.verificationCallError,
  });

  /// `startVerification` reported `adapterStatus == 'request_failed'`. The
  /// account is still queued for manual review.
  final bool adapterFailed;

  /// Firebase isn't configured locally (no firebase_options.dart). Nothing was
  /// written to Firestore and `startVerification` did not run.
  final bool firebaseUnavailable;

  /// Non-auth failure during Firestore writes or Cloud Function setup.
  final String? syncError;

  /// `startVerification` callable threw (e.g. function not deployed,
  /// permission-denied, network error). Profile was written with the initial
  /// `pending`/`manualReviewRequired` status but the Bar lookup did not run.
  final String? verificationCallError;

  bool get hasIssue =>
      adapterFailed ||
      firebaseUnavailable ||
      syncError != null ||
      verificationCallError != null;
}
