import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/vault_document_model.dart';
import '../../repositories/vault_document_repository.dart';
import '../shared/vault_document_tile_widget.dart';
import '../shared/vault_upload_card_widget.dart';
import '../../core/firebase/firebase_initializer.dart';

enum LawyerVaultFilter { all, mine, sharedWithMe }

class LawyerVaultScreen extends StatefulWidget {
  final String lawyerUserId;

  const LawyerVaultScreen({
    super.key,
    required this.lawyerUserId,
  });

  @override
  State<LawyerVaultScreen> createState() => _LawyerVaultScreenState();
}

class _LawyerVaultScreenState extends State<LawyerVaultScreen> {
  final VaultDocumentRepository _repository = VaultDocumentRepository();
  final TextEditingController _clientIdController = TextEditingController();

  bool _isUploading = false;
  double _uploadProgress = 0;
  LawyerVaultFilter _filter = LawyerVaultFilter.all;

  String? get _authUid => FirebaseInitializer.isReady ? FirebaseAuth.instance.currentUser?.uid : null;

  String get _effectiveUserId => _authUid ?? widget.lawyerUserId;

  @override
  void dispose() {
    _clientIdController.dispose();
    super.dispose();
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

  List<VaultDocumentModel> _applyFilter(List<VaultDocumentModel> docs) {
    switch (_filter) {
      case LawyerVaultFilter.mine:
        return docs
            .where((doc) => doc.ownerUserId == _effectiveUserId)
            .toList();
      case LawyerVaultFilter.sharedWithMe:
        return docs
            .where(
              (doc) =>
                  doc.ownerUserId != _effectiveUserId &&
                  doc.allowedUserIds.contains(_effectiveUserId),
            )
            .toList();
      case LawyerVaultFilter.all:
        return docs;
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: VaultUploadCardWidget(
              title: 'Lawyer Vault',
              subtitle: 'Upload legal drafts and share them with a client ID.',
              isUploading: _isUploading,
              progress: _uploadProgress,
              onPickFile: _pickAndUpload,
              extraChild: TextField(
                controller: _clientIdController,
                decoration: InputDecoration(
                  labelText: 'Client User ID (optional)',
                  hintText: 'e.g. client_123',
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All',
                  value: LawyerVaultFilter.all,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Mine',
                  value: LawyerVaultFilter.mine,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Shared With Me',
                  value: LawyerVaultFilter.sharedWithMe,
                ),
              ],
            ),
          ),
          Expanded(
            child: !FirebaseInitializer.isReady
                ? Center(
                    child: Text(
                      'Running in demo mode (Firebase not connected).\nUploads and fetching are disabled.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                    ),
                  )
                : StreamBuilder<List<VaultDocumentModel>>(
              stream: _repository.streamAccessibleDocuments(
                userId: _effectiveUserId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Unable to load lawyer documents.\n${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                    ),
                  );
                }

                final docs = _applyFilter(
                  snapshot.data ?? const <VaultDocumentModel>[],
                );
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No documents available in this view.',
                      style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final canDelete = doc.canDelete(_effectiveUserId);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        VaultDocumentTileWidget(
                          document: doc,
                          canDelete: canDelete,
                          onDelete: canDelete ? () => _deleteDocument(doc) : null,
                        ),
                        if (!canDelete)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10, left: 6),
                            child: Text(
                              'Shared by user: ${doc.ownerUserId}',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: const Color(0xFF6B7280),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required LawyerVaultFilter value,
  }) {
    final selected = value == _filter;

    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF0B2447),
        ),
      ),
      selected: selected,
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: const Color(0xFF0B2447),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
