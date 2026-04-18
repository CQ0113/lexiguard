import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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

  /// Send password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Sign in with Google
  Future<UserModel> signInWithGoogle({required String role}) async {
    UserCredential userCredential;

    try {
      if (kIsWeb) {
        // On web, Firebase handles the popup cleanly without needing the separate API keys
        final googleProvider = GoogleAuthProvider();
        userCredential = await _auth.signInWithPopup(googleProvider);
      } else {
        // On mobile, use standard google_sign_in package
        final GoogleSignIn googleSignIn = GoogleSignIn();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

        if (googleUser == null) {
          throw const AuthException('Google sign in was cancelled.');
        }

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final AuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        userCredential = await _auth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user') {
        throw const AuthException('Google sign in was cancelled.');
      }
      throw AuthException(e.message ?? 'An error occurred during Google Sign In');
    }

    final uid = userCredential.user!.uid;
    UserModel? userModel = await _userService.getUserById(uid);

    final expectedRole = role == 'Client' ? UserRole.client : UserRole.lawyer;

    if (userModel == null) {
      // First time logging in with Google. Seamlessly create the profile based on the selected role!
      userModel = UserModel(
        id: uid,
        name: userCredential.user!.displayName ?? 'New User',
        email: userCredential.user!.email ?? '',
        phone: userCredential.user!.phoneNumber ?? '',
        role: expectedRole,
        barCouncilVerified: expectedRole == UserRole.lawyer ? false : null,
      );
      await _userService.createUserDocument(userModel);
    } else {
      // User document already exists. Verify role matches what they selected on login screen.
      if (userModel.role != expectedRole) {
        await signOut();
        final roleLabel = role == 'Client' ? 'Client' : 'Lawyer';
        throw AuthException(
          'This account is registered as a ${userModel.role.name}, '
          'but you are trying to log in as a $roleLabel. '
          'Please select the correct role.',
        );
      }
    }

    return userModel;
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
