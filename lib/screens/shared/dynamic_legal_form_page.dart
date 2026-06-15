import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../repositories/vault_document_repository.dart';

class DynamicLegalFormPage extends StatefulWidget {
  final Map<String, dynamic>? templateData;
  final bool embedded;
  final VaultDocumentRepository? vaultRepository;

  const DynamicLegalFormPage({
    super.key,
    this.templateData,
    this.embedded = false,
    this.vaultRepository,
  });

  @override
  State<DynamicLegalFormPage> createState() => _DynamicLegalFormPageState();
}

class _DynamicLegalFormPageState extends State<DynamicLegalFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Storing controllers mapped by field_id
  final Map<String, TextEditingController> _controllers = {};
  
  // Default fallback template if none is provided
  late final Map<String, dynamic> _template;

  final TextEditingController _clientIdController = TextEditingController();
  VaultDocumentRepository? _vaultRepositoryInstance;
  VaultDocumentRepository get _vaultRepository =>
      _vaultRepositoryInstance ??= widget.vaultRepository ?? VaultDocumentRepository();
  bool _isCompilingAndUploading = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize the template data
    _template = widget.templateData ?? _getDefaultTenancyTemplate();
    
    // Initialize text controllers for each dynamic field
    final fields = _template['dynamic_fields'] as List<dynamic>;
    for (var field in fields) {
      final fieldId = field['field_id'] as String;
      final controller = TextEditingController();
      
      // Update state when any controller value changes to refresh the live preview
      controller.addListener(() {
        setState(() {});
      });
      _controllers[fieldId] = controller;
    }
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    // Clean up all controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // Helper to neatly format dates to DD/MM/YYYY
  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  // Opens native Flutter DatePicker and updates controller value
  Future<void> _selectDate(BuildContext context, String fieldId, String label) async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 10),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0B2447),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0B2447),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF0B2447),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _controllers[fieldId]?.text = _formatDate(picked);
    }
  }

  // Replaces the dynamic tags like {{f_landlord_name}} in document_body with field values
  String _getCompiledDocumentText() {
    String body = _template['document_body'] as String;
    final fields = _template['dynamic_fields'] as List<dynamic>;
    
    for (var field in fields) {
      final fieldId = field['field_id'] as String;
      final label = field['label'] as String;
      final value = _controllers[fieldId]?.text.trim() ?? '';
      
      if (value.isNotEmpty) {
        body = body.replaceAll('{{$fieldId}}', value);
      } else {
        // Formulate a clean, readable fallback placeholder based on the field label
        final cleanLabel = label
            .replaceAll(RegExp(r'\s*\(as per.*?\)\s*'), '')
            .replaceAll(RegExp(r'\s*\(in months.*?\)\s*'), '')
            .replaceAll(RegExp(r'\s*in Ringgit.*?\s*'), '')
            .trim();
        body = body.replaceAll('{{$fieldId}}', '[$cleanLabel]');
      }
    }
    return body;
  }

  // Handle the compilation and verification trigger
  Future<void> _onCompileAndVerify() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please resolve form validation errors before compiling.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'You must be signed in to upload contracts to the vault.',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      _isCompilingAndUploading = true;
    });

    try {
      var finalCompiledText = _getCompiledDocumentText();
      
      // Ensure the text has the designated signature anchor line (with at least 10 newlines of spacing for a 75pt signature image height and seal text)
      if (!finalCompiledText.contains('Client Signature')) {
        finalCompiledText += '\n\nClient Signature:\n\n\n\n\n\n\n\n_____________________________\nDate:\n';
      }
      
      // 1. Generate PDF bytes using Syncfusion PDF generator
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      
      // Draw standard Title Header
      page.graphics.drawString(
        _template['template_name'] ?? 'Contract Agreement',
        PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold),
        bounds: const Rect.fromLTWH(0, 0, 500, 30),
      );
      
      // Draw a line separator below title
      page.graphics.drawLine(
        PdfPen(PdfColor(148, 163, 184), width: 1),
        const Offset(0, 35),
        const Offset(500, 35),
      );

      // Draw the compiled legal document body text
      final PdfTextElement textElement = PdfTextElement(
        text: finalCompiledText,
        font: PdfStandardFont(PdfFontFamily.helvetica, 11),
        brush: PdfSolidBrush(PdfColor(30, 41, 59)),
      );
      
      final PdfLayoutFormat layoutFormat = PdfLayoutFormat(
        layoutType: PdfLayoutType.paginate,
      );
      
      textElement.draw(
        page: page,
        bounds: const Rect.fromLTWH(0, 50, 500, 650),
        format: layoutFormat,
      );
      
      final List<int> pdfBytesList = document.saveSync();
      final int totalPages = document.pages.count;
      document.dispose();
      final Uint8List pdfBytes = Uint8List.fromList(pdfBytesList);

      // 2. Upload the PDF file to the Vault via VaultDocumentRepository
      final sharedClientId = _clientIdController.text.trim();
      final allowedUsers = sharedClientId.isNotEmpty ? [sharedClientId] : <String>[];
      
      final String formattedFileName = '${_template['template_name']?.replaceAll(' ', '_') ?? 'contract'}_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final isTenancy = _template['template_id'] == 'T-1001';
      final Map<String, dynamic> terms = {
        'type': isTenancy ? 'tenancy' : 'custom',
        'templateId': _template['template_id'],
        'createdAt': DateTime.now().toIso8601String(),
      };

      if (isTenancy) {
        final rentVal = double.tryParse(_controllers['f_monthly_rental']?.text ?? '') ?? 0.0;
        final secDeposit = double.tryParse(_controllers['f_security_deposit']?.text ?? '') ?? 0.0;
        final utilDeposit = double.tryParse(_controllers['f_utility_deposit']?.text ?? '') ?? 0.0;
        terms['monthlyRent'] = rentVal;
        terms['deposit'] = secDeposit + utilDeposit;
        terms['durationMonths'] = int.tryParse(_controllers['f_tenancy_duration']?.text ?? '') ?? 12;
      }

      terms['aiReview'] = {
        'riskLevel': 'Low',
        'riskColor': const Color(0xFF22C55E).value,
        'riskCount': 0,
        'keyClauses': ['Compiled from dynamic template.'],
        'warnings': [],
        'source': 'LexiGuard Form Generator',
        'signaturePage': totalPages,
        'signatureAnchor': 'Client Signature',
        'signatureOffset': 'below',
      };

      await _vaultRepository.uploadDocumentBytes(
        bytes: pdfBytes,
        fileName: formattedFileName,
        ownerUserId: currentUser.uid,
        ownerRole: 'lawyer',
        allowedUserIds: allowedUsers,
        contentType: 'application/pdf',
        isContract: true,
        contractStatus: 'pending_signature',
        contractType: isTenancy ? 'tenancy' : 'custom',
        contractTerms: terms,
      );

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Compiled PDF successfully uploaded to Vault and shared!',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF047857),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      // Clear client sharing field on success
      _clientIdController.clear();
      
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error compiling/uploading contract: $e',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCompilingAndUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fields = _template['dynamic_fields'] as List<dynamic>;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _template['template_name'] ?? 'Contract Form',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0B2447),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF0B2447)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Text(
                'Generate Contract',
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B2447),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Category: ${_template['category'] ?? 'General'}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 24),

              // Form fields section
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
                child: Form(
                  key: _formKey,
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: fields.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final field = fields[index];
                      final fieldId = field['field_id'] as String;
                      final label = field['label'] as String;
                      final type = field['type'] as String;
                      final required = field['required'] as bool? ?? false;
                      final controller = _controllers[fieldId];

                      // Define validator
                      String? validator(String? value) {
                        if (required && (value == null || value.trim().isEmpty)) {
                          return 'This field is required';
                        }
                        return null;
                      }

                      // Render field depending on its type
                      if (type == 'date') {
                        return TextFormField(
                          controller: controller,
                          readOnly: true,
                          validator: validator,
                          onTap: () => _selectDate(context, fieldId, label),
                          decoration: InputDecoration(
                            labelText: required ? '$label *' : label,
                            labelStyle: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 14,
                            ),
                            suffixIcon: const Icon(
                              Icons.calendar_today_outlined,
                              color: Color(0xFF94A3B8),
                              size: 20,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF0B2447), width: 1.5),
                            ),
                          ),
                        );
                      } else {
                        // Render string or number text inputs
                        return TextFormField(
                          controller: controller,
                          validator: validator,
                          keyboardType: type == 'number'
                              ? const TextInputType.numberWithOptions(decimal: true)
                              : TextInputType.text,
                          decoration: InputDecoration(
                            labelText: required ? '$label *' : label,
                            labelStyle: GoogleFonts.inter(
                              color: const Color(0xFF64748B),
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF8FAFC),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(color: Color(0xFF0B2447), width: 1.5),
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 28),

              // Access & Sharing section
              Text(
                'Access & Sharing',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF0B2447),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _clientIdController,
                  decoration: InputDecoration(
                    labelText: 'Share with Client ID (Optional)',
                    hintText: 'e.g. client_123',
                    labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 13),
                    prefixIcon: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF94A3B8), size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Preview Title Header
              Row(
                children: [
                  const Icon(Icons.description_outlined, color: Color(0xFF0B2447)),
                  const SizedBox(width: 8),
                  Text(
                    'Document Live Preview',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0B2447),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Live Preview Content Card (Styled like real legal paper)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  _getCompiledDocumentText(),
                  style: GoogleFonts.robotoMono(
                    fontSize: 13,
                    height: 1.6,
                    color: const Color(0xFF1E293B),
                  ),
                ),
              ),
              const SizedBox(height: 100), // Pushing contents up for floating bottom button
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0B2447),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _isCompilingAndUploading ? null : _onCompileAndVerify,
            child: _isCompilingAndUploading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Compile & Verify Contract',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  // Pre-loaded Tenancy Agreement JSON
  Map<String, dynamic> _getDefaultTenancyTemplate() {
    return {
      "template_id": "T-1001",
      "template_name": "Residential Tenancy Agreement",
      "category": "Property",
      "dynamic_fields": [
        {
          "field_id": "f_landlord_name",
          "label": "Landlord's Full Name (as per NRIC/Passport)",
          "type": "string",
          "required": true
        },
        {
          "field_id": "f_landlord_ic",
          "label": "Landlord's NRIC or Passport Number",
          "type": "string",
          "required": true
        },
        {
          "field_id": "f_tenant_name",
          "label": "Tenant's Full Name (as per NRIC/Passport)",
          "type": "string",
          "required": true
        },
        {
          "field_id": "f_tenant_ic",
          "label": "Tenant's NRIC or Passport Number",
          "type": "string",
          "required": true
        },
        {
          "field_id": "f_property_address",
          "label": "Full Address of the Demised Premises",
          "type": "string",
          "required": true
        },
        {
          "field_id": "f_monthly_rental",
          "label": "Monthly Rental Amount in Ringgit Malaysia (RM)",
          "type": "number",
          "required": true
        },
        {
          "field_id": "f_security_deposit",
          "label": "Security Deposit Amount in Ringgit Malaysia (RM)",
          "type": "number",
          "required": true
        },
        {
          "field_id": "f_utility_deposit",
          "label": "Utility Deposit Amount in Ringgit Malaysia (RM)",
          "type": "number",
          "required": true
        },
        {
          "field_id": "f_commencement_date",
          "label": "Tenancy Commencement Date (DD/MM/YYYY)",
          "type": "date",
          "required": true
        },
        {
          "field_id": "f_tenancy_duration",
          "label": "Tenancy Period (in months, e.g., 12 or 24)",
          "type": "number",
          "required": true
        }
      ],
      "document_body": "*** DISCLAIMER: This document is a prototype generated for the LexiGuard demonstration and does not constitute formal legal advice. *** \n\nTHIS RESIDENTIAL TENANCY AGREEMENT is made on {{f_commencement_date}}.\n\nBETWEEN:\n\n1. The party specified as the Landlord, {{f_landlord_name}} (NRIC No./Passport No.: {{f_landlord_ic}}) (hereinafter referred to as the 'Landlord') of the one part; and\n\n2. The party specified as the Tenant, {{f_tenant_name}} (NRIC No./Passport No.: {{f_tenant_ic}}) (hereinafter referred to as the 'Tenant') of the other part.\n\nWHEREAS:\n\nA. The Landlord is the registered and beneficial owner of the residential property located at {{f_property_address}} (hereinafter referred to as the 'Demised Premises').\nB. The Landlord has agreed to let and the Tenant has agreed to take the Demised Premises on tenancy subject to the terms and conditions hereinafter contained.\n\nNOW IT IS HEREBY AGREED AS FOLLOWS:\n\n1. AGREEMENT TO LET\nSubject to the provisions of this Agreement, the Landlord lets and the Tenant takes the Demised Premises for a duration of {{f_tenancy_duration}} months, commencing on {{f_commencement_date}}.\n\n2. RENTAL AND DEPOSITS\n2.1 The monthly rental for the Demised Premises shall be Ringgit Malaysia {{f_monthly_rental}} (RM{{f_monthly_rental}}) only, payable in advance on or before the 7th day of each calendar month without any deduction whatsoever.\n2.2 Upon signing this Agreement, the Tenant shall pay the Landlord a Security Deposit of Ringgit Malaysia {{f_security_deposit}} (RM{{f_security_deposit}}) only, and a Utility Deposit of Ringgit Malaysia {{f_utility_deposit}} (RM{{f_utility_deposit}}) only. Both deposits shall be held by the Landlord as security for the due performance of the Tenant's obligations and shall be refunded without interest within thirty (30) days from the expiration of this tenancy, subject to deductions for any outstanding payments, damages, or breaches.\n\n3. TENANT'S COVENANTS\nThe Tenant hereby covenants with the Landlord as follows:\n3.1 To pay the monthly rental punctually on the due dates.\n3.2 To pay all charges for water, electricity, internet, sewage, and other utilities consumed on the Demised Premises during the tenancy.\n3.3 To use the Demised Premises solely as a private residential dwelling for the Tenant and the Tenant's immediate family and not to sub-let, assign, or part with the physical possession of the Demised Premises or any part thereof to any third party without the prior written consent of the Landlord.\n3.4 To maintain the interior of the Demised Premises, including fixtures, fittings, and appliances, in good, clean, and tenantable repair and condition (fair wear and tear excepted).\n3.5 Not to make any structural alterations or additions to the Demised Premises without obtaining the prior written consent of the Landlord.\n3.6 To permit the Landlord or the Landlord's authorized agents, at all reasonable times and upon reasonable prior notice, to enter and inspect the condition of the Demised Premises.\n\n4. LANDLORD'S COVENANTS\nThe Landlord hereby covenants with the Tenant as follows:\n4.1 To pay all quit rent, assessment rates, maintenance fees, and sinking funds charged in respect of the Demised Premises.\n4.2 To maintain the main structure, roof, main sewerage, electrical wiring, and plumbing system of the Demised Premises in good repair and tenantable condition.\n4.3 That the Tenant, paying the rental and performing the covenants herein, shall peaceably hold and enjoy the Demised Premises during the tenancy without interruption by the Landlord.\n\n5. MUTUAL COVENANTS & GENERAL CLAUSES\n5.1 SEVERABILITY: If any provision of this Agreement is held to be invalid or unenforceable, such provision shall be fully severable, and the remaining provisions shall remain in full force and effect.\n5.2 GOVERNING LAW: This Agreement shall be governed by, construed, and enforced in accordance with the laws of Malaysia. The parties submit to the exclusive jurisdiction of the Courts of Malaysia in relation to any disputes arising under this Agreement.\n5.3 ENTIRE AGREEMENT: This Agreement constitutes the entire agreement between the parties and supersedes all prior agreements, oral or written, concerning the tenancy of the Demised Premises.\n\nIN WITNESS WHEREOF the parties have set their hands the day and year first above written.\n\n\nSigned by the Landlord:\n\n\n\n\n\n\n\n_____________________________\nName: {{f_landlord_name}}\nDate:\n\nClient Signature:\n\n\n\n\n\n\n\n\n\n\n_____________________________\nName: {{f_tenant_name}}\nDate:"
    };
  }
}
