import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; 

import '../../models/vault_document_model.dart';
import '../../repositories/vault_document_repository.dart';
import '../shared/vault_document_tile_widget.dart';
import '../shared/vault_upload_card_widget.dart';

enum LawyerVaultFilter { all, mine, sharedWithMe }

class LawyerVaultScreen extends StatefulWidget {
  final String lawyerUserId;
  final VaultDocumentRepository? repository;

  const LawyerVaultScreen({
    super.key,
    required this.lawyerUserId,
    this.repository,
  });

  @override
  State<LawyerVaultScreen> createState() => _LawyerVaultScreenState();
}

class _LawyerVaultScreenState extends State<LawyerVaultScreen> {
  late final VaultDocumentRepository _repository;
  final TextEditingController _clientIdController = TextEditingController();

  bool _isUploading = false;
  double _uploadProgress = 0;
  LawyerVaultFilter _filter = LawyerVaultFilter.all;
  
  // Lawyer Storage Limit (100 GB)
  final double _maxStorageGb = 100.0;

  String? get _authUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  String get _effectiveUserId => _authUid ?? widget.lawyerUserId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? VaultDocumentRepository();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    super.dispose();
  }

  Future<void> _openDocument(VaultDocumentModel document) async {
    final urlString = document.downloadUrl; 
    
    if (urlString.isEmpty) {
      _showSnack('File link is not available.');
      return;
    }

    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        _showSnack('Could not open the file.');
      }
    } catch (e) {
      _showSnack('Error opening file: $e');
    }
  }

  Future<void> _pickAndUpload() async {
    final authUid = _authUid;
    if (authUid == null) {
      _showSnack('Please sign in to upload files.');
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
    );

    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      _showSnack('Unable to read selected file bytes.');
      return;
    }

    final sharedClientId = _clientIdController.text.trim();

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      await _repository.uploadDocumentBytes(
        bytes: bytes,
        fileName: file.name,
        ownerUserId: authUid,
        ownerRole: 'lawyer',
        allowedUserIds: sharedClientId.isEmpty
            ? const []
            : <String>[sharedClientId],
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _uploadProgress = value);
        },
      );
      _showSnack('Document uploaded to lawyer vault.');
      _clientIdController.clear();
    } catch (error) {
      _showSnack('Upload failed: $error');
    } finally {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _uploadProgress = 0;
      });
    }
  }

  Future<void> _deleteDocument(VaultDocumentModel document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Document'),
          content: Text('Remove "${document.fileName}" from storage and vault?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red[700]),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _repository.deleteDocument(document);
      _showSnack('Document deleted.');
    } catch (error) {
      _showSnack('Delete failed: $error');
    }
  }

  Future<void> _remindClient(VaultDocumentModel document) async {
    try {
      await _repository.updateReminderTimestamp(document.id);
      _showSnack('Dispatched secure legal draft reminder to client!');
    } catch (e) {
      _showSnack('Failed to dispatch reminder: $e');
    }
  }

  List<VaultDocumentModel> _applyFilter(List<VaultDocumentModel> docs) {
    switch (_filter) {
      case LawyerVaultFilter.mine:
        return docs.where((doc) => doc.ownerUserId == _effectiveUserId).toList();
      case LawyerVaultFilter.sharedWithMe:
        return docs.where((doc) => doc.ownerUserId != _effectiveUserId && doc.allowedUserIds.contains(_effectiveUserId)).toList();
      case LawyerVaultFilter.all:
        return docs;
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildFilterChip({required String label, required LawyerVaultFilter value}) {
    final selected = value == _filter;
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF64748B),
          fontSize: 13,
        ),
      ),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: const Color(0xFF0B2447),
      backgroundColor: Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: selected ? const Color(0xFF0B2447) : const Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<List<VaultDocumentModel>>(
        stream: _repository.streamAccessibleDocuments(userId: _effectiveUserId),
        builder: (context, snapshot) {
          final allDocs = snapshot.data ?? const <VaultDocumentModel>[];
          
          // --- CALCULATE CONTRACTS TRACKER DYNAMICALLY ---
          final contracts = allDocs.where((doc) => doc.isContract && doc.ownerUserId == _effectiveUserId).toList();
          final pendingContracts = contracts.where((doc) => doc.contractStatus == 'pending_signature').toList();
          final signedContracts = contracts.where((doc) => doc.contractStatus == 'signed').toList();
          
          // --- CALCULATE STORAGE DYNAMICALLY ---
          // Always calculate total storage based on ALL docs, regardless of the filter applied
          double totalBytes = allDocs.fold(0, (sum, doc) => sum + (doc.sizeBytes ?? 0));
          double totalGb = totalBytes / (1024 * 1024 * 1024);
          double totalMb = totalBytes / (1024 * 1024);
          
          String usedLabel = totalGb >= 1.0 
              ? '${totalGb.toStringAsFixed(1)} GB' 
              : '${totalMb.toStringAsFixed(1)} MB';
              
          double progressPct = (totalGb / _maxStorageGb).clamp(0.0, 1.0);
          if (allDocs.isNotEmpty && progressPct < 0.02) progressPct = 0.02;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: const Color(0xFF0B2447),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                        tooltip: 'Back',
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lawyer Vault',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 24,
                                  color: const Color(0xFF0B2447),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Manage and share legal drafts securely',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Encrypted Storage Bar
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ]
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.shield_outlined, color: Color(0xFFD4AF37), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Encrypted Storage',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF0B2447),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '$usedLabel / ${_maxStorageGb.toStringAsFixed(0)} GB',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Gradient Progress Bar
                            LayoutBuilder(
                              builder: (context, constraints) {
                                return Container(
                                  height: 6,
                                  width: constraints.maxWidth,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: constraints.maxWidth * progressPct,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(999),
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFF0B2447), Color(0xFFD4AF37)],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sent Contracts Tracker Dashboard Card
                      if (contracts.isNotEmpty) ...[
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFFDE68A)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.01),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${pendingContracts.length}',
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Pending Signatures',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFFB45309),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: const Color(0xFFA7F3D0)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.01),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    )
                                  ]
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      '${signedContracts.length}',
                                      style: GoogleFonts.inter(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF047857),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Signed Agreements',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF047857),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      
                      // Upload Area
                      VaultUploadCardWidget(
                        isUploading: _isUploading,
                        progress: _uploadProgress,
                        onPickFile: _pickAndUpload,
                      ),
                      const SizedBox(height: 12),
                      
                      // Client ID Input
                      TextField(
                        controller: _clientIdController,
                        decoration: InputDecoration(
                          labelText: 'Share with Client ID (Optional)',
                          hintText: 'e.g. client_123',
                          labelStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14),
                          prefixIcon: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF94A3B8), size: 20),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Filters
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip(label: 'All Files', value: LawyerVaultFilter.all),
                            const SizedBox(width: 8),
                            _buildFilterChip(label: 'My Uploads', value: LawyerVaultFilter.mine),
                            const SizedBox(width: 8),
                            _buildFilterChip(label: 'Shared With Me', value: LawyerVaultFilter.sharedWithMe),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Text(
                        'Workspace Documents',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 18,
                          color: const Color(0xFF0B2447),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Document List Section
              if (snapshot.connectionState == ConnectionState.waiting)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Unable to load lawyer documents.',
                      style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                    ),
                  ),
                )
              else 
                Builder(
                  builder: (context) {
                    final filteredDocs = _applyFilter(allDocs);
                    
                    if (filteredDocs.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Text(
                            'No documents available in this view.',
                            style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                          ),
                        ),
                      );
                    }
                    
                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final doc = filteredDocs[index];
                            final canDelete = doc.canDelete(_effectiveUserId);
                            
                            return VaultDocumentTileWidget(
                              document: doc,
                              onTap: () => _openDocument(doc),
                              extraSubtitle: !canDelete ? 'Shared by user: ${doc.ownerUserId}' : null,
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (doc.isContract && doc.contractStatus == 'pending_signature' && canDelete) ...[
                                    IconButton(
                                      onPressed: () => _remindClient(doc),
                                      tooltip: 'Send signature reminder',
                                      icon: const Icon(
                                        Icons.notification_important_outlined,
                                        color: Color(0xFFD4AF37),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  if (canDelete)
                                    IconButton(
                                      onPressed: () => _deleteDocument(doc),
                                      tooltip: 'Delete document',
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        color: Color(0xFFEF4444),
                                        size: 22,
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                          childCount: filteredDocs.length,
                        ),
                      ),
                    );
                  }
                ),
                
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}