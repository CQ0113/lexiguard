import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/vault_document_model.dart';
import '../../repositories/vault_document_repository.dart';

class ContractReviewScreen extends StatefulWidget {
  final VaultDocumentModel contract;
  final bool isDemo;

  const ContractReviewScreen({
    super.key,
    required this.contract,
    this.isDemo = false,
  });

  @override
  State<ContractReviewScreen> createState() => _ContractReviewScreenState();
}

class _ContractReviewScreenState extends State<ContractReviewScreen> with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);
  static const _grey = Color(0xFF64748B);
  static const _goldLight = Color(0xFFFFF9E6);

  final VaultDocumentRepository _repository = VaultDocumentRepository();

  // Signature lines
  List<DrawPoint> _points = [];
  int _currentStroke = 0;

  bool _agreeToTerms = false;
  bool _confirmSignature = false;
  bool _isSigning = false;
  bool _success = false;

  late AnimationController _successController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _successController,
      curve: Curves.elasticOut,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _successController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  Future<void> _viewDocument() async {
    final urlString = widget.contract.downloadUrl;
    if (urlString.isEmpty) {
      _showSnack('Document download link is currently unavailable.');
      return;
    }

    final url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        _showSnack('Unable to open document draft.');
      }
    } catch (e) {
      _showSnack('Error opening document: $e');
    }
  }

  void _clearCanvas() {
    setState(() {
      _points.clear();
      _currentStroke = 0;
    });
  }

  Future<void> _submitSignature() async {
    if (!_agreeToTerms || !_confirmSignature) {
      _showSnack('Please complete and confirm the legal verification checkboxes.');
      return;
    }

    if (_points.isEmpty) {
      _showSnack('Please sign on the signature canvas before finalizing.');
      return;
    }

    setState(() => _isSigning = true);

    // Convert Points into Firestore-compatible list of maps
    final signatureData = _points
        .map((p) => {
              'x': p.offset.dx,
              'y': p.offset.dy,
              'stroke': p.strokeIndex,
            })
        .toList();

    try {
      if (!widget.isDemo) {
        await _repository.signContract(
          documentId: widget.contract.id,
          signaturePoints: signatureData,
        );
      } else {
        // Simulated latency in demo mode
        await Future<void>.delayed(const Duration(milliseconds: 1000));
      }

      setState(() {
        _isSigning = false;
        _success = true;
      });

      _successController.forward();
    } catch (e) {
      setState(() => _isSigning = false);
      _showSnack('Signing failed: $e');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final typeLabel = widget.contract.contractType == 'tenancy'
        ? 'Tenancy Agreement'
        : widget.contract.contractType == 'representation'
            ? 'Representation Agreement'
            : 'Legal Contract';

    final isSigned = widget.contract.contractStatus == 'signed' || _success;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          isSigned ? 'Finalized Agreement' : 'Review & Sign Contract',
          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top header card
                _buildHeaderCard(typeLabel, isSigned),
                const SizedBox(height: 24),

                // Terms detail grid
                Text(
                  'Agreement Terms',
                  style: GoogleFonts.inter(color: _navy, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildTermsDetailGrid(),
                const SizedBox(height: 24),

                // Scope section (only for representation)
                if (widget.contract.contractTerms != null && widget.contract.contractTerms!['scope'] != null) ...[
                  Text(
                    'Scope of Legal Work',
                    style: GoogleFonts.inter(color: _navy, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      widget.contract.contractTerms!['scope'] as String? ?? '',
                      style: GoogleFonts.inter(color: _navy, fontSize: 13, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // View draft button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _viewDocument,
                    icon: const Icon(Icons.file_open_outlined, size: 16),
                    label: Text(
                      isSigned ? 'View Signed Document' : 'View Original Draft File',
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: _navy, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // AI summary block!
                if (widget.contract.contractTerms != null && widget.contract.contractTerms!['aiReview'] != null) ...[
                  _buildAiReviewPanel(widget.contract.contractTerms!['aiReview'] as Map<String, dynamic>),
                  const SizedBox(height: 32),
                ],

                // E-Signature Section
                if (!isSigned) ...[
                  if (widget.contract.contractTerms != null && widget.contract.contractTerms!['aiReview'] != null)
                    _buildSignatureAssistantCard(widget.contract.contractTerms!['aiReview'] as Map<String, dynamic>?),
                  const SizedBox(height: 32),
                  Text(
                    'Draw Digital Signature',
                    style: GoogleFonts.inter(color: _navy, fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Please sign inside the canvas box below using your finger',
                    style: GoogleFonts.inter(color: _grey, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  _buildSignaturePad(),
                  const SizedBox(height: 24),
                  _buildConsentCheckboxes(),
                  const SizedBox(height: 32),
                  _buildSignSubmitButton(),
                ] else ...[
                  _buildCompletedSignatureView(),
                ],

                const SizedBox(height: 40),
              ],
            ),
          ),
          
          // Success Overlay Animation
          if (_success) _buildSuccessAnimationOverlay(),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(String typeLabel, bool isSigned) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _navy.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isSigned ? const Color(0xFF22C55E).withOpacity(0.2) : _gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isSigned ? 'FORMALIZED & ACTIVE' : 'PENDING ACTION',
                  style: GoogleFonts.inter(
                    color: isSigned ? const Color(0xFF4ADE80) : _gold,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Icon(Icons.shield_outlined, color: _gold, size: 22),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            typeLabel,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.contract.fileName,
            style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contract Ref ID', style: GoogleFonts.inter(color: Colors.white38, fontSize: 9)),
                  Text(widget.contract.id, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Lawyer ID', style: GoogleFonts.inter(color: Colors.white38, fontSize: 9)),
                  Text(widget.contract.ownerUserId, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermsDetailGrid() {
    final terms = widget.contract.contractTerms ?? {};
    final type = terms['type'] ?? 'custom';

    if (type == 'tenancy') {
      final rent = terms['monthlyRent'] ?? 0.0;
      final deposit = terms['deposit'] ?? 0.0;
      final duration = terms['durationMonths'] ?? 12;

      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.1,
        children: [
          _buildGridTermItem(Icons.home_work_outlined, 'Monthly Rent', 'RM $rent'),
          _buildGridTermItem(Icons.payments_outlined, 'Rent Deposit', 'RM $deposit'),
          _buildGridTermItem(Icons.calendar_month_outlined, 'Duration', '$duration Months'),
        ],
      );
    } else if (type == 'representation') {
      final hourly = terms['hourlyRate'] ?? 0.0;
      final retainer = terms['fixedRetainer'] ?? 0.0;

      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.6,
        children: [
          _buildGridTermItem(Icons.attach_money_rounded, 'Retainer Fee', 'RM $retainer'),
          _buildGridTermItem(Icons.hourglass_empty_rounded, 'Hourly Rate', 'RM $hourly'),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        'Terms are fully outlined in the drafted PDF file linked below.',
        style: GoogleFonts.inter(color: _navy, fontSize: 12),
      ),
    );
  }

  Widget _buildGridTermItem(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: _gold, size: 18),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(color: _grey, fontSize: 10, fontWeight: FontWeight.w500),
          ),
          Text(
            value,
            style: GoogleFonts.inter(color: _navy, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildSignaturePad() {
    return Container(
      height: 200,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
      ),
      child: Stack(
        children: [
          GestureDetector(
            onPanStart: (details) {
              setState(() {
                _points.add(DrawPoint(
                  offset: details.localPosition,
                  strokeIndex: _currentStroke,
                ));
              });
            },
            onPanUpdate: (details) {
              setState(() {
                _points.add(DrawPoint(
                  offset: details.localPosition,
                  strokeIndex: _currentStroke,
                ));
              });
            },
            onPanEnd: (_) {
              setState(() {
                _currentStroke++;
              });
            },
            child: CustomPaint(
              painter: SignaturePainter(points: _points),
              size: Size.infinite,
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: TextButton.icon(
              onPressed: _clearCanvas,
              icon: const Icon(Icons.clear, size: 14, color: Color(0xFFEF4444)),
              label: Text(
                'Clear Canvas',
                style: GoogleFonts.inter(color: const Color(0xFFEF4444), fontSize: 11, fontWeight: FontWeight.bold),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentCheckboxes() {
    return Column(
      children: [
        _buildCheckboxRow(
          value: _agreeToTerms,
          onChanged: (val) => setState(() => _agreeToTerms = val ?? false),
          text: 'I declare that I have fully read and accept all general and specific terms outlined in this agreement draft.',
        ),
        const SizedBox(height: 12),
        _buildCheckboxRow(
          value: _confirmSignature,
          onChanged: (val) => setState(() => _confirmSignature = val ?? false),
          text: 'I verify that the hand-drawn mark on the signature pad is my official representation and legally validates this contract.',
        ),
      ],
    );
  }

  Widget _buildCheckboxRow({
    required bool value,
    required ValueChanged<bool?> onChanged,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: _navy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(color: _navy, fontSize: 12, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildSignSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isSigning ? null : _submitSignature,
        icon: _isSigning
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
              )
            : const Icon(Icons.edit_document, size: 16),
        label: Text(
          _isSigning ? 'Logging Digital Signature...' : 'Legally Finalize & Sign Agreement',
          style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF22C55E),
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedSignatureView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Official Digital Signature',
          style: GoogleFonts.inter(color: _navy, fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Container(
          height: 140,
          width: double.infinity,
          decoration: BoxDecoration(
            color: _goldLight,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _gold.withOpacity(0.3), width: 1.5),
          ),
          child: Stack(
            children: [
              // Drawn Signature (if present)
              if (widget.contract.signaturePoints != null || _points.isNotEmpty)
                Center(
                  child: CustomPaint(
                    painter: SignaturePainter(
                      points: _points.isNotEmpty
                          ? _points
                          : (widget.contract.signaturePoints ?? [])
                              .map((p) => DrawPoint(
                                    offset: Offset(p['x'] as double, p['y'] as double),
                                    strokeIndex: p['stroke'] as int? ?? 0,
                                  ))
                              .toList(),
                    ),
                    size: Size.infinite,
                  ),
                )
              else
                Center(
                  child: Text(
                    'DIGITALLY E-SIGNED',
                    style: GoogleFonts.inter(color: _gold.withOpacity(0.6), fontWeight: FontWeight.bold, letterSpacing: 2),
                  ),
                ),

              // Sign overlay stamp
              Positioned(
                top: 10,
                left: 16,
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: Color(0xFF22C55E), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      'SECURELY SIGNED',
                      style: GoogleFonts.inter(color: const Color(0xFF15803D), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessAnimationOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.85),
      width: double.infinity,
      height: double.infinity,
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 110,
                  height: 110,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDCFCE7),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Container(
                      width: 82,
                      height: 82,
                      decoration: const BoxDecoration(
                        color: Color(0xFF22C55E),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Colors.white,
                        size: 46,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              FadeTransition(
                opacity: _opacityAnimation,
                child: Column(
                  children: [
                    Text(
                      'Working Relationship Formalized!',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You have successfully signed the tenancy or representation agreement. The digital ledger has been locked, and your lawyer has been notified of the final execution.',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 13,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),

                    // Return Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _navy,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Back to Portals',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormattedText(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final parts = text.split('**');
    
    for (int i = 0; i < parts.length; i++) {
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: isBold ? const TextStyle(fontWeight: FontWeight.bold) : null,
        ),
      );
    }
    
    return RichText(
      text: TextSpan(
        style: baseStyle,
        children: spans,
      ),
    );
  }

  Widget _buildAiReviewPanel(Map<String, dynamic> aiReview) {
    final rawRiskColor = aiReview['riskColor'] as int?;
    final riskColor = rawRiskColor != null ? Color(rawRiskColor) : const Color(0xFF22C55E);
    final riskLevel = aiReview['riskLevel'] as String? ?? 'Low';
    final riskCount = aiReview['riskCount'] as int? ?? 0;
    final keyClauses = List<String>.from(aiReview['keyClauses'] ?? []);
    final warnings = List<String>.from(aiReview['warnings'] ?? []);
    final source = aiReview['source'] as String? ?? 'Gemini 3.5 Flash';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'LexiGuard AI Review',
                        style: GoogleFonts.inter(
                          color: _grey,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: source.contains('Gemini') 
                              ? const Color(0xFFE0F2FE) 
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: source.contains('Gemini')
                                ? const Color(0xFF7DD3FC)
                                : const Color(0xFFCBD5E1),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          source.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: source.contains('Gemini')
                                ? const Color(0xFF0369A1)
                                : const Color(0xFF475569),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Agreement Summarization',
                    style: GoogleFonts.inter(
                      color: _navy,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.shield_outlined, color: riskColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '$riskLevel Risk',
                      style: GoogleFonts.inter(
                        color: riskColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 16),

          // Overview banner
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: riskCount > 0 ? const Color(0xFFFFFBEB) : const Color(0xFFECFDF5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  riskCount > 0 ? Icons.lightbulb_outline_rounded : Icons.check_circle_outline_rounded,
                  color: riskCount > 0 ? _gold : const Color(0xFF10B981),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  riskCount > 0 
                      ? 'AI found $riskCount risk indicators & suggestions for improvement.'
                      : 'AI Review: Fully standardized legal agreement with zero critical risks flagged.',
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Extracted key clauses
          Text(
            'Extracted Key Clauses',
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: keyClauses.map((clause) {
                final isLast = keyClauses.last == clause;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 10.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2.0),
                        child: Icon(Icons.check_circle, color: Color(0xFF22C55E), size: 14),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildFormattedText(
                          clause,
                          GoogleFonts.inter(
                            color: _navy,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),

          // Risks & Suggestions (if any)
          if (warnings.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Identified Risks & Recommendations',
              style: GoogleFonts.inter(
                color: _navy,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Column(
              children: warnings.map((warning) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildFormattedText(
                          warning,
                          GoogleFonts.inter(
                            color: const Color(0xFF92400E),
                            fontSize: 11,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignatureAssistantCard(Map<String, dynamic>? aiReview) {
    if (aiReview == null) return const SizedBox.shrink();

    final rawPage = aiReview['signaturePage'];
    final int signaturePage = rawPage is int 
        ? rawPage 
        : (rawPage is num ? rawPage.toInt() : int.tryParse(rawPage?.toString() ?? '') ?? 1);
        
    final String signatureAnchor = aiReview['signatureAnchor']?.toString() ?? 'Client\'s Signature';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: const Color(0xFF334155), width: 1),
      ),
      child: Stack(
        children: [
          // Subtle decorative mesh/radar lines in background
          Positioned(
            right: -20,
            bottom: -20,
            child: Icon(
              Icons.track_changes,
              size: 130,
              color: Colors.white.withOpacity(0.04),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Pulsing radar-like dot
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD4AF37),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'AI SIGNATURE LOCATOR',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFD4AF37),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Auto-Detected Signature Target Placement',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'LexiGuard multimodal intelligence analyzed this contract structure and successfully resolved the signature targets.',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF334155), height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.find_in_page_outlined, color: Color(0xFFD4AF37), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Target Page',
                                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Page $signaturePage',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 36,
                      color: const Color(0xFF334155),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.title, color: Color(0xFFD4AF37), size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Text Anchor Phrase',
                                style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 10),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '"$signatureAnchor"',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155), width: 0.5),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFF38BDF8), size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your hand-drawn signature will be dynamically bound and locked directly on Page $signaturePage next to the "$signatureAnchor" section.',
                          style: GoogleFonts.inter(color: const Color(0xFF38BDF8), fontSize: 10, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


}

// Support classes for Drawing signature
class DrawPoint {
  final Offset offset;
  final int strokeIndex;

  DrawPoint({
    required this.offset,
    required this.strokeIndex,
  });
}

class SignaturePainter extends CustomPainter {
  final List<DrawPoint> points;

  SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0B2447)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5
      ..isAntiAlias = true;

    // Group points by stroke index and draw continuous lines
    if (points.isEmpty) return;

    for (int stroke = 0; stroke <= points.last.strokeIndex; stroke++) {
      final strokePoints = points.where((p) => p.strokeIndex == stroke).toList();
      if (strokePoints.isEmpty) continue;

      for (int i = 0; i < strokePoints.length - 1; i++) {
        canvas.drawLine(
          strokePoints[i].offset,
          strokePoints[i + 1].offset,
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SignaturePainter oldDelegate) => true;
}
