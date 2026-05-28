import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/firebase/firebase_initializer.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/firebase_auth_sync_service.dart';
import 'admin_login_screen.dart';
import 'client/client_dashboard_screen.dart';
import 'lawyer/lawyer_dashboard_screen.dart';
import 'shared/live_dashboard_router_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool isLogin = true;
  String selectedRole = 'Client'; // 'Client' or 'Lawyer'
  bool obscurePassword = true;
  String selectedJurisdiction = 'peninsular';

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  final TextEditingController legalFullNameController = TextEditingController();
  final TextEditingController barNumberController = TextEditingController();
  final TextEditingController firmNameController = TextEditingController();
  final TextEditingController practiceStateController = TextEditingController();
  final TextEditingController practiceCityController = TextEditingController();

  final Color primaryBlue = const Color(0xFF0C1D36);
  final Color goldAccent = const Color(0xFFCFA92A);
  final FirebaseAuthSyncService _authSyncService = FirebaseAuthSyncService();
  // Lazy — defers FirebaseAuth.instance until Firebase is confirmed ready.
  AuthService? _authServiceInstance;
  AuthService get _authService => _authServiceInstance ??= AuthService();
  bool _isSubmitting = false;
  bool _isGoogleSubmitting = false;

  bool get showLawyerVerificationFields {
    return !isLogin && selectedRole == 'Lawyer';
  }

  String get actionLabel {
    if (isLogin) return 'Sign In';
    return selectedRole == 'Lawyer'
        ? 'Register & Start Verification'
        : 'Create Account';
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    return emailRegex.hasMatch(email);
  }

  String? _validateInputs() {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty) {
      return 'Please enter your email address.';
    }

    if (!_isValidEmail(email)) {
      return 'Please enter a valid email address.';
    }

    if (password.isEmpty) {
      return 'Please enter your password.';
    }

    if (!isLogin && password.length < 6) {
      return 'Password must be at least 6 characters.';
    }

    if (!showLawyerVerificationFields) {
      return null;
    }

    if (legalFullNameController.text.trim().isEmpty) {
      return 'Legal full name is required for lawyer verification.';
    }

    if (firmNameController.text.trim().isEmpty) {
      return 'Law firm name is required for lawyer verification.';
    }

    if (practiceStateController.text.trim().isEmpty) {
      return 'Practice state is required for lawyer verification.';
    }

    if (practiceCityController.text.trim().isEmpty) {
      return 'Practice city is required for lawyer verification.';
    }

    return null;
  }

  void _showInputError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFFB91C1C),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openAdminLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
    );
  }

  VerificationStatus _initialStatusForJurisdiction(String jurisdiction) {
    return jurisdiction == 'peninsular'
        ? VerificationStatus.pending
        : VerificationStatus.manualReviewRequired;
  }

  String _verificationProviderForJurisdiction(String jurisdiction) {
    switch (jurisdiction) {
      case 'peninsular':
        return 'malaysian_bar';
      case 'sabah':
        return 'manual_review_sabah';
      case 'sarawak':
        return 'manual_review_sarawak';
      default:
        return 'manual_review';
    }
  }

  String _registrationMessageForStatus(VerificationStatus status) {
    if (status == VerificationStatus.manualReviewRequired) {
      return 'East Malaysia verification is currently manual review only. Our team will review your profile within 48 hours.';
    }
    return 'Verification submitted. You are now in pending sandbox mode.';
  }

  UserModel _buildPendingLawyerFromForm() {
    final jurisdiction = selectedJurisdiction;
    final initialStatus = _initialStatusForJurisdiction(jurisdiction);
    final legalName = legalFullNameController.text.trim();
    final barNumber = barNumberController.text.trim();
    final firmName = firmNameController.text.trim();
    final practiceState = practiceStateController.text.trim();
    final practiceCity = practiceCityController.text.trim();

    return UserModel(
      id: 'local_lawyer_${DateTime.now().millisecondsSinceEpoch}',
      name: legalName,
      email: emailController.text.trim(),
      phone: '',
      role: UserRole.lawyer,
      barNumber: barNumber.isNotEmpty ? barNumber : null,
      specialization: 'General Practice',
      barCouncilVerified: false,
      verificationStatus: initialStatus,
      verificationProvider: _verificationProviderForJurisdiction(jurisdiction),
      verificationBadgeVisible: false,
      legalFullName: legalName,
      firmName: firmName,
      jurisdiction: jurisdiction,
      practiceState: practiceState,
      practiceCity: practiceCity,
    );
  }

  UserModel _buildFallbackClient() {
    final email = emailController.text.trim();
    final localName = email.split('@').first.trim();

    return UserModel(
      id: 'local_client_${DateTime.now().millisecondsSinceEpoch}',
      name: localName.isEmpty ? 'Client User' : localName,
      email: email,
      phone: '',
      role: UserRole.client,
    );
  }

  UserModel _buildFallbackLawyerLogin() {
    final email = emailController.text.trim();
    final localName = email.split('@').first.trim();

    return UserModel(
      id: 'local_lawyer_login',
      name: localName.isEmpty ? 'Lawyer User' : localName,
      email: email,
      phone: '',
      role: UserRole.lawyer,
      specialization: 'General Practice',
      verificationStatus: VerificationStatus.autoVerified,
      verificationBadgeVisible: true,
    );
  }

  void _navigateFallback(UserRole role, UserModel? lawyerProfile) {
    if (!mounted) return;

    if (role == UserRole.client) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ClientDashboardScreen(user: _buildFallbackClient()),
        ),
      );
      return;
    }

    final lawyer = lawyerProfile ?? _buildFallbackLawyerLogin();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LawyerDashboardScreen(user: lawyer),
      ),
    );

    if (!isLogin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _registrationMessageForStatus(lawyer.verificationStatus),
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1E3A8A),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _onGoogleSignIn() async {
    if (_isGoogleSubmitting || _isSubmitting) return;

    setState(() => _isGoogleSubmitting = true);

    try {
      if (!FirebaseInitializer.isReady) {
        _showInputError('Firebase is not available. Please try again later.');
        return;
      }

      // Step 1: OAuth Ã¢â‚¬â€ checks if returning user or brand new.
      final result = await _authService.authenticateWithGoogle(
        role: selectedRole,
      );

      if (!mounted) return;

      // Step 2: For new users, create a minimal profile and let
      // LiveDashboardRouterScreen handle the rest:
      //   Ã¢â‚¬Â¢ New lawyers  Ã¢â€ â€™ verificationStatus = unsubmitted
      //                  Ã¢â€ â€™ router redirects to LawyerVerificationScreen
      //   Ã¢â‚¬Â¢ New clients  Ã¢â€ â€™ minimal profile, go straight to ClientDashboard
      if (result.isNewUser) {
        final newProfile = UserModel(
          id: result.credential.user!.uid,
          name: result.credential.user!.displayName ?? 'New User',
          email: result.credential.user!.email ?? '',
          phone: result.credential.user!.phoneNumber ?? '',
          role: selectedRole == 'Lawyer' ? UserRole.lawyer : UserRole.client,
          // Lawyers start as unsubmitted â€” LiveDashboardRouterScreen gates them
          // to LawyerVerificationScreen before granting dashboard access.
          barCouncilVerified: selectedRole == 'Lawyer' ? false : null,
        );
        await _authService.finalizeGoogleProfile(
          credential: result.credential,
          profile: newProfile,
        );
      }

      if (!mounted) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        _showInputError('Authentication failed. Please try again.');
        return;
      }

      // The router handles all role/verification-status branching from here.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LiveDashboardRouterScreen(uid: currentUser.uid),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) _showInputError(e.message);
    } catch (e) {
      if (mounted) _showInputError(e.toString());
    } finally {
      if (mounted) setState(() => _isGoogleSubmitting = false);
    }
  }

  Future<void> _onSubmit() async {
    if (_isSubmitting) return;

    final validationError = _validateInputs();
    if (validationError != null) {
      _showInputError(validationError);
      return;
    }

    final role = selectedRole == 'Lawyer' ? UserRole.lawyer : UserRole.client;
    final email = emailController.text.trim();
    final password = passwordController.text.trim();
    final lawyerProfile = role == UserRole.lawyer
        ? (isLogin ? null : _buildPendingLawyerFromForm())
        : null;

    setState(() => _isSubmitting = true);

    try {
      // If Firebase is completely unavailable, allow local/demo mode.
      if (!FirebaseInitializer.isReady) {
        _navigateFallback(role, lawyerProfile);
        return;
      }

      final syncResult = await _authSyncService.syncSession(
        isLogin: isLogin,
        email: email,
        password: password,
        role: role,
        lawyerProfile: lawyerProfile,
      );

      if (!mounted) return;

      final currentUser = FirebaseAuth.instance.currentUser;
      // currentUser should never be null here after a successful syncSession.
      // If it is, something unexpected happened Ã¢â‚¬â€ do NOT fall back silently.
      if (currentUser == null) {
        _showInputError(
          'Authentication failed. Please check your credentials.',
        );
        return;
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => LiveDashboardRouterScreen(uid: currentUser.uid),
        ),
      );

      if (mounted && syncResult.hasIssue) {
        final message = _syncIssueMessage(syncResult);
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 6),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      // Surface Firebase credential errors directly to the user.
      final message = _friendlyAuthError(e.code);
      if (mounted) _showInputError(message);
    } catch (e) {
      // For non-auth errors (network, Firestore, etc.): allow local fallback
      // only for registration; login must always use real credentials.
      if (!isLogin) {
        _showInputError('Could not reach Firebase. Continuing in local mode.');
        _navigateFallback(role, lawyerProfile);
      } else {
        _showInputError('Could not connect to the server. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String? _syncIssueMessage(SyncSessionResult result) {
    // Only show issues during registration — login doesn't trigger verification.
    if (isLogin) return null;
    if (result.firebaseUnavailable) {
      return 'Firebase is not configured on this device. Your verification will '
          'not run until the app is set up with valid Firebase credentials.';
    }
    if (result.verificationCallError != null) {
      return 'Account created, but verification could not start. The Cloud '
          'Function may not be deployed. Contact support if this persists.';
    }
    if (result.adapterFailed) {
      return 'We could not reach the Malaysian Bar directory. Your verification '
          'has been queued for manual review.';
    }
    if (result.syncError != null) {
      return 'Account created, but profile sync hit an error. Some details may '
          'need to be re-entered.';
    }
    return null;
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'user-not-found':
        return 'No account found with this email. Please register first.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a moment and try again.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Please log in instead.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      default:
        return 'Authentication error ($code). Please try again.';
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final dialogEmailCtrl = TextEditingController(
      text: emailController.text.trim(),
    );
    bool isSending = false;
    bool sent = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: goldAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.lock_reset_rounded,
                  color: goldAccent,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Reset Password',
                style: GoogleFonts.inter(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: primaryBlue,
                ),
              ),
            ],
          ),
          content: sent
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      color: Color(0xFF16A34A),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Email sent!',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A password reset link was sent to ${dialogEmailCtrl.text.trim()}. '
                      'Check your inbox (and spam folder) and follow the link.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Enter your registered email and we'll send a reset link.",
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        key: const Key('forgot_password_email_field'),
                        controller: dialogEmailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofocus: true,
                        style: GoogleFonts.inter(
                          color: primaryBlue,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Your email address',
                          hintStyle: GoogleFonts.inter(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.email_outlined,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
          actions: sent
              ? [
                  TextButton(
                    onPressed: () => Navigator.of(dialogCtx).pop(),
                    child: Text(
                      'Done',
                      style: GoogleFonts.inter(
                        color: primaryBlue,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ]
              : [
                  TextButton(
                    onPressed: isSending
                        ? null
                        : () => Navigator.of(dialogCtx).pop(),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(color: Colors.grey[500]),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: isSending
                        ? null
                        : () async {
                            final email = dialogEmailCtrl.text.trim();
                            if (email.isEmpty || !_isValidEmail(email)) {
                              ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    email.isEmpty
                                        ? 'Please enter your email address.'
                                        : 'Please enter a valid email address.',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: const Color(0xFFB91C1C),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              return;
                            }
                            setDialogState(() => isSending = true);
                            try {
                              await _authService.sendPasswordResetEmail(email);
                              setDialogState(() {
                                isSending = false;
                                sent = true;
                              });
                            } on FirebaseAuthException catch (e) {
                              setDialogState(() => isSending = false);
                              if (dialogCtx.mounted) {
                                final msg = switch (e.code) {
                                  'user-not-found' =>
                                    'No account found with this email.',
                                  'invalid-email' =>
                                    'Please enter a valid email address.',
                                  'too-many-requests' =>
                                    'Too many attempts. Please try again later.',
                                  _ =>
                                    'Could not send reset email (${e.code}).',
                                };
                                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      msg,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFB91C1C),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (_) {
                              setDialogState(() => isSending = false);
                              if (dialogCtx.mounted) {
                                ScaffoldMessenger.of(dialogCtx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Could not send reset email. Check your connection.',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                      ),
                                    ),
                                    backgroundColor: const Color(0xFFB91C1C),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: isSending
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            'Send Reset Link',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ],
        ),
      ),
    );
    dialogEmailCtrl.dispose();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    legalFullNameController.dispose();
    barNumberController.dispose();
    firmNameController.dispose();
    practiceStateController.dispose();
    practiceCityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: Column(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            size: 36,
                            color: primaryBlue,
                          ),
                          Text(
                            'LEXIGUARD\nMALAYSIA',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 7,
                              color: primaryBlue,
                              fontWeight: FontWeight.w800,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'LexiGuard Malaysia',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your Trusted Legal Companion',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24.0,
                      vertical: 32.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => isLogin = true),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isLogin
                                          ? primaryBlue
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Login',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: isLogin
                                            ? Colors.white
                                            : Colors.grey[500],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () => setState(() => isLogin = false),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: !isLogin
                                          ? primaryBlue
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'Register',
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w600,
                                        color: !isLogin
                                            ? Colors.white
                                            : Colors.grey[500],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _buildRoleCard(
                                title: "I'm a Client",
                                icon: Icons.shield_outlined,
                                isSelected: selectedRole == 'Client',
                                activeColor: goldAccent,
                                onTap: () =>
                                    setState(() => selectedRole = 'Client'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildRoleCard(
                                title: "I'm a Lawyer",
                                icon: Icons.balance,
                                isSelected: selectedRole == 'Lawyer',
                                activeColor: goldAccent,
                                onTap: () =>
                                    setState(() => selectedRole = 'Lawyer'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          hintText: 'Email Address',
                          controller: emailController,
                          inputKey: const Key('auth_email_field'),
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(
                          hintText: 'Password',
                          controller: passwordController,
                          isPassword: true,
                          obscureText: obscurePassword,
                          inputKey: const Key('auth_password_field'),
                          onTogglePassword: () => setState(
                            () => obscurePassword = !obscurePassword,
                          ),
                        ),
                        if (showLawyerVerificationFields) ...[
                          const SizedBox(height: 16),
                          _buildVerificationCard(),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hintText: 'Legal Full Name (as on bar records)',
                            controller: legalFullNameController,
                            inputKey: const Key('lawyer_legal_name_field'),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hintText: 'Bar / Roll Number (optional)',
                            controller: barNumberController,
                            inputKey: const Key('lawyer_bar_number_field'),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hintText: 'Law Firm Name',
                            controller: firmNameController,
                            inputKey: const Key('lawyer_firm_field'),
                          ),
                          const SizedBox(height: 12),
                          _buildJurisdictionField(),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hintText: 'Practice State',
                            controller: practiceStateController,
                            inputKey: const Key('lawyer_practice_state_field'),
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hintText: 'Practice City',
                            controller: practiceCityController,
                            inputKey: const Key('lawyer_practice_city_field'),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (isLogin)
                          Row(
                            children: [
                              TextButton.icon(
                                onPressed: _openAdminLogin,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: Icon(
                                  Icons.admin_panel_settings_outlined,
                                  size: 16,
                                  color: goldAccent,
                                ),
                                label: Text(
                                  'Login as admin',
                                  style: GoogleFonts.inter(
                                    color: goldAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: _showForgotPasswordDialog,
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(50, 30),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  'Forgot Password?',
                                  style: GoogleFonts.inter(
                                    color: goldAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _onSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text(
                                  actionLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                        const SizedBox(height: 32),
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[200])),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Text(
                                'or continue with',
                                style: GoogleFonts.inter(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Expanded(child: Divider(color: Colors.grey[200])),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildGoogleSignInButton(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey[200]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : Colors.grey[400],
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                color: isSelected ? primaryBlue : Colors.grey[500],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    TextEditingController? controller,
    bool isPassword = false,
    bool? obscureText,
    Key? inputKey,
    VoidCallback? onTogglePassword,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: TextField(
        key: inputKey,
        controller: controller,
        obscureText: obscureText ?? false,
        style: GoogleFonts.inter(color: primaryBlue, fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 15),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    obscureText! ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[400],
                    size: 20,
                  ),
                  onPressed: onTogglePassword,
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildVerificationCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.verified_user_outlined,
            color: Color(0xFFB45309),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Peninsular applications start in pending sandbox mode. Sabah and Sarawak applications are routed to manual review.',
              style: GoogleFonts.inter(
                color: const Color(0xFF92400E),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJurisdictionField() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedJurisdiction,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.grey[500],
          ),
          style: GoogleFonts.inter(color: primaryBlue, fontSize: 15),
          items: const [
            DropdownMenuItem(
              value: 'peninsular',
              child: Text('Jurisdiction: Peninsular (Malaysian Bar)'),
            ),
            DropdownMenuItem(
              value: 'sabah',
              child: Text('Jurisdiction: Sabah Law Society'),
            ),
            DropdownMenuItem(
              value: 'sarawak',
              child: Text('Jurisdiction: Advocates Assoc. Sarawak'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => selectedJurisdiction = value);
          },
        ),
      ),
    );
  }

  Widget _buildGoogleSignInButton() {
    return OutlinedButton(
      onPressed: (_isSubmitting || _isGoogleSubmitting)
          ? null
          : _onGoogleSignIn,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: Colors.grey[200]!, width: 1.5),
        backgroundColor: Colors.white,
        foregroundColor: primaryBlue,
      ),
      child: _isGoogleSubmitting
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CustomPaint(painter: _GoogleGPainter()),
                ),
                const SizedBox(width: 12),
                Text(
                  isLogin ? 'Continue with Google' : 'Sign up with Google',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
    );
  }
}

class _GoogleGPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    // Draw coloured arc segments
    final segments = [
      (
        startAngle: -0.52,
        sweepAngle: 1.57,
        color: const Color(0xFF4285F4),
      ), // blue
      (
        startAngle: 1.05,
        sweepAngle: 1.57,
        color: const Color(0xFF34A853),
      ), // green
      (
        startAngle: 2.62,
        sweepAngle: 1.05,
        color: const Color(0xFFFBBC05),
      ), // yellow
      (
        startAngle: 3.67,
        sweepAngle: 1.05,
        color: const Color(0xFFEA4335),
      ), // red
    ];

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.butt;

    for (final seg in segments) {
      paint.color = seg.color;
      canvas.drawArc(
        Rect.fromCircle(center: Offset(cx, cy), radius: r * 0.78),
        seg.startAngle,
        seg.sweepAngle,
        false,
        paint,
      );
    }

    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(cx, cy - size.height * 0.09, r * 0.82, size.height * 0.18),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
