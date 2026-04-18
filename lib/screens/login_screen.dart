import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../services/auth_service.dart';
import 'client/client_dashboard_screen.dart';
import 'lawyer/lawyer_dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();

  String selectedRole = 'Client'; // 'Client' or 'Lawyer'
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isForgotLoading = false;

  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  static const Color _primaryBlue = Color(0xFF0C1D36);
  static const Color _goldAccent = Color(0xFFCFA92A);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ─── Sign In ──────────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() => _isLoading = true);

    try {
      await _authService.signIn(
        email: email,
        password: password,
        role: selectedRole,
      );

      // We don't push a new route here. The AuthGate in main.dart listens to 
      // the auth state change and will seamlessly swap the LoginScreen with the Dashboard!
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyFirebaseError(e.code));
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Something went wrong. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── Forgot Password ──────────────────────────────────────────────────────

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Enter your email above, then tap Forgot Password.');
      return;
    }

    setState(() => _isForgotLoading = true);
    try {
      await _authService.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password reset email sent to $email',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _showError(_friendlyFirebaseError(e.code));
    } finally {
      if (mounted) setState(() => _isForgotLoading = false);
    }
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFFD32F2F),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _friendlyFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for this email. Please register first.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      default:
        return 'Sign in failed. Please try again.';
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: _primaryBlue,
        body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header
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
                          Icon(Icons.shield_outlined,
                              size: 36, color: _primaryBlue),
                          Text(
                            'LEXIGUARD\nMALAYSIA',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 7,
                              color: _primaryBlue,
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

            // Bottom Sheet
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(32)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24.0, vertical: 32.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Role selection
                        Row(
                          children: [
                            Expanded(
                              child: _buildRoleCard(
                                title: "I'm a Client",
                                icon: Icons.shield_outlined,
                                isSelected: selectedRole == 'Client',
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
                                onTap: () =>
                                    setState(() => selectedRole = 'Lawyer'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),

                        Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Email
                              _buildTextField(
                                controller: _emailController,
                                hintText: 'Email Address',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Please enter your email';
                                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v.trim())) {
                                    return 'Please enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Password
                              _buildTextField(
                                controller: _passwordController,
                                hintText: 'Password',
                                icon: Icons.lock_outline,
                                isPassword: true,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _signIn(),
                                onTogglePassword: () => setState(
                                    () => _obscurePassword = !_obscurePassword),
                                validator: (v) {
                                  if (v == null || v.isEmpty) return 'Please enter your password';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 12),

                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: _isForgotLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : TextButton(
                                        onPressed: _forgotPassword,
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: const Size(50, 30),
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: Text(
                                          'Forgot Password?',
                                          style: GoogleFonts.inter(
                                            color: _goldAccent,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                              ),
                              const SizedBox(height: 24),

                              // Sign In Button
                              ElevatedButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _primaryBlue,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor:
                                      _primaryBlue.withValues(alpha: 0.6),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
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
                                        'Sign In',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Register CTA
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: GoogleFonts.inter(
                                color: Colors.grey[500],
                                fontSize: 14,
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RegisterScreen(
                                      initialRole: selectedRole,
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                'Register',
                                style: GoogleFonts.inter(
                                  color: _goldAccent,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: Colors.grey[200])),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0),
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
    ),
  );
}

  Widget _buildRoleCard({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color:
              isSelected ? _goldAccent.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? _goldAccent : Colors.grey[200]!,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? _goldAccent : Colors.grey[400],
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(
                color: isSelected ? _primaryBlue : Colors.grey[500],
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    IconData? icon,
    bool isPassword = false,
    bool? obscureText,
    VoidCallback? onTogglePassword,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    Function(String)? onFieldSubmitted,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText ?? false,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      validator: validator,
      style: GoogleFonts.inter(color: _primaryBlue, fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 15),
        prefixIcon: icon != null ? Icon(icon, color: Colors.grey[400], size: 20) : null,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }
}
