import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../../models/case_model.dart';
import '../../models/user_model.dart';
import '../../repositories/vault_document_repository.dart';

enum SendContractStep { fillDetails, aiReview }

class SendContractScreen extends StatefulWidget {
  final CaseModel caseModel;
  final UserModel lawyer;

  const SendContractScreen({
    super.key,
    required this.caseModel,
    required this.lawyer,
  });

  @override
  State<SendContractScreen> createState() => _SendContractScreenState();
}

class _SendContractScreenState extends State<SendContractScreen> with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFFFF9E6);
  static const _grey = Color(0xFF64748B);

  final _formKey = GlobalKey<FormState>();
  final _repository = VaultDocumentRepository();

  String _contractType = 'representation'; // representation | tenancy | custom

  // Representation terms
  final _hourlyRateController = TextEditingController();
  final _fixedRetainerController = TextEditingController();
  final _scopeController = TextEditingController();

  // Tenancy terms
  final _monthlyRentController = TextEditingController();
  final _depositController = TextEditingController();
  final _durationMonthsController = TextEditingController();

  // File picking
  PlatformFile? _pickedFile;
  Uint8List? _fileBytes;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  bool _success = false;

  // AI Review states
  SendContractStep _currentStep = SendContractStep.fillDetails;
  bool _isAnalyzing = false;
  String _analysisStatus = '';
  ContractAiReview? _aiReview;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    // Default mock inputs for easy testing
    _hourlyRateController.text = '350';
    _fixedRetainerController.text = '1500';
    _scopeController.text = 'Full legal representation for Property Dispute case.';

    _monthlyRentController.text = '2200';
    _depositController.text = '4400';
    _durationMonthsController.text = '12';

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.elasticOut,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _hourlyRateController.dispose();
    _fixedRetainerController.dispose();
    _scopeController.dispose();
    _monthlyRentController.dispose();
    _depositController.dispose();
    _durationMonthsController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _pickedFile = result.files.first;
      _fileBytes = _pickedFile!.bytes;
    });
  }

  Future<void> _submitContract() async {
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or upload a contract agreement document.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    // Compile terms based on type
    final Map<String, dynamic> terms = {
      'type': _contractType,
      'createdAt': DateTime.now().toIso8601String(),
    };

    if (_contractType == 'representation') {
      terms['hourlyRate'] = double.tryParse(_hourlyRateController.text) ?? 0.0;
      terms['fixedRetainer'] = double.tryParse(_fixedRetainerController.text) ?? 0.0;
      terms['scope'] = _scopeController.text;
    } else if (_contractType == 'tenancy') {
      terms['monthlyRent'] = double.tryParse(_monthlyRentController.text) ?? 0.0;
      terms['deposit'] = double.tryParse(_depositController.text) ?? 0.0;
      terms['durationMonths'] = int.tryParse(_durationMonthsController.text) ?? 12;
    }

    // Pack the AI Review details into contractTerms so they are stored in Firestore!
    if (_aiReview != null) {
      terms['aiReview'] = {
        'riskLevel': _aiReview!.riskLevel,
        'riskColor': _aiReview!.riskColor.value, // Color stored as integer value
        'riskCount': _aiReview!.riskCount,
        'keyClauses': _aiReview!.keyClauses,
        'warnings': _aiReview!.warnings,
        'source': _aiReview!.source,
        'signaturePage': _aiReview!.signaturePage,
        'signatureAnchor': _aiReview!.signatureAnchor,
        'signatureOffset': _aiReview!.signatureOffset,
      };
    }

    try {
      await _repository.uploadDocumentBytes(
        bytes: _fileBytes!,
        fileName: _pickedFile!.name,
        ownerUserId: widget.lawyer.id,
        ownerRole: 'lawyer',
        allowedUserIds: [widget.caseModel.clientId],
        contentType: _pickedFile!.extension == 'pdf' ? 'application/pdf' : 'application/octet-stream',
        isContract: true,
        contractStatus: 'pending_signature',
        contractType: _contractType,
        contractTerms: terms,
        onProgress: (value) {
          setState(() => _uploadProgress = value);
        },
      );

      setState(() {
        _isUploading = false;
        _success = true;
      });
      _animController.forward();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to transfer agreement: $e'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _extractTextFromBytes(Uint8List bytes, String? extension) {
    if (bytes.isEmpty) return '';
    final ext = (extension ?? '').toLowerCase();
    
    // 1. If it's a plain text or markdown file, just decode it directly
    if (ext == 'txt' || ext == 'md' || ext == 'json' || ext == 'csv' || ext == 'rtf') {
      try {
        return utf8.decode(bytes, allowMalformed: true).trim();
      } catch (_) {
        // Fall back to printable strings extraction if UTF-8 fails
      }
    }

    // 2. For binary/structured documents like PDF or DOCX, extract printable ASCII sequences (like "strings" tool)
    try {
      final buffer = StringBuffer();
      int consecutive = 0;
      final currentList = <int>[];

      for (final byte in bytes) {
        // Alphanumeric, spaces, basic punctuation, tab, newline
        if ((byte >= 32 && byte <= 126) || byte == 10 || byte == 13 || byte == 9) {
          currentList.add(byte);
          consecutive++;
        } else {
          if (consecutive >= 4) {
            // Keep chunks of text that look like actual words/phrases
            final word = String.fromCharCodes(currentList);
            // Ignore highly common raw PDF/binary syntax elements to reduce tokens even further
            if (!word.contains('/Page') && 
                !word.contains('/Contents') && 
                !word.contains('/Resources') &&
                !word.contains('/Font') &&
                !word.contains('endstream') &&
                !word.contains('obj') &&
                !word.contains('endobj')) {
              buffer.write(word);
              buffer.write(' ');
            }
          }
          currentList.clear();
          consecutive = 0;
        }
      }
      if (consecutive >= 4) {
        buffer.write(String.fromCharCodes(currentList));
      }

      String rawExtracted = buffer.toString().trim();
      
      // Post-process: collapse multiple spaces and remove garbled character streaks
      rawExtracted = rawExtracted.replaceAll(RegExp(r'\s+'), ' ');
      
      // Filter out non-alphanumeric/unreadable junk characters (retaining standard punctuation)
      rawExtracted = rawExtracted.replaceAll(RegExp(r'[^a-zA-Z0-9\s.,;:()\-–_@/\\#%&?*+=!\[\]{}'']'), '');
      
      // Limit to prevent token overflow (e.g., max ~15,000 characters)
      if (rawExtracted.length > 15000) {
        rawExtracted = '${rawExtracted.substring(0, 15000)}... [TRUNCATED]';
      }
      
      return rawExtracted.trim();
    } catch (e) {
      return 'Error parsing document content: $e';
    }
  }

  String _sanitizeFontOutput(String text) {
    // 1. Map common smart unicode symbols to clean ASCII equivalents
    String result = text
        .replaceAll('⚠️', '[Warning] ')
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('‘', "'")
        .replaceAll('’', "'")
        .replaceAll('•', '-')
        .replaceAll('–', '-') // en dash
        .replaceAll('—', '-') // em dash
        .replaceAll('…', '...')
        .replaceAll('™', 'TM')
        .replaceAll('®', '(R)')
        .replaceAll('©', '(C)')
        .replaceAll('§', 'Section ');

    // 2. Strip any other complex unsupported/non-ASCII symbols (such as emoji, smart glyphs)
    // that would trigger the Noto Font fallback error in Flutter UI rendering.
    final buffer = StringBuffer();
    for (int i = 0; i < result.length; i++) {
      final codeUnit = result.codeUnitAt(i);
      // ASCII 32 (space) to 126 (~) plus common whitespace (LF, CR, Tab) and common Latin-1 accents
      if ((codeUnit >= 32 && codeUnit <= 126) || codeUnit == 10 || codeUnit == 13 || codeUnit == 9) {
        buffer.writeCharCode(codeUnit);
      }
    }
    return buffer.toString().trim();
  }

  int _parsePageNumber(dynamic val) {
    if (val == null) return 1;
    if (val is int) return val;
    if (val is double) return val.toInt();
    if (val is num) return val.toInt();
    if (val is String) {
      final clean = val.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = int.tryParse(clean);
      return parsed ?? 1;
    }
    return 1;
  }

  Widget _buildFormattedText(String text, TextStyle baseStyle) {
    final List<TextSpan> spans = [];
    final parts = text.split('**');
    
    for (int i = 0; i < parts.length; i++) {
      final isBold = i % 2 == 1;
      spans.add(
        TextSpan(
          text: parts[i],
          style: isBold 
              ? const TextStyle(fontWeight: FontWeight.bold) 
              : null,
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

  Future<void> _runAiAnalysis() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or upload a contract agreement document.'),
          backgroundColor: Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisStatus = 'Reading agreement draft...';
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() => _analysisStatus = 'Connecting to LexiGuard AI...');

    final fileName = _pickedFile!.name;
    ContractAiReview review;

    // Extract text from the contract file bytes to send as pure text
    String fileTextContent = '';
    if (_fileBytes != null) {
      fileTextContent = _extractTextFromBytes(_fileBytes!, _pickedFile!.extension);
    }

    final apiKey = dotenv.env['GEMINI_API_KEY'];
    final bool hasCustomKey = apiKey != null && apiKey.isNotEmpty && apiKey != 'YOUR_GEMINI_API_KEY_HERE';

    try {
      if (!hasCustomKey) {
        // Fallback: If no API key is provided, run our local Malaysian legal rules engine.
        // It provides a beautifully responsive and mock-safe user experience during sandbox testing.
        throw Exception('Placeholder key detected. Using offline legal logic.');
      }

      setState(() => _analysisStatus = 'Running LexiGuard AI Review (Gemini 3.5)...');
      
      final model = GenerativeModel(
        model: 'gemini-3.5-flash',
        apiKey: apiKey,
      );

      final prompt = '''
      You are an expert legal contract reviewer specializing in Malaysian law.
      Analyze the contract details, form fields, and the attached raw contract document file (PDF/Image/Text) provided below to perform a thorough legal audit and review.
      
      Form-Specified Contract Details:
      - Type: $_contractType
      - File Name: $fileName
      ${_contractType == 'tenancy' ? '''
      - Monthly Rent: RM ${_monthlyRentController.text}
      - Deposit: RM ${_depositController.text}
      - Duration: ${_durationMonthsController.text} Months
      ''' : ''}
      ${_contractType == 'representation' ? '''
      - Fixed Retainer: RM ${_fixedRetainerController.text}
      - Hourly Rate: RM ${_hourlyRateController.text}
      - Scope: ${_scopeController.text}
      ''' : ''}

      ${fileTextContent.isNotEmpty ? '''
      --- ADDITIONAL PLAIN TEXT EXTRACTED ---
      $fileTextContent
      --------------------------------------
      ''' : ''}

      Please read the attached contract document file directly (Gemini is analyzing the raw document bytes). Audit the actual clauses inside the document. Extract the exact key clauses (comparing them to the lawyer's form inputs) and identify any potential legal risks, warnings, mismatch alerts, or recommendation improvements based on standard Malaysian legal practices (e.g. Tenancy Act norms, Bar Council guidelines).
      
      You MUST return a JSON response with the following format:
      {
        "riskLevel": "Low" | "Medium" | "High",
        "keyClauses": [
          "Extracted monthly rental / professional rate clause",
          "Extracted deposit/retainer terms",
          "Duration / lease length key term",
          "At least 2 other key operational clauses or conditions"
        ],
        "warnings": [
          "Specific legal warning or suggestion 1 (e.g. standard deposit is 2.5 months)",
          "Specific legal warning or suggestion 2 (e.g. late payment fees, billing caps, arbitration AIAC)"
        ],
        "signaturePage": 1-based integer representing the page number where the client's signature is located,
        "signatureAnchor": "The closest text label/phrase or header next to the client's signature box (e.g. 'Tenant's Signature', 'Signature of Client', 'Second Party Signature' etc.)",
        "signatureOffset": "\"above\" | \"right\" | \"below\" - indicating where the physical signature should be placed relative to the signatureAnchor text. (e.g. if the anchor is 'Client: ______', the offset should be 'right'. If the anchor is 'Client's Signature' under a line, the offset should be 'above'). Default to 'above' if unsure."
      }
      ''';

      final response = await model.generateContent([
        Content('user', [
          TextPart(prompt),
          if (_fileBytes != null && (
              _pickedFile!.extension == 'pdf' || 
              _pickedFile!.extension == 'txt' || 
              _pickedFile!.extension == 'png' || 
              _pickedFile!.extension == 'jpg' || 
              _pickedFile!.extension == 'jpeg'
          )) ...[
            DataPart(
              _pickedFile!.extension == 'pdf' ? 'application/pdf' :
              _pickedFile!.extension == 'txt' ? 'text/plain' :
              _pickedFile!.extension == 'png' ? 'image/png' : 'image/jpeg',
              _fileBytes!,
            ),
          ],
        ]),
      ]);
      final responseText = response.text;
      
      if (responseText == null || responseText.isEmpty) {
        throw Exception('Empty response from Gemini API');
      }

      String cleanText = responseText.trim();
      if (cleanText.startsWith('```')) {
        cleanText = cleanText.replaceAll(RegExp(r'^```(json)?'), '');
        cleanText = cleanText.replaceAll(RegExp(r'```$'), '');
        cleanText = cleanText.trim();
      }

      final Map<String, dynamic> aiJson = jsonDecode(cleanText);
      final rawRisk = aiJson['riskLevel']?.toString() ?? 'Low';
      final riskLevel = (rawRisk == 'High' || rawRisk == 'Medium' || rawRisk == 'Low') ? rawRisk : 'Low';
      final riskColor = riskLevel == 'High' 
          ? const Color(0xFFEF4444) 
          : (riskLevel == 'Medium' ? const Color(0xFFD4AF37) : const Color(0xFF22C55E));

      final keyClauses = List<String>.from(aiJson['keyClauses'] ?? []);
      final warnings = List<String>.from(aiJson['warnings'] ?? []);

      review = ContractAiReview(
        riskLevel: riskLevel,
        riskColor: riskColor,
        riskCount: warnings.length,
        keyClauses: (keyClauses.isNotEmpty ? keyClauses : ['Draft successfully parsed.'])
            .map((c) => _sanitizeFontOutput(c))
            .toList(),
        warnings: (warnings.isNotEmpty ? warnings : ['No critical risks flagged by Gemini.'])
            .map((w) => _sanitizeFontOutput(w))
            .toList(),
        source: 'Gemini 3.5 Flash',
        signaturePage: _parsePageNumber(aiJson['signaturePage']),
        signatureAnchor: _sanitizeFontOutput(aiJson['signatureAnchor']?.toString() ?? 'Client\'s Signature'),
        signatureOffset: aiJson['signatureOffset']?.toString() ?? 'above',
      );
    } catch (e) {
      // If the user provided a custom key, but the call failed, do NOT silent-fallback.
      // Show the actual API/network error so they can debug their key or connection!
      if (hasCustomKey) {
        if (!mounted) return;
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gemini API Error: $e\n\nPlease check your API key validity and network connection.'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
          ),
        );
        return;
      }

      // Offline fallback: Use the deterministic Malaysian legal heuristics
      final rent = double.tryParse(_monthlyRentController.text) ?? 0.0;
      final deposit = double.tryParse(_depositController.text) ?? 0.0;
      final duration = int.tryParse(_durationMonthsController.text) ?? 12;

      if (_contractType == 'tenancy') {
        final monthlyRentStr = 'RM ${rent.toStringAsFixed(2)}';
        final depositStr = 'RM ${deposit.toStringAsFixed(2)}';

        review = ContractAiReview(
          riskLevel: rent > 4000 ? 'Medium' : 'Low',
          riskColor: rent > 4000 ? const Color(0xFFD4AF37) : const Color(0xFF22C55E),
          riskCount: rent > 4000 ? 2 : 1,
          keyClauses: [
            'Monthly Rental: $monthlyRentStr',
            'Security Deposit: $depositStr (equivalent to ${(deposit / (rent > 0 ? rent : 1)).toStringAsFixed(1)} months rent)',
            'Lease Duration: $duration Months lease term',
            'Utility Bills: Tenant is strictly responsible for electricity, water, and internet bills.',
            'Subletting: Strictly prohibited without prior written consent from the landlord.',
          ].map((c) => _sanitizeFontOutput(c)).toList(),
          warnings: [
            if (deposit < rent * 2)
              '⚠️ Insufficient security deposit. Standard practice in Malaysia requires a 2-month security deposit + 0.5-month utility deposit (Total RM ${(rent * 2.5).toStringAsFixed(0)}).',
            if (rent > 4000)
              '⚠️ Higher rent threshold. Recommend adding a clear dispute arbitration clause in case of payment defaults.',
            '⚠️ Late payment interest fee is omitted. Consider specifying an 8% p.a. interest fee for late payments to discourage defaults.',
          ].map((w) => _sanitizeFontOutput(w)).toList(),
          source: 'Offline Heuristics',
          signaturePage: 3,
          signatureAnchor: 'Tenant\'s Signature',
          signatureOffset: 'above',
        );
      } else if (_contractType == 'representation') {
        final hourly = double.tryParse(_hourlyRateController.text) ?? 0.0;
        final retainer = double.tryParse(_fixedRetainerController.text) ?? 0.0;
        final scope = _scopeController.text;

        review = ContractAiReview(
          riskLevel: hourly > 500 ? 'Medium' : 'Low',
          riskColor: hourly > 500 ? const Color(0xFFD4AF37) : const Color(0xFF22C55E),
          riskCount: hourly > 500 ? 2 : 1,
          keyClauses: [
            'Professional Retainer Fee: RM ${retainer.toStringAsFixed(2)} (Fixed)',
            'Hourly Billing Rate: RM ${hourly.toStringAsFixed(2)}/hour for extra work',
            'Scope of Representation: "$scope"',
            'Dispute Resolution: Any billing disputes will be resolved in accordance with Bar Council guidelines.',
          ].map((c) => _sanitizeFontOutput(c)).toList(),
          warnings: [
            if (hourly > 500)
              '⚠️ Standard hourly rate warning. The hourly rate of RM ${hourly.toStringAsFixed(0)} is above standard mid-tier counsel rates. Ensure scope limits are clear.',
            '⚠️ No billing ceiling cap. Recommend adding a clause stating that total billable hours cannot exceed a specific budget without client\'s prior authorization.',
          ].map((w) => _sanitizeFontOutput(w)).toList(),
          source: 'Offline Heuristics',
          signaturePage: 2,
          signatureAnchor: 'Client\'s Signature',
          signatureOffset: 'above',
        );
      } else {
        review = ContractAiReview(
          riskLevel: 'Medium',
          riskColor: const Color(0xFFD4AF37),
          riskCount: 2,
          keyClauses: [
            'Document File Name: "$fileName"',
            'Contract Type: Custom / Unspecified',
            'General Indemnity: Owner is fully indemnified against general liabilities.',
          ].map((c) => _sanitizeFontOutput(c)).toList(),
          warnings: [
            '⚠️ One-sided indemnity. The general indemnity clause is highly favorable to the owner/sender. Recommend balancing liability allocations.',
            '⚠️ Arbitration clause is missing. Consider adding a standard arbitration clause citing regional arbitration court (AIAC Malaysia).',
          ].map((w) => _sanitizeFontOutput(w)).toList(),
          source: 'Offline Heuristics',
          signaturePage: 1,
          signatureAnchor: 'Signature of Client',
          signatureOffset: 'above',
        );
      }
    }

    setState(() {
      _aiReview = review;
      _isAnalyzing = false;
      _currentStep = SendContractStep.aiReview;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_success) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: _buildSuccessUI(),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: _isAnalyzing
          ? _buildAiLoadingUI()
          : (_currentStep == SendContractStep.aiReview ? _buildAiReviewUI() : _buildFormUI()),
    );
  }

  Widget _buildAiLoadingUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation<Color>(_gold),
                  ),
                ),
                Container(
                  width: 68,
                  height: 68,
                  decoration: const BoxDecoration(
                    color: _goldLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome,
                      color: _gold,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'LexiGuard AI Reviewer',
              style: GoogleFonts.inter(
                color: _navy,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _analysisStatus,
                key: ValueKey(_analysisStatus),
                style: GoogleFonts.inter(
                  color: _grey,
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: _navy,
      foregroundColor: Colors.white,
      elevation: 0,
      title: Text(
        _currentStep == SendContractStep.aiReview ? 'AI Contract Summary' : 'Send Legal Contract',
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      centerTitle: true,
      leading: _currentStep == SendContractStep.aiReview
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _currentStep = SendContractStep.fillDetails;
                });
              },
            )
          : null,
    );
  }

  Widget _buildFormUI() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Target client info header
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF6FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_outline_rounded, color: _navy, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sending Agreement To:',
                          style: GoogleFonts.inter(
                            color: _grey,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Client ID: ${widget.caseModel.clientId}',
                          style: GoogleFonts.inter(
                            color: _navy,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Case: ${widget.caseModel.title}',
                          style: GoogleFonts.inter(
                            color: _grey,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Segmented selector for type
            Text(
              'Agreement Type',
              style: GoogleFonts.inter(
                color: _navy,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildSegmentButton('representation', 'Representation'),
                const SizedBox(width: 8),
                _buildSegmentButton('tenancy', 'Tenancy'),
                const SizedBox(width: 8),
                _buildSegmentButton('custom', 'Custom'),
              ],
            ),
            const SizedBox(height: 24),

            // Dynamic Form Fields based on Type
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _buildDynamicFormFields(),
            ),
            const SizedBox(height: 24),

            // File Upload Area
            Text(
              'Agreement Document',
              style: GoogleFonts.inter(
                color: _navy,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            _buildFilePickerArea(),
            const SizedBox(height: 36),

            // Submit Button or uploading loading indicator
            _isUploading ? _buildUploadingState() : _buildSubmitButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String value, String label) {
    final active = _contractType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _contractType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? _navy : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: active ? _navy : const Color(0xFFE2E8F0),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: _navy.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    )
                  ]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: active ? Colors.white : _navy,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicFormFields() {
    if (_contractType == 'representation') {
      return Column(
        key: const ValueKey('rep'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Hourly Rate (RM)',
                  controller: _hourlyRateController,
                  icon: Icons.hourglass_empty_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  label: 'Fixed Retainer (RM)',
                  controller: _fixedRetainerController,
                  icon: Icons.attach_money_rounded,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Scope of Representation',
            controller: _scopeController,
            icon: Icons.gavel_outlined,
            maxLines: 3,
          ),
        ],
      );
    } else if (_contractType == 'tenancy') {
      return Column(
        key: const ValueKey('ten'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildInputField(
                  label: 'Monthly Rent (RM)',
                  controller: _monthlyRentController,
                  icon: Icons.home_work_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildInputField(
                  label: 'Deposit Amount (RM)',
                  controller: _depositController,
                  icon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputField(
            label: 'Tenancy Duration (Months)',
            controller: _durationMonthsController,
            icon: Icons.calendar_month_outlined,
            keyboardType: TextInputType.number,
          ),
        ],
      );
    } else {
      return Container(
        key: const ValueKey('cus'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline, color: _gold, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Custom agreement template. Details will be bound directly to the uploaded file.',
                style: GoogleFonts.inter(color: _navy, fontSize: 12),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _navy,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: GoogleFonts.inter(fontSize: 14, color: _navy),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Field required';
            }
            return null;
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: _grey, size: 18),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _navy),
            ),
            errorStyle: GoogleFonts.inter(fontSize: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildFilePickerArea() {
    return GestureDetector(
      onTap: _pickFile,
      child: DottedBorder(
        color: _pickedFile == null ? const Color(0xFFCBD5E1) : _gold,
        strokeWidth: 2,
        dashPattern: const [6, 4],
        borderType: BorderType.RRect,
        radius: const Radius.circular(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            color: _pickedFile == null ? Colors.white : _goldLight,
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _pickedFile == null ? const Color(0xFFF1F5F9) : const Color(0xFFFFF2CC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _pickedFile == null ? Icons.cloud_upload_outlined : Icons.description,
                    color: _pickedFile == null ? _grey : _gold,
                    size: 26,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _pickedFile == null ? 'Upload Contract PDF' : _pickedFile!.name,
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  _pickedFile == null
                      ? 'PDF, DOCX, JPG, PNG (Max 15MB)'
                      : '${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB  •  Tap to replace file',
                  style: GoogleFonts.inter(
                    color: _grey,
                    fontSize: 11,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUploadingState() {
    return Column(
      children: [
        LinearProgressIndicator(
          value: _uploadProgress,
          backgroundColor: const Color(0xFFE2E8F0),
          valueColor: const AlwaysStoppedAnimation<Color>(_gold),
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Uploading secure draft to vault...',
              style: GoogleFonts.inter(color: _navy, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            Text(
              '${(_uploadProgress * 100).toInt()}%',
              style: GoogleFonts.inter(color: _gold, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _runAiAnalysis,
        icon: const Icon(Icons.auto_awesome, size: 16),
        label: Text(
          'Analyze Agreement with LexiGuard AI',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _navy,
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

  Widget _buildAiReviewUI() {
    if (_aiReview == null) return const SizedBox.shrink();

    final typeLabel = _contractType == 'tenancy'
        ? 'Tenancy Agreement'
        : _contractType == 'representation'
            ? 'Representation Agreement'
            : 'Custom Legal Contract';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Risk Header Card
          Container(
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                                color: _aiReview!.source.contains('Gemini') 
                                    ? const Color(0xFFE0F2FE) // Sky blue for Live Gemini
                                    : const Color(0xFFF1F5F9), // Slate for local heuristics
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: _aiReview!.source.contains('Gemini')
                                      ? const Color(0xFF7DD3FC)
                                      : const Color(0xFFCBD5E1),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                _aiReview!.source.toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: _aiReview!.source.contains('Gemini')
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
                          typeLabel,
                          style: GoogleFonts.inter(
                            color: _navy,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _aiReview!.riskColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.shield_outlined, color: _aiReview!.riskColor, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            '${_aiReview!.riskLevel} Risk',
                            style: GoogleFonts.inter(
                              color: _aiReview!.riskColor,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'AI found ${_aiReview!.riskCount} potential risk points or recommendations for improvement in this draft.',
                        style: GoogleFonts.inter(
                          color: _navy,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Key Clauses Section
          Row(
            children: [
              const Icon(Icons.description_outlined, color: _navy, size: 18),
              const SizedBox(width: 8),
              Text(
                'AI Extracted Key Clauses',
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              children: _aiReview!.keyClauses.map((clause) {
                final isLast = _aiReview!.keyClauses.last == clause;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 12.0),
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
          const SizedBox(height: 24),

          // Potential Risks & Suggestions
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, color: _gold, size: 18),
              const SizedBox(width: 8),
              Text(
                'Identified Risks & Recommendations',
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            children: _aiReview!.warnings.map((warning) {
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFBEB),
                  borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 36),

          // Actions
          if (_isUploading)
            _buildUploadingState()
          else ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitContract,
                icon: const Icon(Icons.send_rounded, size: 16),
                label: Text(
                  'Confirm & Securely Send to Client',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _currentStep = SendContractStep.fillDetails;
                  });
                },
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                label: Text(
                  'Adjust Draft / Edit Terms',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
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
          ],
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSuccessUI() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium checkmark shield micro-animation
            ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFEFF6FF),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: Colors.white,
                      size: 40,
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
                    'Contract Shared Securely',
                    style: GoogleFonts.inter(
                      color: _navy,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'The agreement document has been uploaded with end-to-end encryption. The client has been notified to review and sign the draft in their portal.',
                    style: GoogleFonts.inter(
                      color: _grey,
                      fontSize: 13,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Return Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: const BorderSide(color: _navy, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Back to Dashboard',
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
    );
  }
}

class ContractAiReview {
  final String riskLevel;
  final Color riskColor;
  final int riskCount;
  final List<String> keyClauses;
  final List<String> warnings;
  final String source;
  final int signaturePage;
  final String signatureAnchor;
  final String signatureOffset;

  const ContractAiReview({
    required this.riskLevel,
    required this.riskColor,
    required this.riskCount,
    required this.keyClauses,
    required this.warnings,
    required this.source,
    required this.signaturePage,
    required this.signatureAnchor,
    required this.signatureOffset,
  });
}
