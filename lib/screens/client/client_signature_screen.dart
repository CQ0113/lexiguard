import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../models/user_model.dart';
import '../../models/vault_document_model.dart';
import '../../repositories/vault_document_repository.dart';
import '../../core/firebase/firebase_initializer.dart';
import '../shared/contract_review_screen.dart';

class ClientSignatureScreen extends StatefulWidget {
  final UserModel clientUser;

  const ClientSignatureScreen({
    super.key,
    required this.clientUser,
  });

  @override
  State<ClientSignatureScreen> createState() => _ClientSignatureScreenState();
}

class _ClientSignatureScreenState extends State<ClientSignatureScreen> with SingleTickerProviderStateMixin {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);
  static const _goldLight = Color(0xFFFFF9E6);
  static const _grey = Color(0xFF64748B);

  final VaultDocumentRepository _repository = VaultDocumentRepository();
  late TabController _tabController;
  bool _forceDemo = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<VaultDocumentModel>> _getContractsStream() {
    return _repository.streamContractsForUser(userId: widget.clientUser.id);
  }

  // Fallback demo/mock contracts when Firebase is not ready
  List<VaultDocumentModel> _getMockContracts() {
    return [
      VaultDocumentModel(
        id: 'mock_contract_1',
        fileName: 'Tenancy_Agreement_Ahmad_Razif.pdf',
        downloadUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ownerUserId: 'lawyer_1',
        ownerRole: 'lawyer',
        storagePath: 'vault/lawyer_1/tenancy_agreement.pdf',
        allowedUserIds: [widget.clientUser.id],
        isContract: true,
        contractStatus: 'pending_signature',
        contractType: 'tenancy',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        sizeBytes: 124500,
        contentType: 'application/pdf',
        contractTerms: {
          'type': 'tenancy',
          'monthlyRent': 2200.0,
          'deposit': 4400.0,
          'durationMonths': 12,
          'aiReview': {
            'riskLevel': 'Low',
            'riskColor': const Color(0xFF22C55E).value,
            'riskCount': 1,
            'keyClauses': [
              'Monthly Rental: RM 2,200.00',
              'Security Deposit: RM 4,400.00 (equivalent to 2.0 months rent)',
              'Lease Duration: 12 Months lease term',
              'Utility Bills: Tenant is strictly responsible for electricity, water, and internet bills.',
            ],
            'warnings': [
              '[Warning] Late payment interest fee is omitted. Consider specifying an 8% p.a. interest fee for late payments to discourage defaults.',
            ],
            'source': 'Gemini 3.5 Flash',
            'signaturePage': 3,
            'signatureAnchor': "Tenant's Signature",
          },
        },
      ),
      VaultDocumentModel(
        id: 'mock_contract_2',
        fileName: 'Representation_Retainer_Agreement.pdf',
        downloadUrl: 'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        ownerUserId: 'lawyer_1',
        ownerRole: 'lawyer',
        storagePath: 'vault/lawyer_1/retainer.pdf',
        allowedUserIds: [widget.clientUser.id],
        isContract: true,
        contractStatus: 'signed',
        contractType: 'representation',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
        signedAt: DateTime.now().subtract(const Duration(days: 14)),
        sizeBytes: 98000,
        contentType: 'application/pdf',
        contractTerms: {
          'type': 'representation',
          'hourlyRate': 350.0,
          'fixedRetainer': 1500.0,
          'scope': 'Full legal representation for Property Dispute case in Shah Alam.',
          'aiReview': {
            'riskLevel': 'Low',
            'riskColor': const Color(0xFF22C55E).value,
            'riskCount': 1,
            'keyClauses': [
              'Professional Retainer Fee: RM 1,500.00 (Fixed)',
              'Hourly Billing Rate: RM 350.00/hour for extra work',
              'Scope of Representation: "Full legal representation for Property Dispute case in Shah Alam."',
            ],
            'warnings': [
              '[Warning] No billing ceiling cap. Recommend adding a clause stating that total billable hours cannot exceed a specific budget.',
            ],
            'source': 'Gemini 3.5 Flash',
            'signaturePage': 2,
            'signatureAnchor': "Client's Signature",
          },
        },
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasAuth = FirebaseInitializer.isReady && FirebaseAuth.instance.currentUser != null;
    if (!hasAuth || _forceDemo) {
      // In Demo mode, show mock items for verification
      final mockDocs = _getMockContracts();
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: _buildContent(mockDocs, isDemo: true),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: StreamBuilder<List<VaultDocumentModel>>(
        stream: _getContractsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(28.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFEF4444),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load from database',
                      style: GoogleFonts.inter(
                        color: _navy,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      style: GoogleFonts.inter(
                        color: _grey,
                        fontSize: 12,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          setState(() {
                            _forceDemo = true;
                          });
                        },
                        icon: const Icon(Icons.bolt, size: 16),
                        label: Text(
                          'Switch to Demo Sandbox Mode',
                          style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: _navy,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final allContracts = snapshot.data ?? const [];
          return _buildContent(allContracts);
        },
      ),
    );
  }

  Widget _buildContent(List<VaultDocumentModel> allContracts, {bool isDemo = false}) {
    final pending = allContracts.where((c) => c.contractStatus != 'signed').toList();
    final signed = allContracts.where((c) => c.contractStatus == 'signed').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Signing Portal',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      color: _navy,
                    ),
                  ),
                  if (isDemo) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _gold.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'DEMO MODE',
                        style: GoogleFonts.inter(color: _gold, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Review and digitally sign official agreements from your lawyer',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: _grey,
                ),
              ),
            ],
          ),
        ),

        // Custom Premium Tab Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelColor: _navy,
              unselectedLabelColor: _grey,
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w500, fontSize: 13),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              padding: const EdgeInsets.all(4),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.pending_actions, size: 16),
                      const SizedBox(width: 6),
                      Text('Pending (${pending.length})'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.assignment_turned_in_outlined, size: 16),
                      const SizedBox(width: 6),
                      Text('Signed (${signed.length})'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildContractList(pending, isPending: true, isDemo: isDemo),
              _buildContractList(signed, isPending: false, isDemo: isDemo),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildContractList(List<VaultDocumentModel> list, {required bool isPending, bool isDemo = false}) {
    if (list.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPending ? Icons.edit_document : Icons.assignment_turned_in_rounded,
                  color: const Color(0xFF94A3B8),
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isPending ? 'No agreements pending signature' : 'No signed agreements found',
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                isPending
                    ? 'When your lawyer sends an official contract or tenancy agreement, it will appear here for review and digital signature.'
                    : 'Once you sign an agreement, the fully formalized copy will be logged here for your permanent records.',
                style: GoogleFonts.inter(color: _grey, fontSize: 12, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: list.length,
      itemBuilder: (context, idx) {
        final doc = list[idx];
        return _buildContractCard(doc, isPending: isPending, isDemo: isDemo);
      },
    );
  }

  Widget _buildContractCard(VaultDocumentModel doc, {required bool isPending, bool isDemo = false}) {
    final typeLabel = doc.contractType == 'tenancy'
        ? 'Tenancy Agreement'
        : doc.contractType == 'representation'
            ? 'Representation Agreement'
            : 'Legal Contract';

    final createdDateStr = doc.createdAt != null
        ? DateFormat('dd MMM yyyy, h:mm a').format(doc.createdAt!)
        : 'Recently';

    final signedDateStr = doc.signedAt != null
        ? DateFormat('dd MMM yyyy, h:mm a').format(doc.signedAt!)
        : '';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header color strip
          Container(
            height: 6,
            decoration: BoxDecoration(
              color: isPending ? _gold : const Color(0xFF22C55E),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending ? _goldLight : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPending ? 'AWAITING SIGNATURE' : 'SIGNED & ACTIVE',
                        style: GoogleFonts.inter(
                          color: isPending ? _gold : const Color(0xFF15803D),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.attach_file, color: _grey, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          doc.contentType == 'application/pdf' ? 'PDF' : 'Draft',
                          style: GoogleFonts.inter(color: _grey, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  typeLabel,
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  doc.fileName,
                  style: GoogleFonts.inter(
                    color: _grey,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),

                // Terms details brief
                if (doc.contractTerms != null) ...[
                  _buildTermsRow(doc.contractTerms!),
                  const SizedBox(height: 12),
                ],

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sender / Lawyer ID',
                          style: GoogleFonts.inter(color: _grey, fontSize: 10),
                        ),
                        Text(
                          doc.ownerUserId,
                          style: GoogleFonts.inter(color: _navy, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isPending ? 'Received' : 'Signed On',
                          style: GoogleFonts.inter(color: _grey, fontSize: 10),
                        ),
                        Text(
                          isPending ? createdDateStr : signedDateStr,
                          style: GoogleFonts.inter(color: _navy, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Actions
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ContractReviewScreen(
                            contract: doc,
                            isDemo: isDemo,
                          ),
                        ),
                      );
                    },
                    icon: Icon(
                      isPending ? Icons.edit_note : Icons.visibility_outlined,
                      size: 16,
                    ),
                    label: Text(
                      isPending ? 'Review & Digital Sign' : 'View Agreement Details',
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isPending ? _navy : const Color(0xFFF1F5F9),
                      foregroundColor: isPending ? Colors.white : _navy,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsRow(Map<String, dynamic> terms) {
    if (terms['type'] == 'tenancy') {
      final rent = terms['monthlyRent'] ?? 0.0;
      final deposit = terms['deposit'] ?? 0.0;
      final duration = terms['durationMonths'] ?? 12;
      return Row(
        children: [
          _buildTermChip(Icons.home, 'Rent: RM $rent/mo'),
          const SizedBox(width: 8),
          _buildTermChip(Icons.payments, 'Deposit: RM $deposit'),
          const SizedBox(width: 8),
          _buildTermChip(Icons.calendar_month, '$duration Months'),
        ],
      );
    } else if (terms['type'] == 'representation') {
      final fixed = terms['fixedRetainer'] ?? 0.0;
      final hourly = terms['hourlyRate'] ?? 0.0;
      return Row(
        children: [
          _buildTermChip(Icons.money, 'Retainer: RM $fixed'),
          const SizedBox(width: 8),
          _buildTermChip(Icons.hourglass_empty, 'Hourly: RM $hourly'),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildTermChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: _gold),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(color: _navy, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
