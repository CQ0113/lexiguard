import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

  // ── SAFE GETTERS ────────────────────────────────────────────────────────
  // Wrapped in try-catch to prevent synchronous web crashes during build
  String? get _authUid {
    try {
      return FirebaseInitializer.isReady ? FirebaseAuth.instance.currentUser?.uid : null;
    } catch (e) {
      return null;
    }
  }

  String get _effectiveUserId => _authUid ?? widget.userId;

  // ── SAFE STREAM INITIALIZER ─────────────────────────────────────────────
  // Prevents Firestore from crashing the build method if the query is invalid
  Stream<List<VaultDocumentModel>> _getSafeStream() {
    try {
      return _repository.streamClientDocuments(clientUserId: _effectiveUserId);
    } catch (e) {
      print('🔥 Sync Stream Setup Error: $e');
      // Pass the error safely into the stream so the builder catches it,
      // rather than crashing the widget build phase.
      return Stream.error('Stream setup failed'); 
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
    
    final fileBytes = picked.files.single.bytes;
    final fileName = picked.files.single.name;
    
    if (fileBytes == null) {
      _showSnack('Unable to read selected file bytes.');
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      await _repository.uploadDocumentBytes(
        bytes: fileBytes,
        fileName: fileName,
        ownerUserId: authUid,
        ownerRole: 'client', 
        allowedUserIds: [...widget.sharedLawyerIds],
        onProgress: (value) {
          if (!mounted) return;
          setState(() => _uploadProgress = value);
        },
      );
      _showSnack('Document uploaded successfully! 🎉');
      
    } on FirebaseException catch (e) {
      print('🔥 Firebase Error [${e.code}]: ${e.message}');
      _showSnack('Upload failed: ${e.message}');
    } catch (error) {
      print('⚠️ Unknown/Web Platform Error: $error');
      _showSnack('Upload encountered an error. Check console for details.');
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
          content: Text('Remove "${document.fileName}" from your vault?'),
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
    } on FirebaseException catch (e) {
      print('🔥 Firebase Delete Error [${e.code}]: ${e.message}');
      _showSnack('Delete failed: ${e.message}');
    } catch (error) {
      print('⚠️ Unknown/Web Platform Error on Delete: $error');
      _showSnack('Delete failed. Check console for details.');
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
              title: 'Client Vault',
              subtitle: 'Upload land titles, survey reports, and legal records.',
              isUploading: _isUploading,
              progress: _uploadProgress,
              onPickFile: _pickAndUpload,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'My Documents',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: const Color(0xFF0B2447),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
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
              stream: _getSafeStream(), // Safely injected stream
              builder: (context, snapshot) {
                
                if (snapshot.hasError) {
                  // We removed the string interpolation of snapshot.error here 
                  // to prevent JS Object casting issues on the UI layer.
                  print('🔥 StreamBuilder Error occurred. Check browser console.');
                  return Center(
                    child: Text(
                      'Unable to load Vault documents.\nPlease check your browser console for Firebase permission errors.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data ?? const <VaultDocumentModel>[];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No files uploaded yet.',
                      style: GoogleFonts.inter(color: const Color(0xFF6B7280)),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    return VaultDocumentTileWidget(
                      document: doc,
                      canDelete: doc.canDelete(_effectiveUserId),
                      onDelete: () => _deleteDocument(doc),
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
}