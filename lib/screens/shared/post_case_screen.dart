import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/firebase/firebase_initializer.dart';
import '../../data/dummy_data.dart';
import '../../models/case_model.dart';
import '../../models/user_model.dart';
import '../../repositories/case_repository.dart';
import '../../repositories/case_action_repository.dart';

// Exact replica of the Figma-exported post-case.tsx
// Design: #0B2447 navy, #D4AF37 gold, white cards, gray-50 bg
class PostCaseScreen extends StatefulWidget {
  final UserModel poster;

  const PostCaseScreen({super.key, required this.poster});

  @override
  State<PostCaseScreen> createState() => _PostCaseScreenState();
}

class _PostCaseScreenState extends State<PostCaseScreen> {
  // ── Brand ─────────────────────────────────────────────────────────────────
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);

  // ── Categories (exact list from Figma) ────────────────────────────────────
  static const _categories = [
    'Property Dispute',
    'Family / Divorce',
    'Criminal Defense',
    'Employment Issue',
    'Corporate / Business',
    'Tenancy / Rental',
    'Syariah Law',
    'Personal Injury',
    'Banking / Finance',
    'Other',
  ];

  // ── Locations (exact list from Figma) ────────────────────────────────────
  static const _locations = [
    'Damansara, Selangor',
    'Kuala Lumpur City',
    'Petaling Jaya, Selangor',
    'Shah Alam, Selangor',
    'Bangsar, Kuala Lumpur',
    'Subang Jaya, Selangor',
    'Ampang, Selangor',
    'Cheras, Kuala Lumpur',
    'Penang, George Town',
    'Johor Bahru, Johor',
  ];

  static const _budgets = [
    'RM 100 - 200/hr',
    'RM 200 - 400/hr',
    'RM 400 - 600/hr',
    'RM 600+/hr',
    'Flexible / Negotiable',
  ];

  // ── State ─────────────────────────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _category = '';
  int _locationIdx = -1;
  String _urgency = 'medium'; // low | medium | high
  String _budget = 'RM 200 - 400/hr';
  List<PlatformFile> _files = [];
  bool _submitting = false;
  String _submitStatus = '';
  final CaseRepository _caseRepository = CaseRepository();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _titleCtrl.text.trim().isNotEmpty &&
      _category.isNotEmpty &&
      _descCtrl.text.trim().isNotEmpty &&
      _locationIdx >= 0;

  bool get _canUseFirestore {
    if (!FirebaseInitializer.isReady) return false;
    return FirebaseAuth.instance.currentUser?.uid == widget.poster.id;
  }

  Future<void> _addFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      final updated = List<PlatformFile>.from(_files);
      for (final file in result.files) {
        final alreadyAdded = updated.any(
          (item) => item.name == file.name && item.size == file.size,
        );
        if (!alreadyAdded) updated.add(file);
      }
      _files = updated;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_isValid) return;
    setState(() {
      _submitting = true;
      _submitStatus = _files.isNotEmpty ? 'Uploading attachments...' : 'Creating case...';
    });

    // Map string category to CaseCategory enum
    CaseCategory cat;
    if (_category.contains('Property') || _category.contains('Tenancy')) {
      cat = CaseCategory.property;
    } else if (_category.contains('Family') || _category.contains('Divorce')) {
      cat = CaseCategory.family;
    } else if (_category.contains('Criminal')) {
      cat = CaseCategory.criminal;
    } else if (_category.contains('Corporate') ||
        _category.contains('Banking')) {
      cat = CaseCategory.commercial;
    } else if (_category.contains('Employment')) {
      cat = CaseCategory.employment;
    } else {
      cat = CaseCategory.other;
    }

    CaseUrgency urg;
    if (_urgency == 'high') {
      urg = CaseUrgency.high;
    } else if (_urgency == 'medium') {
      urg = CaseUrgency.medium;
    } else {
      urg = CaseUrgency.low;
    }

    final caseId = 'case_${DateTime.now().millisecondsSinceEpoch}';
    final attachmentMetadata = <CaseAttachment>[];

    if (_canUseFirestore) {
      try {
        for (final file in _files) {
          final bytes = file.bytes;
          if (bytes == null) {
            throw StateError('Could not read ${file.name}. Please reattach it.');
          }

          final attachment = await _caseRepository.uploadCaseAttachmentBytes(
            caseId: caseId,
            clientId: widget.poster.id,
            bytes: bytes,
            fileName: file.name,
            contentType: _contentTypeFor(file.name),
          );
          attachmentMetadata.add(attachment);
        }
        if (mounted) {
          setState(() => _submitStatus = 'Creating case...');
        }
      } catch (error) {
        if (mounted) {
          setState(() => _submitting = false);
          _showSnack('Attachment upload failed: $error');
        }
        return;
      }
    } else if (_files.isNotEmpty) {
      attachmentMetadata.addAll(
        _files.map(
          (file) => CaseAttachment(
            id: '${caseId}_${file.name}_${file.size}',
            fileName: file.name,
            downloadUrl: '',
            storagePath: '',
            sizeBytes: file.size,
            contentType: _contentTypeFor(file.name),
            uploadedAt: DateTime.now(),
          ),
        ),
      );
    }

    final newCase = CaseModel(
      id: caseId,
      clientId: widget.poster.id,
      lawyerId: null,
      title: _titleCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      location: _locations[_locationIdx],
      budgetRange: _budget,
      category: cat,
      status: CaseStatus.pending,
      urgency: urg,
      progressPercent: 0,
      createdAt: DateTime.now(),
      interestedLawyerIds: [],
      attachments: attachmentMetadata,
    );

    var storedInFirestore = false;
    if (_canUseFirestore) {
      try {
        await _caseRepository.createCase(newCase);
        storedInFirestore = true;
        if (mounted) {
          setState(() => _submitStatus = 'Finding suitable lawyers...');
        }
        try {
          await CaseActionRepository().recommendLawyers(caseId: caseId);
        } catch (error) {
          debugPrint('Generating recommendations failed: $error');
          try {
            await _caseRepository.updateCaseRecommendationStatus(caseId, 'failed');
          } catch (updateError) {
            debugPrint('Failed to update recommendation status: $updateError');
          }
        }
      } catch (error) {
        for (final attachment in attachmentMetadata) {
          try {
            await _caseRepository.deleteCaseAttachment(attachment);
          } catch (_) {
            // The submission error is more useful to surface here.
          }
        }
        if (mounted) {
          setState(() => _submitting = false);
          _showSnack('Case submission failed: $error');
        }
        return;
      }
    }

    if (!storedInFirestore) {
      DummyData.openCases.insert(0, newCase);
    }

    if (mounted) {
      setState(() => _submitting = false);
      Navigator.of(context).pop(newCase);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Text(
                'Post Your Case',
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Describe your legal concern and we'll match you with the best lawyers nearby.",
                style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
              ),
              const SizedBox(height: 20),

              // AI matching banner
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0B2447), Color(0xFF183B6E)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: _gold,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart Matching',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'AI matches by distance + specialization proficiency',
                          style: GoogleFonts.inter(
                            color: Colors.white60,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Form fields
              _buildFieldLabel('Case Title *'),
              _buildTextInput(
                controller: _titleCtrl,
                hint: 'e.g. Landlord refusing to return deposit',
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Legal Category *'),
              _buildDropdown(
                value: _category.isEmpty ? null : _category,
                hint: 'Select category...',
                items: _categories,
                onChanged: (v) => setState(() => _category = v ?? ''),
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Describe Your Concern *'),
              _buildTextArea(),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${_descCtrl.text.length}/500',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Location label with MapPin
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: _navy,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Your Location *',
                    style: GoogleFonts.inter(
                      color: _navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _buildDropdown(
                value: _locationIdx >= 0 ? _locations[_locationIdx] : null,
                hint: 'Select your area...',
                items: _locations,
                onChanged: (v) =>
                    setState(() => _locationIdx = _locations.indexOf(v ?? '')),
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Urgency Level'),
              _buildUrgencyPills(),
              const SizedBox(height: 16),

              _buildFieldLabel('Budget Range'),
              _buildDropdown(
                value: _budget,
                hint: '',
                items: _budgets,
                onChanged: (v) => setState(() => _budget = v ?? _budget),
              ),
              const SizedBox(height: 16),

              _buildFieldLabel('Attachments'),
              ..._files.asMap().entries.map(
                (entry) => _buildFileChip(entry.value, entry.key),
              ),
              if (_files.isNotEmpty) const SizedBox(height: 8),
              _buildAttachButton(),
              const SizedBox(height: 16),

              // Privacy notice (blue-50)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF3B82F6),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your case details will be visible to verified lawyers on the platform. '
                        'Personal contact information is only shared after you choose to connect with a lawyer.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF1D4ED8),
                          fontSize: 11,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Submit button — gold when valid, gray when not
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isValid && !_submitting) ? _handleSubmit : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: (_isValid && !_submitting)
                        ? _gold
                        : Colors.grey[200],
                    disabledBackgroundColor: Colors.grey[200],
                    foregroundColor: _navy,
                    disabledForegroundColor: Colors.grey[400],
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _navy.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _submitStatus.isNotEmpty
                                  ? _submitStatus
                                  : 'Submitting...',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.auto_awesome, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Submit & Find Lawyers',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widget builders ───────────────────────────────────────────────────────

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: const Color(0xFF0B2447),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildTextInput({
    required TextEditingController controller,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 13),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0B2447)),
        ),
      ),
    );
  }

  Widget _buildTextArea() {
    return TextField(
      controller: _descCtrl,
      maxLines: 4,
      maxLength: 500,
      style: GoogleFonts.inter(fontSize: 13, height: 1.6),
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText:
            "Provide details about your legal issue, timeline, and what outcome you're hoping for...",
        hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        counterText: '',
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0B2447)),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              hint,
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
            ),
          ),
          isExpanded: true,
          icon: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Icon(
              Icons.keyboard_arrow_down,
              color: Colors.grey[400],
              size: 20,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          borderRadius: BorderRadius.circular(12),
          style: GoogleFonts.inter(
            color: const Color(0xFF0B2447),
            fontSize: 13,
          ),
          items: items
              .map((i) => DropdownMenuItem(value: i, child: Text(i)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // Urgency pills — Low=green, Medium=amber, High=red when active
  Widget _buildUrgencyPills() {
    const urgencies = [
      ('low', '🟢 Low', Color(0xFF22C55E), Color(0xFFF0FDF4)),
      ('medium', '🟡 Medium', Color(0xFFF59E0B), Color(0xFFFFFBEB)),
      ('high', '🔴 High', Color(0xFFEF4444), Color(0xFFFEF2F2)),
    ];
    return Row(
      children: urgencies.map((u) {
        final (key, label, activeColor, activeBg) = u;
        final isActive = _urgency == key;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: key != 'high' ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _urgency = key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isActive ? activeBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isActive ? activeColor : const Color(0xFFE5E7EB),
                    width: isActive ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      color: isActive ? activeColor : Colors.grey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFileChip(PlatformFile file, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            color: Color(0xFF0B2447),
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              file.name,
              style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 12),
            ),
          ),
          Text(
            _formatFileSize(file.size),
            style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 11),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() {
              _files = List<PlatformFile>.from(_files)..removeAt(index);
            }),
            child: Icon(Icons.close, color: Colors.grey[400], size: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildAttachButton() {
    return GestureDetector(
      onTap: _addFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            style: BorderStyle.solid,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_file, color: Colors.grey[400], size: 16),
            const SizedBox(width: 6),
            Text(
              'Attach documents (PDF, JPG, PNG)',
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  String _contentTypeFor(String fileName) {
    final extension = fileName.split('.').last.toLowerCase();
    switch (extension) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
