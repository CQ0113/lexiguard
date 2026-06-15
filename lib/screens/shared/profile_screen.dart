import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_model.dart';
import '../../services/profile_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.user,
    this.profileService,
    this.embedded = false,
    this.readOnly = false,
  });

  final UserModel user;
  final ProfileService? profileService;
  final bool embedded;
  final bool readOnly;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);
  static const _surface = Color(0xFFF2F2F7);

  final _formKey = GlobalKey<FormState>();
  late final ProfileService _profileService;

  late UserModel _user;
  bool isEditing = false;
  bool _isSaving = false;

  static const List<String> _availableLanguages = [
    'English',
    'Malay',
    'Mandarin',
    'Tamil',
    'Cantonese',
    'Hokkien',
    'Other',
  ];
  late List<String> _selectedLanguages;

  late final TextEditingController _fullNameController;
  late final TextEditingController _legalNameController;
  late final TextEditingController _firmController;
  late final TextEditingController _specializationController;
  late final TextEditingController _experienceController;
  late final TextEditingController _hourlyRateController;
  late final TextEditingController _phoneController;

  bool get _isLawyer => _user.role == UserRole.lawyer;

  String get _effectiveUid => _profileService.currentUid ?? _user.id;

  @override
  void initState() {
    super.initState();
    _profileService = widget.profileService ?? ProfileService();
    _user = widget.user;
    _fullNameController = TextEditingController();
    _legalNameController = TextEditingController();
    _firmController = TextEditingController();
    _specializationController = TextEditingController();
    _experienceController = TextEditingController();
    _hourlyRateController = TextEditingController();
    _phoneController = TextEditingController();
    _selectedLanguages = List<String>.from(_user.languages);
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user != widget.user && !isEditing) {
      _user = widget.user;
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _legalNameController.dispose();
    _firmController.dispose();
    _specializationController.dispose();
    _experienceController.dispose();
    _hourlyRateController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _fullNameController.text = _user.name;
    _legalNameController.text = _user.legalFullName ?? _user.name;
    _firmController.text = _user.firmName ?? '';
    _specializationController.text = _user.specialization ?? '';
    _experienceController.text = _user.yearsExperience?.toString() ?? '';
    _hourlyRateController.text = _formatNumber(_user.hourlyRate);
    _phoneController.text = _user.phone;
    _selectedLanguages = List<String>.from(_user.languages);
  }

  void _toggleEditing() {
    if (widget.readOnly) return;
    setState(() {
      if (isEditing) {
        _syncControllers();
      }
      isEditing = !isEditing;
    });
  }

  Future<void> _saveChanges() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final yearsExperience = _isLawyer
        ? int.tryParse(_experienceController.text.trim())
        : null;
    final hourlyRate = _isLawyer
        ? double.tryParse(_hourlyRateController.text.trim())
        : null;

    final updates = <String, Object?>{
      'phone': _phoneController.text.trim(),
      if (_isLawyer) ...{
        'name': _legalNameController.text.trim(),
        'legalFullName': _legalNameController.text.trim(),
        'firmName': _firmController.text.trim(),
        'specialization': _specializationController.text.trim(),
        'yearsExperience': yearsExperience,
        'hourlyRate': hourlyRate,
        'languages': _selectedLanguages,
      } else
        'name': _fullNameController.text.trim(),
    };

    setState(() => _isSaving = true);
    try {
      await _profileService.updateUserProfile(
        uid: _effectiveUid,
        fields: updates,
      );

      final localMap = _user.toMap()..addAll(updates);
      _user = UserModel.fromMap(localMap);
      _syncControllers();

      if (!mounted) return;
      setState(() => isEditing = false);
      _showSnack('Profile updated successfully.');
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _sendPasswordReset() async {
    setState(() => _isSaving = true);
    try {
      await _profileService.sendPasswordResetEmail(email: _user.email);
      if (!mounted) return;
      _showSnack('Password reset link sent to your email.');
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _changeEmail() async {
    final newEmail = await _showEmailDialog();
    final trimmedEmail = newEmail?.trim();
    if (!mounted || trimmedEmail == null || trimmedEmail.isEmpty) return;

    setState(() => _isSaving = true);
    try {
      await _profileService.verifyBeforeUpdateEmail(trimmedEmail);
      if (!mounted) return;
      _showSnack(
        'Verification link sent to $trimmedEmail. Your profile will update once verified.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(_friendlyError(error), isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<String?> _showEmailDialog() {
    return showDialog<String>(
      context: context,
      builder: (_) => _EmailChangeDialog(initialEmail: _user.email),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      children: [
        Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.embedded) _embeddedHeader(),
                _identityCard(),
                const SizedBox(height: 14),
                if (_isLawyer) _lawyerProfessionalCard() else _clientInfoCard(),
                if (_isLawyer) ...[const SizedBox(height: 14), _languagesCard()],
                const SizedBox(height: 14),
                _accountCard(),
                if (!widget.readOnly) ...[
                  const SizedBox(height: 14),
                  _securityCard(),
                ],
                if (isEditing && !widget.readOnly) ...[const SizedBox(height: 18), _saveButton()],
              ],
            ),
          ),
        ),
        if (_isSaving) _loadingOverlay(),
      ],
    );

    if (widget.embedded) return content;

    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(
          _isLawyer ? 'Lawyer Profile' : 'My Profile',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        actions: widget.readOnly ? null : [_editButton(color: Colors.white)],
      ),
      body: content,
    );
  }

  Widget _embeddedHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isLawyer ? 'Lawyer Profile' : 'My Profile',
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _isLawyer
                      ? 'Your public and professional account details.'
                      : 'Manage your account details and preferences.',
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!widget.readOnly) _editButton(color: _navy),
        ],
      ),
    );
  }

  Widget _editButton({required Color color}) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      child: IconButton(
        tooltip: isEditing ? 'Cancel editing' : 'Edit profile',
        onPressed: _isSaving ? null : _toggleEditing,
        icon: Icon(isEditing ? Icons.close_rounded : Icons.edit_outlined),
        color: color,
        style: IconButton.styleFrom(
          hoverColor: Colors.white.withOpacity(0.1),
        ),
      ),
    );
  }

  Widget _identityCard() {
    final displayName = _isLawyer
        ? _legalNameController.text
        : _fullNameController.text;

    final nameText = displayName.isEmpty ? _user.name : displayName;
    final isVerified = _user.verificationStatus == VerificationStatus.autoVerified;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0C1D36), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          // Elegant Avatar with Gold Indicator Ring
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_gold, Color(0xFFFBBF24)],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(2), // Gold ring thickness
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0C1D36),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials(nameText),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          
          // User Details Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        nameText,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified && _isLawyer) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        color: Color(0xFF38BDF8), // Light blue verified tick
                        size: 18,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _user.email,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 12.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                _roleChip(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        _isLawyer ? 'LAWYER' : 'CLIENT',
        style: GoogleFonts.inter(
          color: _gold,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _clientInfoCard() {
    return _sectionCard(
      title: 'Personal information',
      children: [
        _editableRow(
          label: 'Full Name',
          controller: _fullNameController,
          icon: Icons.person_outline_rounded,
          validator: _required('Full name is required.'),
        ),
        _gap,
        _editableRow(
          label: 'Phone',
          controller: _phoneController,
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          validator: _required('Phone number is required.'),
        ),
        _gap,
        _readOnlyRow('Account ID', _user.id, Icons.vpn_key_outlined),
      ],
    );
  }

  Widget _lawyerProfessionalCard() {
    return _sectionCard(
      title: 'Professional information',
      children: [
        _editableRow(
          label: 'Legal Name',
          controller: _legalNameController,
          icon: Icons.person_outline_rounded,
          validator: _required('Legal name is required.'),
        ),
        _gap,
        _readOnlyRow('Bar Number', _user.barNumber ?? 'Not provided', Icons.badge_outlined),
        _gap,
        _editableRow(
          label: 'Firm',
          controller: _firmController,
          icon: Icons.business_outlined,
          validator: _required('Firm name is required.'),
        ),
        _gap,
        _editableRow(
          label: 'Specialization',
          controller: _specializationController,
          icon: Icons.gavel_outlined,
          validator: _required('Specialization is required.'),
        ),
        _gap,
        _editableRow(
          label: 'Experience',
          controller: _experienceController,
          icon: Icons.work_outline_rounded,
          displayValue: _displayExperience(),
          keyboardType: TextInputType.number,
          suffixText: 'years',
          validator: _validateInt,
        ),
        _gap,
        _editableRow(
          label: 'Hourly Rate',
          controller: _hourlyRateController,
          icon: Icons.payments_outlined,
          displayValue: _displayHourlyRate(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixText: 'RM ',
          suffixText: '/ hour',
          validator: _validateRate,
        ),
      ],
    );
  }

  Widget _languagesCard() {
    return _sectionCard(
      title: 'Languages spoken',
      children: [
        Text(
          'Select the languages you can serve clients in.',
          style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
        ),
        const SizedBox(height: 12),
        if (!isEditing)
          _selectedLanguages.isEmpty
              ? Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.translate_rounded,
                          size: 20, color: Colors.grey[400]),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No languages selected yet — tap edit to add yours.',
                          style: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _selectedLanguages
                      .map(
                        (lang) => Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _gold.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _gold.withOpacity(0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle_rounded,
                                  size: 16,
                                  color: _navy.withOpacity(0.7)),
                              const SizedBox(width: 6),
                              Text(
                                lang,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _navy,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableLanguages.map((lang) {
              final selected = _selectedLanguages.contains(lang);
              return FilterChip(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                label: Text(
                  lang,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : _navy,
                  ),
                ),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _selectedLanguages.add(lang);
                    } else {
                      _selectedLanguages.remove(lang);
                    }
                  });
                },
                selectedColor: _navy,
                checkmarkColor: _gold,
                backgroundColor: const Color(0xFFF8FAFC),
                side: BorderSide(
                  color: selected ? _navy : const Color(0xFFE5E7EB),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _accountCard() {
    return _sectionCard(
      title: _isLawyer ? 'Account and verification' : 'Account',
      children: [
        if (_isLawyer) ...[
          _readOnlyRow('Status', _user.verificationStatus.label, Icons.verified_user_outlined),
          _gap,
        ],
        _readOnlyRow('Email', _user.email, Icons.email_outlined),
        if (_isLawyer) ...[
          _gap,
          _editableRow(
            label: 'Phone',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            validator: _required('Phone number is required.'),
          ),
        ],
      ],
    );
  }

  Widget _securityCard() {
    return _sectionCard(
      title: 'Security',
      children: [
        _actionRow(
          icon: Icons.mail_outline,
          title: 'Change Email',
          subtitle: 'Verify a new email before it replaces this one',
          onTap: _changeEmail,
        ),
        _gap,
        _actionRow(
          icon: Icons.lock_outline,
          title: 'Change Password',
          subtitle: 'Send a secure reset link to your current email',
          onTap: _sendPasswordReset,
        ),
      ],
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: _gold,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _editableRow({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? displayValue,
    String? prefixText,
    String? suffixText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    if (!isEditing) {
      return _readOnlyRow(
        label,
        displayValue ?? _emptyFallback(controller.text),
        icon,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          decoration: _inputDecoration(
            label,
            icon: icon,
            prefixText: prefixText,
            suffixText: suffixText,
          ),
          style: GoogleFonts.inter(
            color: _navy,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _readOnlyRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF64748B), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0xFF64748B),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _emptyFallback(value),
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: _isSaving ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _navy.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: _navy),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: _navy,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.grey[500],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: _isSaving ? null : _saveChanges,
        icon: const Icon(Icons.save_outlined, size: 18),
        label: Text(
          'Save Changes',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }

  Widget _loadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.16),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_gold),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(
    String hint, {
    required IconData icon,
    String? prefixText,
    String? suffixText,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefixText,
      suffixText: suffixText,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 18),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _gold, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB91C1C)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFB91C1C)),
      ),
    );
  }

  Widget get _gap => const SizedBox(height: 14);

  String? Function(String?) _required(String message) {
    return (value) {
      if (value == null || value.trim().isEmpty) return message;
      return null;
    };
  }

  String? _validateInt(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Experience is required.';
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 0) return 'Enter a valid year count.';
    return null;
  }

  String? _validateRate(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Hourly rate is required.';
    final parsed = double.tryParse(trimmed);
    if (parsed == null || parsed < 0) return 'Enter a valid hourly rate.';
    return null;
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError ? const Color(0xFFB91C1C) : _navy,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    return message.replaceFirst(
      RegExp(r'^(Exception|StateError|ArgumentError):\s*'),
      '',
    );
  }

  String _displayExperience() {
    final years = _user.yearsExperience;
    if (years == null) return 'Not provided';
    return years == 1 ? '1 year' : '$years years';
  }

  String _displayHourlyRate() {
    final rate = _user.hourlyRate;
    if (rate == null) return 'Not provided';
    return 'RM ${_formatNumber(rate)} / hour';
  }

  String _formatNumber(num? value) {
    if (value == null) return '';
    return value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2);
  }

  String _emptyFallback(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? 'Not provided' : trimmed;
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

}

class _EmailChangeDialog extends StatefulWidget {
  const _EmailChangeDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_EmailChangeDialog> createState() => _EmailChangeDialogState();
}

class _EmailChangeDialogState extends State<_EmailChangeDialog> {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      title: Text(
        'New Email Address',
        style: GoogleFonts.inter(color: _navy, fontWeight: FontWeight.w700),
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: _inputDecoration('Email address'),
          validator: _validateEmail,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: GoogleFonts.inter(color: _navy)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) {
              Navigator.of(context).pop(_controller.text.trim());
            }
          },
          child: Text(
            'Send Link',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _gold, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFB91C1C)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFB91C1C)),
      ),
    );
  }

  String? _validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'Email address is required.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(trimmed)) {
      return 'Enter a valid email address.';
    }
    return null;
  }
}
