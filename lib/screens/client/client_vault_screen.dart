import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; 

import '../../models/vault_document_model.dart';
import '../../repositories/vault_document_repository.dart';
import '../shared/vault_document_tile_widget.dart';
import '../shared/vault_upload_card_widget.dart';
import '../../core/firebase/firebase_initializer.dart';

class ClientVaultScreen extends StatefulWidget {
  final String userId;
  final List<String> sharedLawyerIds;

  const ClientVaultScreen({
    super.key,
    required this.userId,
    this.sharedLawyerIds = const [],
  });

  @override
  State<ClientVaultScreen> createState() => _ClientVaultScreenState();
}

class _ClientVaultScreenState extends State<ClientVaultScreen> {
  final VaultDocumentRepository _repository = VaultDocumentRepository();
  bool _isUploading = false;
  double _uploadProgress = 0;
  
  // Client Storage Limit
  final double _maxStorageGb = 50.0;

  String? get _authUid {
    try {
      return FirebaseInitializer.isReady ? FirebaseAuth.instance.currentUser?.uid : null;
    } catch (e) {
      return null;
    }
  }

  String get _effectiveUserId => _authUid ?? widget.userId;

  Stream<List<VaultDocumentModel>> _getSafeStream() {
    try {
      return _repository.streamClientDocuments(clientUserId: _effectiveUserId);
    } catch (e) {
      return Stream.error('Stream setup failed'); 
    }
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
    if (!FirebaseInitializer.isReady) {
      _showSnack('Demo mode: Firebase is not configured. Uploads are disabled.');
      return;
    }

    final authUid = _authUid;
    if (authUid == null) {
      _showSnack('Please sign in to upload files to Firebase Vault.');
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

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      await _repository.uploadDocumentBytes(
        bytes: bytes,
        fileName: file.name,
        ownerUserId: authUid,
        ownerRole: 'client',
        allowedUserIds: widget.sharedLawyerIds,
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _uploadProgress = value);
        },
      );
      _showSnack('Document uploaded securely.');
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

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (!FirebaseInitializer.isReady) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Text(
            'Demo mode (Firebase not connected).',
            style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<List<VaultDocumentModel>>(
        stream: _getSafeStream(),
        builder: (context, snapshot) {
          final docs = snapshot.data ?? const <VaultDocumentModel>[];
          
          // --- CALCULATE STORAGE DYNAMICALLY ---
          double totalBytes = docs.fold(0, (sum, doc) => sum + (doc.sizeBytes ?? 0));
          double totalGb = totalBytes / (1024 * 1024 * 1024);
          double totalMb = totalBytes / (1024 * 1024);
          
          String usedLabel = totalGb >= 1.0 
              ? '${totalGb.toStringAsFixed(1)} GB' 
              : '${totalMb.toStringAsFixed(1)} MB';
              
          double progressPct = (totalGb / _maxStorageGb).clamp(0.0, 1.0);
          // If there are files but size is tiny, show at least a 2% sliver of the bar so it's visible
          if (docs.isNotEmpty && progressPct < 0.02) progressPct = 0.02;

          return CustomScrollView(
            slivers: [
              // Header Section
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Document Vault',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 24,
                                  color: const Color(0xFF0B2447),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'End-to-end encrypted storage',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF0B2447),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: _pickAndUpload,
                              icon: const Icon(Icons.add, color: Colors.white),
                            ),
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
                      const SizedBox(height: 20),
                      
                      // Upload Area
                      VaultUploadCardWidget(
                        isUploading: _isUploading,
                        progress: _uploadProgress,
                        onPickFile: _pickAndUpload,
                      ),
                      const SizedBox(height: 24),
                      
                      Text(
                        'My Documents',
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
                      'Unable to load Vault documents.',
                      style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                    ),
                  ),
                )
              else if (docs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'No files uploaded yet.',
                      style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final doc = docs[index];
                        return VaultDocumentTileWidget(
                          document: doc,
                          onTap: () => _openDocument(doc),
                          trailing: IconButton(
                            onPressed: () {
                              _showSnack('Share feature coming soon!');
                            },
                            icon: const Icon(
                              Icons.share_outlined,
                              color: Color(0xFF94A3B8),
                              size: 20,
                            ),
                          ),
                        );
                      },
                      childCount: docs.length,
                    ),
                  ),
                ),
                
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          );
        },
      ),
    );
  }
}