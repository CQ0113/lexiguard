import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';
import 'user_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserService _userService = UserService();

  // Stream of Firebase User — null when signed out
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Current Firebase user (nullable)
  User? get currentUser => _auth.currentUser;

  /// Sign in with email + password.
  /// Throws [AuthException] if credentials are wrong or role doesn't match.
  Future<UserModel> signIn({
    required String email,
    required String password,
    required String role, // 'client' or 'lawyer'
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;
    final userModel = await _userService.getUserById(uid);

    if (userModel == null) {
      await _auth.signOut();
      throw AuthException('Account not found. Please register first.');
    }

    final expectedRole = role == 'Client' ? UserRole.client : UserRole.lawyer;
    if (userModel.role != expectedRole) {
      await _auth.signOut();
      final roleLabel = role == 'Client' ? 'Client' : 'Lawyer';
      throw AuthException(
        'This account is not registered as a $roleLabel. '
        'Please select the correct role.',
      );
    }

    return userModel;
  }

  /// Register a new user (creates Auth account + Firestore document).
  Future<UserModel> register({
    required String name,
    required String email,
    required String password,
    required String phone,
    required String role, // 'Client' or 'Lawyer'
    // Lawyer-only fields
    String? barNumber,
    String? specialization,
    double? hourlyRate,
    int? yearsExperience,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    final uid = credential.user!.uid;

    final userModel = UserModel(
      id: uid,
      name: name.trim(),
      email: email.trim(),
      phone: phone.trim(),
      role: role == 'Lawyer' ? UserRole.lawyer : UserRole.client,
      barNumber: barNumber?.trim(),
      specialization: specialization?.trim(),
      hourlyRate: hourlyRate,
      yearsExperience: yearsExperience,
      barCouncilVerified: role == 'Lawyer' ? false : null,
    );

    await _userService.createUserDocument(userModel);

    // Update display name in Firebase Auth
    await credential.user!.updateDisplayName(name.trim());

    return userModel;
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Step 1 of Google sign-in: perform OAuth and return the raw credential
  /// plus a flag indicating whether this is a brand-new user (no Firestore doc).
  /// Does NOT write anything to Firestore.
  Future<({UserCredential credential, bool isNewUser, UserModel? existingModel})>
      authenticateWithGoogle({required String role}) async {
    UserCredential userCredential;

    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw const AuthException('Google sign in was cancelled.');
        }
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );
        userCredential = await _auth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('[AuthService] FirebaseAuthException during Google sign-in: '
          'code=${e.code} message=${e.message}');
      if (e.code == 'popup-closed-by-user' ||
          e.code == 'cancelled-popup-request') {
        throw const AuthException('Google sign in was cancelled.');
      }
      throw AuthException(
        e.message ?? 'Firebase error during Google Sign In (code: ${e.code})',
      );
    } catch (e) {
      debugPrint('[AuthService] Unexpected error during Google sign-in: $e');
      throw AuthException('Unexpected error: $e');
    }

    final uid = userCredential.user!.uid;
    final existingModel = await _userService.getUserById(uid);

    // If the existing user's role doesn't match the selected role, sign out
    // immediately and report the conflict before any profile work.
    if (existingModel != null) {
      final expectedRole = role == 'Client' ? UserRole.client : UserRole.lawyer;
      if (existingModel.role != expectedRole) {
        await signOut();
        final roleLabel = role == 'Client' ? 'Client' : 'Lawyer';
        throw AuthException(
          'This account is registered as a ${existingModel.role.name}, '
          'but you are trying to log in as a $roleLabel. '
          'Please select the correct role.',
        );
      }
    }

    return (
      credential: userCredential,
      isNewUser: existingModel == null,
      existingModel: existingModel,
    );
  }

  /// Step 2 of Google sign-in: persist the supplied [profile] to Firestore.
  /// Call this after collecting any extra information from the user (e.g.
  /// lawyer verification details).
  Future<UserModel> finalizeGoogleProfile({
    required UserCredential credential,
    required UserModel profile,
  }) async {
    // Override the id with the real Firebase UID.
    final finalProfile = UserModel(
      id: credential.user!.uid,
      name: profile.name.isNotEmpty
          ? profile.name
          : (credential.user!.displayName ?? 'New User'),
      email: profile.email.isNotEmpty
          ? profile.email
          : (credential.user!.email ?? ''),
      phone: profile.phone.isNotEmpty
          ? profile.phone
          : (credential.user!.phoneNumber ?? ''),
      role: profile.role,
      barNumber: profile.barNumber,
      specialization: profile.specialization,
      barCouncilVerified: profile.barCouncilVerified,
      verificationStatus: profile.verificationStatus,
      verificationProvider: profile.verificationProvider,
      verificationBadgeVisible: profile.verificationBadgeVisible,
      legalFullName: profile.legalFullName,
      firmName: profile.firmName,
      jurisdiction: profile.jurisdiction,
      practiceState: profile.practiceState,
      practiceCity: profile.practiceCity,
    );
    await _userService.createUserDocument(finalProfile);
    return finalProfile;
  }

  /// Sign out.
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn().signOut();
      }
    } catch (_) {} // Ignore exceptions if they weren't signed in with Google
    await _auth.signOut();
  }
}

/// Custom exception for auth-level errors we want to surface to the UI.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
