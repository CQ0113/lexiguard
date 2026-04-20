import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_model.dart';
import '../../repositories/lawyer_profile_repository.dart';
import '../../repositories/user_repository.dart';
import '../../repositories/verification_review_repository.dart';
import '../lawyer/lawyer_dashboard_screen.dart';

/// Shown to a lawyer who registered via Google Sign-In (or any path that
/// resulted in [VerificationStatus.unsubmitted]) so they can complete their
/// bar council verification details before accessing the dashboard.
class LawyerVerificationScreen extends StatefulWidget {
  const LawyerVerificationScreen({super.key, required this.user});

  final UserModel user;

  @override
  State<LawyerVerificationScreen> createState() =>
      _LawyerVerificationScreenState();
}

class _LawyerVerificationScreenState extends State<LawyerVerificationScreen> {
  final Color primaryBlue = const Color(0xFF0C1D36);
  final Color goldAccent = const Color(0xFFCFA92A);

  final _legalNameController = TextEditingController();
  final _barNumberController = TextEditingController();
  final _firmNameController = TextEditingController();
  final _practiceStateController = TextEditingController();
  final _practiceCityController = TextEditingController();

  String _jurisdiction = 'peninsular';
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill name from the Google account if available
    _legalNameController.text = widget.user.name;
  }

  @override
  void dispose() {
    _legalNameController.dispose();
    _barNumberController.dispose();
    _firmNameController.dispose();
    _practiceStateController.dispose();
    _practiceCityController.dispose();
    super.dispose();
  }

  VerificationStatus get _initialStatus => _jurisdiction == 'peninsular'
      ? VerificationStatus.pending
      : VerificationStatus.manualReviewRequired;

  String get _verificationProvider {
    switch (_jurisdiction) {
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

  String? _validate() {
    if (_legalNameController.text.trim().isEmpty) {
      return 'Legal full name is required.';
    }
    if (_firmNameController.text.trim().isEmpty) {
      return 'Law firm name is required.';
    }
    if (_practiceStateController.text.trim().isEmpty) {
      return 'Practice state is required.';
    }
    if (_practiceCityController.text.trim().isEmpty) {
      return 'Practice city is required.';
    }
    return null;
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFFB91C1C),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      _showError(error);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final uid = widget.user.id;
      final status = _initialStatus;

      final updatedProfile = UserModel(
        id: uid,
        name: widget.user.name,
        email: widget.user.email,
        phone: widget.user.phone,
        role: UserRole.lawyer,
        barCouncilVerified: false,
        verificationStatus: status,
        verificationProvider: _verificationProvider,
        verificationBadgeVisible: false,
        legalFullName: _legalNameController.text.trim(),
        barNumber: _barNumberController.text.trim().isNotEmpty
            ? _barNumberController.text.trim()
            : null,
        firmName: _firmNameController.text.trim(),
        jurisdiction: _jurisdiction,
        practiceState: _practiceStateController.text.trim(),
        practiceCity: _practicyCityController.text.trim(),
      );

      // 1. Update the users document with full verification info
      await UserRepository().upsertUser(
        uid: uid,
        payload: {
          ...updatedProfile.toMap(),
          'updatedAt': now,
        },
      );

      // 2. Write to lawyer_profiles collection
      await LawyerProfileRepository().upsertProfile(
        uid: uid,
        profile: updatedProfile,
      );

      // 3. Enqueue in verification_requests
      if (updatedProfile.isPendingLike) {
        await VerificationReviewRepository().enqueueRegistrationReview(
          uid: uid,
          profile: updatedProfile,
        );
      }

      // 4. Trigger Cloud Function (best-effort — failures are non-fatal)
      bool adapterFailed = false;
      try {
        final callable =
            FirebaseFunctions.instance.httpsCallable('startVerification');
        final result = await callable.call({
          'uid': uid,
          'legalFullName': updatedProfile.legalFullName ?? updatedProfile.name,
          'barOrRollNumber': updatedProfile.barNumber,
          'firmName': updatedProfile.firmName,
          'jurisdiction': updatedProfile.jurisdiction ?? 'peninsular',
          'practiceState': updatedProfile.practiceState,
          'practiceCity': updatedProfile.practiceCity,
        });
        final adapterStatus =
            (result.data as Map<Object?, Object?>?)?['adapterStatus']
                as String?;
        adapterFailed = adapterStatus == 'request_failed';
      } catch (_) {
        adapterFailed = true;
      }

      if (!mounted) return;

      // Navigate to lawyer dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LawyerDashboardScreen(user: updatedProfile),
        ),
      );

      // Show confirmation snackbar
      final message = adapterFailed
          ? 'Verification queued for manual review. Our team will contact you within 48 hours.'
          : status == VerificationStatus.manualReviewRequired
              ? 'East Malaysia verification submitted. Our team will review within 48 hours.'
              : 'Verification submitted. You are now in pending sandbox mode.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: const Color(0xFF1E3A8A),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (mounted) _showError('Submission failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlue,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.verified_user_outlined,
                        size: 36,
                        color: primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Complete Your Verification',
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'As a lawyer, you need to submit your bar council details\nbefore accessing your dashboard.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),

            // ── Form card ───────────────────────────────────────────────────
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(32)),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Info card
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFFBEB),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFDE68A)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: Color(0xFFB45309),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Peninsular applications start in pending sandbox mode. '
                                  'Sabah and Sarawak applications go to manual review.',
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
                        ),
                        const SizedBox(height: 24),

                        _label('Legal Full Name (as on bar records)'),
                        const SizedBox(height: 6),
                        _field(
                          controller: _legalNameController,
                          hint: 'e.g. Ahmad Bin Abdullah',
                          inputKey: const Key('v_legal_name'),
                        ),
                        const SizedBox(height: 16),

                        _label('Bar / Roll Number (optional)'),
                        const SizedBox(height: 6),
                        _field(
                          controller: _barNumberController,
                          hint: 'e.g. B/123/2020',
                          inputKey: const Key('v_bar_number'),
                        ),
                        const SizedBox(height: 16),

                        _label('Law Firm Name'),
                        const SizedBox(height: 6),
                        _field(
                          controller: _firmNameController,
                          hint: 'e.g. Messrs. Tan & Associates',
                          inputKey: const Key('v_firm_name'),
                        ),
                        const SizedBox(height: 16),

                        _label('Jurisdiction'),
                        const SizedBox(height: 6),
                        _jurisdictionDropdown(),
                        const SizedBox(height: 16),

                        _label('Practice State'),
                        const SizedBox(height: 6),
                        _field(
                          controller: _practiceStateController,
                          hint: 'e.g. Selangor',
                          inputKey: const Key('v_practice_state'),
                        ),
                        const SizedBox(height: 16),

                        _label('Practice City'),
                        const SizedBox(height: 6),
                        _field(
                          controller: _practiceCityController,
                          hint: 'e.g. Petaling Jaya',
                          inputKey: const Key('v_practice_city'),
                        ),
                        const SizedBox(height: 32),

                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _submit,
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
                                  'Submit Verification & Start Sandbox',
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
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

  Widget _label(String text) => Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: primaryBlue,
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    Key? inputKey,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        key: inputKey,
        controller: controller,
        style: GoogleFonts.inter(color: primaryBlue, fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _jurisdictionDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _jurisdiction,
          isExpanded: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.grey[500],
          ),
          style: GoogleFonts.inter(color: primaryBlue, fontSize: 14),
          items: const [
            DropdownMenuItem(
              value: 'peninsular',
              child: Text('Peninsular (Malaysian Bar)'),
            ),
            DropdownMenuItem(
              value: 'sabah',
              child: Text('Sabah Law Society'),
            ),
            DropdownMenuItem(
              value: 'sarawak',
              child: Text('Advocates Assoc. Sarawak'),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _jurisdiction = val);
          },
        ),
      ),
    );
  }

  // Typo-safe alias used in _submit
  TextEditingController get _practicyCityController => _practiceCityController;
}
