import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart'; 
import 'package:cloud_functions/cloud_functions.dart'; 
import 'package:flutter/services.dart'; 

import '../../models/vault_document_model.dart';
import '../../repositories/vault_document_repository.dart';
import '../shared/vault_document_tile_widget.dart';
import '../shared/vault_upload_card_widget.dart';

class ClientVaultScreen extends StatefulWidget {
  final String userId;
  final List<String> sharedLawyerIds;
  final VaultDocumentRepository? repository;

  const ClientVaultScreen({
    super.key,
    required this.userId,
    this.sharedLawyerIds = const [],
    this.repository,
  });

  @override
  State<ClientVaultScreen> createState() => _ClientVaultScreenState();
}

class _ClientVaultScreenState extends State<ClientVaultScreen> {
  late final VaultDocumentRepository _repository;
  bool _isUploading = false;
  double _uploadProgress = 0;
  
  final double _maxStorageGb = 50.0;
  final Map<String, DateTime> _activeShareLinks = {};

  String? get _authUid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  String get _effectiveUserId => _authUid ?? widget.userId;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? VaultDocumentRepository();
  }

  Stream<List<VaultDocumentModel>> _getSafeStream() {
    return _repository.streamClientDocuments(clientUserId: _effectiveUserId);
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

  Future<void> _showShareDialog(VaultDocumentModel doc) async {
    int selectedHours = 24; 
    bool isGenerating = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time-Bomb Share Link',
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0B2447),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Link will automatically expire after the set duration.',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildDurationButton(1, '1h', selectedHours, (val) => setModalState(() => selectedHours = val)),
                      _buildDurationButton(6, '6h', selectedHours, (val) => setModalState(() => selectedHours = val)),
                      _buildDurationButton(24, '24h', selectedHours, (val) => setModalState(() => selectedHours = val)),
                      _buildDurationButton(48, '48h', selectedHours, (val) => setModalState(() => selectedHours = val)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD4AF37),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: isGenerating
                          ? null
                          : () async {
                              setModalState(() => isGenerating = true);
                              
                              try {
                                final result = await FirebaseFunctions.instance
                                    .httpsCallable('generateSecureShareLink')
                                    .call({
                                  'storagePath': doc.storagePath,
                                  'expirationHours': selectedHours,
                                });

                                if (mounted) {
                                  setModalState(() => isGenerating = false);
                                  
                                  final generatedUrl = result.data['url'] as String?;
                                  final expiresAtMs = result.data['expiresAt'] as int?; 

                                  if (generatedUrl != null) {
                                    Clipboard.setData(ClipboardData(text: generatedUrl));
                                    _showSnack('Link generated and copied to clipboard!');
                                    
                                    if (expiresAtMs != null) {
                                      setState(() {
                                        _activeShareLinks[doc.storagePath] = DateTime.fromMillisecondsSinceEpoch(expiresAtMs);
                                      });
                                    }
                                    
                                    Navigator.pop(context);
                                  }
                                }
                              } on FirebaseFunctionsException catch (e) {
                                if (mounted) {
                                  setModalState(() => isGenerating = false);
                                  Navigator.pop(context);
                                  _showSnack('Failed to generate link: ${e.message}');
                                }
                              } catch (e) {
                                if (mounted) {
                                  setModalState(() => isGenerating = false);
                                  Navigator.pop(context);
                                  _showSnack('Error connecting to server: $e');
                                }
                              }
                            },
                      child: isGenerating
                          ? const SizedBox(
                              height: 20, width: 20, 
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.link, color: const Color(0xFF0B2447)),
                                const SizedBox(width: 8),
                                Text(
                                  'Generate & Copy Link',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFF0B2447),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDurationButton(int value, String label, int selectedHours, Function(int) onChanged) {
    final isSelected = value == selectedHours;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0B2447) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF0B2447) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF0B2447),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<List<VaultDocumentModel>>(
        stream: _getSafeStream(),
        builder: (context, snapshot) {
          final docs = snapshot.data ?? const <VaultDocumentModel>[];
          
          double totalBytes = docs.fold(0, (sum, doc) => sum + (doc.sizeBytes ?? 0));
          double totalGb = totalBytes / (1024 * 1024 * 1024);
          double totalMb = totalBytes / (1024 * 1024);
          
          String usedLabel = totalGb >= 1.0 
              ? '${totalGb.toStringAsFixed(1)} GB' 
              : '${totalMb.toStringAsFixed(1)} MB';
              
          double progressPct = (totalGb / _maxStorageGb).clamp(0.0, 1.0);
          if (docs.isNotEmpty && progressPct < 0.02) progressPct = 0.02;

          return CustomScrollView(
            slivers: [
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
                        
                        String? shareNotice;
                        bool isExpired = false;
                        final expiresAt = _activeShareLinks[doc.storagePath];

                        if (expiresAt != null) {
                          final now = DateTime.now();
                          
                          if (expiresAt.isAfter(now)) {
                            final diff = expiresAt.difference(now);
                            final hours = diff.inHours;
                            final minutes = diff.inMinutes % 60;
                            
                            if (hours > 0) {
                              shareNotice = 'Share link: ${hours}h ${minutes}m remaining';
                            } else if (minutes > 0) {
                              shareNotice = 'Share link: ${minutes}m remaining';
                            } else {
                              shareNotice = 'Share link: < 1m remaining';
                            }
                          } else {
                            shareNotice = 'Share link: Expired';
                            isExpired = true;
                          }
                        }

                        return VaultDocumentTileWidget(
                          document: doc,
                          activeShareText: shareNotice, 
                          isShareExpired: isExpired, 
                          onTap: () => _openDocument(doc),
                          trailing: IconButton(
                            onPressed: () => _showShareDialog(doc),
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
