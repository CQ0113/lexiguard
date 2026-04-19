import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  final String initialRole; // 'Client' or 'Lawyer'

  const RegisterScreen({super.key, required this.initialRole});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _authService = AuthService();

  // Step controller
  int _currentStep = 0;

  // Role
  late String _selectedRole;

  // Step 1 controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  // Step 2 (lawyer) controllers
  final _barNumberController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  final _yearsExpController = TextEditingController();
  String? _selectedSpecialization;

  // Form keys
  final _step1Key = GlobalKey<FormState>();
  final _step2Key = GlobalKey<FormState>();

  bool _isLoading = false;

  // Design tokens
  static const Color _primaryBlue = Color(0xFF0C1D36);
  static const Color _goldAccent = Color(0xFFCFA92A);

  final List<String> _specializations = [
    'Criminal Law',
    'Civil Law',
    'Corporate Law',
    'Family Law',
    'Immigration Law',
    'Intellectual Property',
    'Labour Law',
    'Property Law',
    'Syariah Law',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.initialRole;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _barNumberController.dispose();
    _hourlyRateController.dispose();
    _yearsExpController.dispose();
    super.dispose();
  }

  // ─── Navigation ─────────────────────────────────────────────────────────────

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_step1Key.currentState!.validate()) return;
    } else if (_currentStep == 1 && _selectedRole == 'Lawyer') {
      if (!_step2Key.currentState!.validate()) return;
    }
    if (_currentStep < _effectiveTotalSteps - 1) {
      setState(() => _currentStep++);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep--);
  }

  int get _effectiveTotalSteps =>
      _selectedRole == 'Lawyer' ? 3 : 2; // step 2 is lawyer-only

  // ─── Submit ──────────────────────────────────────────────────────────────────

  Future<void> _register() async {
    setState(() => _isLoading = true);
    try {
      await _authService.register(
        name: _nameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        phone: _phoneController.text,
        role: _selectedRole,
        barNumber: _selectedRole == 'Lawyer' ? _barNumberController.text : null,
        specialization: _selectedRole == 'Lawyer'
            ? (_selectedSpecialization ?? '')
            : null,
        hourlyRate:
            _selectedRole == 'Lawyer' && _hourlyRateController.text.isNotEmpty
            ? double.tryParse(_hourlyRateController.text)
            : null,
        yearsExperience:
            _selectedRole == 'Lawyer' && _yearsExpController.text.isNotEmpty
            ? int.tryParse(_yearsExpController.text)
            : null,
      );

      // AuthGate responds automatically to the authentication and shows the dashboard.
      if (mounted) {
        Navigator.pop(
          context,
        ); // Pop the register screen since it was pushed on top of AuthGate
      }
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyFirebaseError(e.code));
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (e) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _friendlyFirebaseError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered. Please log in.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Registration failed. Please try again.';
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _primaryBlue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
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
                  child: Column(
                    children: [
                      _buildStepIndicator(),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                          child: _buildCurrentStep(),
                        ),
                      ),
                      _buildNavigationButtons(),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create Account',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Join as a $_selectedRole',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = _selectedRole == 'Lawyer'
        ? ['Personal Info', 'Professional', 'Review']
        : ['Personal Info', 'Review'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Row(
        children: List.generate(steps.length, (i) {
          final isActive = i == _currentStep;
          final isCompleted = i < _currentStep;
          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          if (i > 0)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: isCompleted
                                    ? _goldAccent
                                    : Colors.grey[200],
                              ),
                            ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _primaryBlue
                                  : isCompleted
                                  ? _goldAccent
                                  : Colors.grey[100],
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isActive
                                    ? _primaryBlue
                                    : isCompleted
                                    ? _goldAccent
                                    : Colors.grey[300]!,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: isCompleted
                                  ? const Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16,
                                    )
                                  : Text(
                                      '${i + 1}',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: isActive
                                            ? Colors.white
                                            : Colors.grey[400],
                                      ),
                                    ),
                            ),
                          ),
                          if (i < steps.length - 1)
                            Expanded(
                              child: Container(
                                height: 2,
                                color: i < _currentStep
                                    ? _goldAccent
                                    : Colors.grey[200],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[i],
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: isActive
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isActive ? _primaryBlue : Colors.grey[400],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_currentStep == 0) return _buildStep1();
    if (_currentStep == 1 && _selectedRole == 'Lawyer') return _buildStep2();
    return _buildReviewStep();
  }

  // ─── Step 1: Personal Info ────────────────────────────────────────────────

  Widget _buildStep1() {
    return Form(
      key: _step1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionLabel('Role'),
          const SizedBox(height: 10),
          Row(
            children: ['Client', 'Lawyer'].map((role) {
              final isSelected = _selectedRole == role;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: role == 'Client' ? 8 : 0,
                    left: role == 'Lawyer' ? 8 : 0,
                  ),
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedRole = role),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? _goldAccent.withValues(alpha: 0.08)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? _goldAccent : Colors.grey[200]!,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            role == 'Client'
                                ? Icons.shield_outlined
                                : Icons.balance,
                            color: isSelected ? _goldAccent : Colors.grey[400],
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            role,
                            style: GoogleFonts.inter(
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: isSelected
                                  ? _primaryBlue
                                  : Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          _buildSectionLabel('Full Name'),
          const SizedBox(height: 8),
          _buildFormField(
            controller: _nameController,
            hint: 'e.g. Ahmad bin Abdullah',
            icon: Icons.person_outline,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Name is required' : null,
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('Email Address'),
          const SizedBox(height: 8),
          _buildFormField(
            controller: _emailController,
            hint: 'you@example.com',
            icon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(
                r'^[\w-.]+@([\w-]+\.)+[\w]{2,}$',
              ).hasMatch(v.trim())) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('Phone Number'),
          const SizedBox(height: 8),
          _buildFormField(
            controller: _phoneController,
            hint: '+60 12-345 6789',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\s]')),
            ],
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Phone is required' : null,
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('Password'),
          const SizedBox(height: 8),
          _buildFormField(
            controller: _passwordController,
            hint: 'At least 6 characters',
            icon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('Confirm Password'),
          const SizedBox(height: 8),
          _buildFormField(
            controller: _confirmPasswordController,
            hint: 'Repeat your password',
            icon: Icons.lock_outline,
            obscureText: _obscureConfirm,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                color: Colors.grey[400],
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Please confirm password';
              if (v != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Lawyer Professional Info ────────────────────────────────────

  Widget _buildStep2() {
    return Form(
      key: _step2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _goldAccent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _goldAccent.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: _goldAccent, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your credentials will be reviewed by the Bar Council for verification.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _primaryBlue,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionLabel('Bar Council Number'),
          const SizedBox(height: 8),
          _buildFormField(
            controller: _barNumberController,
            hint: 'e.g. BAR/MY/2018/12345',
            icon: Icons.badge_outlined,
            validator: (v) =>
                v == null || v.trim().isEmpty ? 'Bar number is required' : null,
          ),
          const SizedBox(height: 16),
          _buildSectionLabel('Area of Specialization'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _selectedSpecialization,
              hint: Text(
                'Select specialization',
                style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 15),
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
              ),
              icon: Icon(Icons.expand_more, color: Colors.grey[400]),
              items: _specializations.map((s) {
                return DropdownMenuItem(
                  value: s,
                  child: Text(
                    s,
                    style: GoogleFonts.inter(fontSize: 15, color: _primaryBlue),
                  ),
                );
              }).toList(),
              onChanged: (v) => setState(() => _selectedSpecialization = v),
              validator: (v) => v == null ? 'Specialization is required' : null,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('Hourly Rate (MYR)'),
                    const SizedBox(height: 8),
                    _buildFormField(
                      controller: _hourlyRateController,
                      hint: 'e.g. 250',
                      icon: Icons.attach_money,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionLabel('Years Experience'),
                    const SizedBox(height: 8),
                    _buildFormField(
                      controller: _yearsExpController,
                      hint: 'e.g. 8',
                      icon: Icons.work_outline,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Review Step ─────────────────────────────────────────────────────────

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionLabel('Review Your Information'),
        const SizedBox(height: 16),
        _buildReviewCard(
          title: 'Personal Details',
          icon: Icons.person_outline,
          items: {
            'Role': _selectedRole,
            'Full Name': _nameController.text,
            'Email': _emailController.text,
            'Phone': _phoneController.text,
          },
        ),
        if (_selectedRole == 'Lawyer') ...[
          const SizedBox(height: 16),
          _buildReviewCard(
            title: 'Professional Details',
            icon: Icons.balance,
            items: {
              'Bar Number': _barNumberController.text,
              'Specialization': _selectedSpecialization ?? '',
              if (_hourlyRateController.text.isNotEmpty)
                'Hourly Rate': 'RM ${_hourlyRateController.text}/hr',
              if (_yearsExpController.text.isNotEmpty)
                'Experience': '${_yearsExpController.text} years',
            },
          ),
        ],
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _primaryBlue.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _primaryBlue.withValues(alpha: 0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.verified_user_outlined, color: _primaryBlue, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'By registering, you agree to LexiGuard\'s Terms of Service and Privacy Policy.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard({
    required String title,
    required IconData icon,
    required Map<String, String> items,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 18, color: _goldAccent),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: _primaryBlue,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey[100]),
          ...items.entries.map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      e.key,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.value.isEmpty ? '—' : e.value,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: _primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Bottom Navigation ────────────────────────────────────────────────────

  Widget _buildNavigationButtons() {
    final isLastStep = _currentStep == _effectiveTotalSteps - 1;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _isLoading ? null : _prevStep,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'Back',
                  style: GoogleFonts.inter(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isLoading
                  ? null
                  : (isLastStep ? _register : _nextStep),
              style: ElevatedButton.styleFrom(
                backgroundColor: isLastStep ? _goldAccent : _primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : Text(
                      isLastStep ? 'Create Account' : 'Continue',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Reusable Widgets ────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: _primaryBlue,
      ),
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.inter(color: _primaryBlue, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 15),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFF1F5F9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _primaryBlue.withValues(alpha: 0.4)),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD32F2F)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD32F2F)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
