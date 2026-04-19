import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../data/dummy_data.dart';
import '../models/user_model.dart';
import '../services/firebase_auth_sync_service.dart';
import 'client/client_dashboard_screen.dart';
import 'lawyer/lawyer_dashboard_screen.dart';

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
    final template = DummyData.firstPendingLawyer;
    final jurisdiction = selectedJurisdiction;
    final initialStatus = _initialStatusForJurisdiction(jurisdiction);
    final legalName = legalFullNameController.text.trim();
    final barNumber = barNumberController.text.trim();
    final firmName = firmNameController.text.trim();
    final practiceState = practiceStateController.text.trim();
    final practiceCity = practiceCityController.text.trim();

    return UserModel(
      id: '${template.id}_new',
      name: legalName,
      email: emailController.text.trim(),
      phone: template.phone,
      role: UserRole.lawyer,
      avatarUrl: template.avatarUrl,
      barNumber: barNumber.isNotEmpty ? barNumber : null,
      specialization: template.specialization,
      hourlyRate: template.hourlyRate,
      rating: template.rating,
      yearsExperience: template.yearsExperience,
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

  void _onSubmit() {
    final validationError = _validateInputs();
    if (validationError != null) {
      _showInputError(validationError);
      return;
    }

    final role = selectedRole == 'Lawyer' ? UserRole.lawyer : UserRole.client;

    if (selectedRole == 'Client') {
      unawaited(
        _authSyncService.syncSession(
          isLogin: isLogin,
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
          role: role,
        ),
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ClientDashboardScreen(
            user: DummyData.users.firstWhere((u) => u.role == UserRole.client),
          ),
        ),
      );
      return;
    }

    final lawyer = isLogin
        ? DummyData.firstVerifiedLawyer
        : _buildPendingLawyerFromForm();

    unawaited(
      _authSyncService.syncSession(
        isLogin: isLogin,
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        role: role,
        lawyerProfile: isLogin ? null : lawyer,
      ),
    );

    Navigator.push(
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
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => _showInputError(
                                'Forgot password is not wired yet in demo mode.',
                              ),
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(50, 30),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                          ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _onSubmit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
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
                        const SizedBox(height: 24),
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
}
