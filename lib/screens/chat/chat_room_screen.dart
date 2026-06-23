import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/user_model.dart';
import '../../models/vault_document_model.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/vault_document_repository.dart';
import '../../repositories/user_repository.dart';
import 'widgets/lexibot_draft_panel.dart';
import 'widgets/message_bubble.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CHAT ROOM SCREEN — SCRUM-17 Steps 3 + 5
//
// Messaging room between a client and their approved lawyer.
// Supports text messages (Step 3) and image/file attachments (Step 5).
// LexiBot (Steps 6-7) is wired as a disabled button with a tooltip.
// ─────────────────────────────────────────────────────────────────────────────

class ChatRoomScreen extends StatefulWidget {
  const ChatRoomScreen({
    super.key,
    required this.currentUser,
    required this.room,
    this.repository,
  });

  final UserModel currentUser;
  final ChatRoom room;

  /// Optional injection for tests.
  final ChatRepository? repository;

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  static const Color _navy = Color(0xFF0C1D36);
  static const Color _gold = Color(0xFFCFA92A);

  late final ChatRepository _repo;
  final TextEditingController _textCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  bool _isSending = false;
  bool _isUploading = false;

  // Storage path of the most recently sent attachment, passed to LexiBot so it
  // can ground answers on the shared image/file. Cleared after each draft.
  String? _lastAttachmentPath;

  // ── Derived from the room — never from arbitrary input ────────────────────

  bool get _isClient => widget.currentUser.role == UserRole.client;

  UserRole get _senderRole => _isClient ? UserRole.client : UserRole.lawyer;

  String get _recipientId =>
      _isClient ? widget.room.lawyerId : widget.room.clientId;

  String get _otherName =>
      _isClient ? widget.room.lawyerName : widget.room.clientName;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ChatRepository();
    // Clear the badge for the opener when the room first loads.
    _markRead();
    // NOTE: Do NOT add a setState listener on _textCtrl here.
    // That would rebuild the entire Scaffold (including the messages StreamBuilder)
    // on every keystroke. The _Composer widget handles its own rebuild internally.
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _markRead() {
    _repo.markRoomRead(widget.room.id, widget.currentUser.id);
  }

  Future<void> _deleteMessage(String messageId) async {
    try {
      await _repo.deleteMessage(roomId: widget.room.id, messageId: messageId);
    } catch (e) {
      _showErrorSnackBar('Could not delete message: ${e.toString()}');
    }
  }

  Future<void> _editMessage(String messageId, String newText) async {
    try {
      await _repo.editMessage(
        roomId: widget.room.id,
        messageId: messageId,
        newText: newText,
      );
    } catch (e) {
      _showErrorSnackBar('Could not edit message: ${e.toString()}');
    }
  }

  Future<void> _showRecipientProfile() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: _gold)),
    );
    try {
      if (_isClient) {
        final users = await UserRepository().getUsers([_recipientId]);
        if (mounted) Navigator.of(context).pop(); // Dismiss loader
        if (users.isNotEmpty && mounted) {
          _showProfileDetailsBottomSheet(users.first);
        } else {
          throw Exception('Profile not found.');
        }
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('connection_requests')
            .doc(widget.room.id)
            .get();
        if (mounted) Navigator.of(context).pop(); // Dismiss loader
        if (doc.exists && mounted) {
          final data = doc.data();
          final reveal = data?['clientReveal'] as Map<String, dynamic>?;
          if (reveal != null) {
            final clientUser = UserModel(
              id: _recipientId,
              name: reveal['name']?.toString() ?? widget.room.clientName,
              email: reveal['email']?.toString() ?? '',
              phone: reveal['phone']?.toString() ?? '',
              role: UserRole.client,
            );
            _showProfileDetailsBottomSheet(clientUser);
          } else {
            final clientUser = UserModel(
              id: _recipientId,
              name: widget.room.clientName,
              email: '',
              phone: '',
              role: UserRole.client,
            );
            _showProfileDetailsBottomSheet(clientUser);
          }
        } else {
          throw Exception('Connection request not found.');
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Dismiss loader
      _showErrorSnackBar('Could not load profile: ${e.toString()}');
    }
  }

  void _showProfileDetailsBottomSheet(UserModel user) {
    final isLawyer = user.role == UserRole.lawyer;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFF8FAFC),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Avatar
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _navy.withValues(alpha: 0.1),
                  backgroundImage:
                      isLawyer &&
                          user.avatarUrl != null &&
                          user.avatarUrl!.isNotEmpty
                      ? NetworkImage(user.avatarUrl!)
                      : null,
                  child:
                      !isLawyer ||
                          user.avatarUrl == null ||
                          user.avatarUrl!.isEmpty
                      ? Text(
                          _initials(user.name),
                          style: GoogleFonts.inter(
                            color: _navy,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 16),
                // Name
                Text(
                  user.legalFullName ?? user.name,
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isLawyer
                        ? _gold.withValues(alpha: 0.12)
                        : _navy.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isLawyer ? 'VERIFIED LAWYER' : 'CLIENT',
                    style: GoogleFonts.inter(
                      color: isLawyer ? _gold : _navy,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Details Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      if (isLawyer) ...[
                        _buildDetailRow(
                          Icons.business_rounded,
                          'Firm Name',
                          user.firmName ?? 'Not provided',
                        ),
                        _buildDetailDivider(),
                        _buildDetailRow(
                          Icons.gavel_rounded,
                          'Specialization',
                          user.specialization ?? 'Not provided',
                        ),
                        _buildDetailDivider(),
                        _buildDetailRow(
                          Icons.history_rounded,
                          'Experience',
                          user.yearsExperience != null
                              ? '${user.yearsExperience} years'
                              : 'Not provided',
                        ),
                        _buildDetailDivider(),
                        _buildDetailRow(
                          Icons.monetization_on_outlined,
                          'Hourly Rate',
                          user.hourlyRate != null
                              ? 'RM ${user.hourlyRate!.toStringAsFixed(2)} / hour'
                              : 'Not provided',
                        ),
                        _buildDetailDivider(),
                        _buildDetailRow(
                          Icons.badge_outlined,
                          'Bar Number',
                          user.barNumber ?? 'Not provided',
                        ),
                        if (user.languages.isNotEmpty) ...[
                          _buildDetailDivider(),
                          _buildLanguagesRow(user.languages),
                        ],
                      ] else ...[
                        _buildDetailRow(
                          Icons.email_outlined,
                          'Email',
                          user.email,
                        ),
                        _buildDetailDivider(),
                        _buildDetailRow(
                          Icons.phone_outlined,
                          'Phone',
                          user.phone.isNotEmpty ? user.phone : 'Not provided',
                        ),
                        _buildDetailDivider(),
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailRow(
                                Icons.fingerprint_rounded,
                                'Client ID',
                                user.id,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy_rounded,
                                color: Color(0xFFCFA92A),
                                size: 20,
                              ),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: user.id));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Client ID copied to clipboard.',
                                      style: GoogleFonts.inter(),
                                    ),
                                    backgroundColor: const Color(0xFF0C1D36),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Close button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: BorderSide(color: _navy.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Close',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF64748B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailDivider() {
    return Divider(color: Colors.grey[200], height: 16, thickness: 1);
  }

  Widget _buildLanguagesRow(List<String> languages) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.translate_rounded,
            size: 20,
            color: Color(0xFF64748B),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Languages',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF94A3B8),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: languages.map((lang) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _gold.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        lang,
                        style: GoogleFonts.inter(
                          color: _navy,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool get _isBusy => _isSending || _isUploading;

  // _canSend is now computed inside _Composer — not needed at this scope.
  // Kept here only for the onSend guard inside _send().

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    setState(() => _isSending = true);
    try {
      await _repo.sendTextMessage(
        roomId: widget.room.id,
        senderId: widget.currentUser.id,
        senderRole: _senderRole,
        text: text,
        recipientId: _recipientId,
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Could not send message: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickAndSendAttachment({required bool imageOnly}) async {
    final result = await FilePicker.platform.pickFiles(
      type: imageOnly ? FileType.image : FileType.any,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      if (!mounted) return;
      _showErrorSnackBar('Could not read file. Please try again.');
      return;
    }

    final fileName = file.name;
    final mimeType = imageOnly
        ? _mimeFromExtension(fileName, fallback: 'image/jpeg')
        : _mimeFromExtension(fileName, fallback: 'application/octet-stream');
    final msgType = imageOnly ? MessageType.image : MessageType.file;

    setState(() => _isUploading = true);
    try {
      final path = await _repo.sendAttachmentMessage(
        roomId: widget.room.id,
        senderId: widget.currentUser.id,
        senderRole: _senderRole,
        recipientId: _recipientId,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        type: msgType,
      );
      if (mounted) setState(() => _lastAttachmentPath = path);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('Could not send attachment: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Derives a MIME type from a file extension.
  ///
  /// No external `mime` package needed — extension lookup covers all types
  /// permitted by the Storage rule.
  static String _mimeFromExtension(
    String fileName, {
    required String fallback,
  }) {
    final ext = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : '';
    const table = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'gif': 'image/gif',
      'webp': 'image/webp',
      'heic': 'image/heic',
      'heif': 'image/heif',
      'pdf': 'application/pdf',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'ppt': 'application/vnd.ms-powerpoint',
      'pptx':
          'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'txt': 'text/plain',
    };
    return table[ext] ?? fallback;
  }

  Future<void> _openLexiBot() async {
    final seedQuestion = _textCtrl.text.trim().isEmpty
        ? null
        : _textCtrl.text.trim();
    final draft = await showLexiBotDraft(
      context,
      roomId: widget.room.id,
      seedQuestion: seedQuestion,
      // Ground the answer on the most recently shared attachment, if any.
      attachmentStoragePath: _lastAttachmentPath,
    );
    // Consume the attachment context so it doesn't leak into the next query.
    if (mounted) setState(() => _lastAttachmentPath = null);
    if (draft != null && draft.isNotEmpty && mounted) {
      _textCtrl.text = draft;
      _textCtrl.selection = TextSelection.collapsed(
        offset: _textCtrl.text.length,
      );
    }
  }

  Future<void> _showAttachmentPicker() async {
    final chosen = await showModalBottomSheet<_AttachChoice>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(
                Icons.image_rounded,
                color: Color(0xFF0C1D36),
              ),
              title: Text(
                'Photo',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0C1D36),
                ),
              ),
              onTap: () => Navigator.of(ctx).pop(_AttachChoice.photo),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(
                Icons.insert_drive_file_rounded,
                color: Color(0xFF0C1D36),
              ),
              title: Text(
                'File',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0C1D36),
                ),
              ),
              onTap: () => Navigator.of(ctx).pop(_AttachChoice.file),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(
                Icons.shield_outlined,
                color: Color(0xFF0C1D36),
              ),
              title: Text(
                'Vault Document',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF0C1D36),
                ),
              ),
              onTap: () => Navigator.of(ctx).pop(_AttachChoice.vault),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    if (chosen == _AttachChoice.vault) {
      await _showVaultFilePicker();
    } else {
      await _pickAndSendAttachment(imageOnly: chosen == _AttachChoice.photo);
    }
  }

  Future<void> _showVaultFilePicker() async {
    final VaultDocumentRepository vaultRepo = VaultDocumentRepository();
    final chosenDoc = await showDialog<VaultDocumentModel>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: Text(
            'Select Vault Document',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0C1D36),
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: StreamBuilder<List<VaultDocumentModel>>(
              stream: vaultRepo.streamAccessibleDocuments(
                userId: widget.currentUser.id,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0C1D36)),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading documents: ${snapshot.error}'),
                  );
                }
                final docs = snapshot.data ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No documents in vault.',
                      style: GoogleFonts.inter(color: Colors.grey[500]),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    IconData icon = Icons.insert_drive_file_outlined;
                    if (doc.contentType?.startsWith('image/') ?? false) {
                      icon = Icons.image_outlined;
                    } else if (doc.contentType == 'application/pdf') {
                      icon = Icons.picture_as_pdf_outlined;
                    }
                    return ListTile(
                      leading: Icon(icon, color: const Color(0xFF0C1D36)),
                      title: Text(
                        doc.fileName,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        doc.contentType ?? 'Document',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                      onTap: () => Navigator.of(dialogCtx).pop(doc),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: const Color(0xFF0C1D36)),
              ),
            ),
          ],
        );
      },
    );

    if (chosenDoc == null || !mounted) return;

    // Ask user: Direct send or Time-bomb expiring link
    final shareModeChoice = await showDialog<String>(
      context: context,
      builder: (modeCtx) {
        return AlertDialog(
          title: Text(
            'Share Document',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0C1D36),
            ),
          ),
          content: Text(
            'How would you like to share "${chosenDoc.fileName}" in this chat?',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF334155),
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C1D36),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('Send Document Directly'),
                    onPressed: () => Navigator.of(modeCtx).pop('direct'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFCFA92A),
                      side: const BorderSide(color: Color(0xFFCFA92A)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.timer_outlined, size: 16),
                    label: const Text('Send Expiring Link (Time-Bomb)'),
                    onPressed: () => Navigator.of(modeCtx).pop('timebomb'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(modeCtx).pop(),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: Colors.grey[500]),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );

    if (shareModeChoice == null) return;

    if (shareModeChoice == 'direct') {
      setState(() => _isUploading = true);
      try {
        final String mimeType =
            chosenDoc.contentType ?? 'application/octet-stream';
        final msgType = mimeType.startsWith('image/')
            ? MessageType.image
            : MessageType.file;

        // Directly link vault attachment without local download to resolve CORS & Storage permissions
        final path = await _repo.sendVaultAttachmentMessage(
          roomId: widget.room.id,
          senderId: widget.currentUser.id,
          senderRole: _senderRole,
          recipientId: _recipientId,
          downloadUrl: chosenDoc.downloadUrl,
          storagePath: chosenDoc.storagePath,
          fileName: chosenDoc.fileName,
          mimeType: mimeType,
          type: msgType,
          sizeBytes: chosenDoc.sizeBytes ?? 0,
        );

        if (mounted) setState(() => _lastAttachmentPath = path);
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('Could not share document: ${e.toString()}');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    } else if (shareModeChoice == 'timebomb') {
      if (!mounted) return;
      int selectedHours = 24;
      final bool? confirmTimebomb = await showDialog<bool>(
        context: context,
        builder: (timebombCtx) {
          return StatefulBuilder(
            builder: (context, setTimeState) {
              return AlertDialog(
                title: Text(
                  'Expiring Share Link',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0C1D36),
                  ),
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select link validity duration. Once expired, the recipient will not be able to access the document.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildTimeOption(
                          timebombCtx,
                          1,
                          '1h',
                          selectedHours,
                          (v) => setTimeState(() => selectedHours = v),
                        ),
                        _buildTimeOption(
                          timebombCtx,
                          6,
                          '6h',
                          selectedHours,
                          (v) => setTimeState(() => selectedHours = v),
                        ),
                        _buildTimeOption(
                          timebombCtx,
                          24,
                          '24h',
                          selectedHours,
                          (v) => setTimeState(() => selectedHours = v),
                        ),
                        _buildTimeOption(
                          timebombCtx,
                          48,
                          '48h',
                          selectedHours,
                          (v) => setTimeState(() => selectedHours = v),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(timebombCtx).pop(false),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(color: Colors.grey[500]),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0C1D36),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(timebombCtx).pop(true),
                    child: const Text('Generate & Send'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (confirmTimebomb != true) return;

      setState(() => _isUploading = true);
      try {
        final result = await FirebaseFunctions.instance
            .httpsCallable('generateSecureShareLink')
            .call({
              'storagePath': chosenDoc.storagePath,
              'expirationHours': selectedHours,
            });

        final generatedUrl = result.data['url'] as String?;
        if (generatedUrl == null) {
          throw Exception('Cloud function returned empty redirect URL.');
        }

        final DateTime expiresAt = DateTime.now().add(
          Duration(hours: selectedHours),
        );
        // Send the generated link as a secure message in the chat
        await _repo.sendTextMessage(
          roomId: widget.room.id,
          senderId: widget.currentUser.id,
          senderRole: _senderRole,
          recipientId: _recipientId,
          text:
              '🔒 Secure Expiring Link for "${chosenDoc.fileName}" (valid for $selectedHours hours):\n$generatedUrl',
          expiresAt: expiresAt,
          attachmentName: chosenDoc.fileName,
          attachmentDownloadUrl: generatedUrl,
        );
      } catch (e) {
        if (!mounted) return;
        _showErrorSnackBar('Failed to generate expiring link: ${e.toString()}');
      } finally {
        if (mounted) setState(() => _isUploading = false);
      }
    }
  }

  Widget _buildTimeOption(
    BuildContext ctx,
    int value,
    String label,
    int selected,
    Function(int) onTap,
  ) {
    final active = value == selected;
    return GestureDetector(
      onTap: () => onTap(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF0C1D36) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? const Color(0xFF0C1D36) : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            color: active ? Colors.white : const Color(0xFF0C1D36),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isClient = _isClient;
    final room = widget.room;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: GestureDetector(
          onTap: _showRecipientProfile,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: _gold.withValues(alpha: 0.2),
                backgroundImage:
                    !isClient &&
                        room.lawyerAvatarUrl != null &&
                        room.lawyerAvatarUrl!.isNotEmpty
                    ? NetworkImage(room.lawyerAvatarUrl!)
                    : null,
                child:
                    isClient ||
                        room.lawyerAvatarUrl == null ||
                        room.lawyerAvatarUrl!.isEmpty
                    ? Text(
                        _initials(_otherName),
                        style: GoogleFonts.inter(
                          color: _gold,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _otherName,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Show gold verified badge when client views lawyer
                        if (isClient) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            color: _gold,
                            size: 13,
                          ),
                        ],
                      ],
                    ),
                    Text(
                      room.caseTitle,
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Colors.white),
            tooltip: 'View Profile',
            onPressed: _showRecipientProfile,
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // ── Message list ──────────────────────────────────────────────
              Expanded(
                child: StreamBuilder<List<ChatMessage>>(
                  stream: _repo.streamMessages(room.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Could not load messages.',
                          style: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 13,
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF0C1D36),
                        ),
                      );
                    }

                    final messages = snapshot.data ?? const [];

                    // Mark read when new messages arrive from the other party.
                    if (messages.isNotEmpty) {
                      final newest = messages.first;
                      final myUnread =
                          room.unreadCounts[widget.currentUser.id] ?? 0;
                      if (newest.senderId != widget.currentUser.id &&
                          myUnread > 0) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) _markRead();
                        });
                      }
                    }

                    if (messages.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            'No messages yet. Say hello!',
                            style: GoogleFonts.inter(
                              color: Colors.grey[400],
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, i) {
                        final msg = messages[i];
                        final isMyMsg = msg.senderId == widget.currentUser.id;
                        return MessageBubble(
                          message: msg,
                          isOwn: isMyMsg,
                          onDelete: isMyMsg
                              ? () => _deleteMessage(msg.id)
                              : null,
                          onEdit: isMyMsg && msg.type == MessageType.text
                              ? (newText) => _editMessage(msg.id, newText)
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Composer ──────────────────────────────────────────────────
              _Composer(
                controller: _textCtrl,
                isBusy: _isBusy,
                onSend: _send,
                onAttach: _showAttachmentPicker,
                onLexiBot: _openLexiBot,
              ),
            ],
          ),

          // ── Upload overlay ─────────────────────────────────────────────────
          if (_isUploading)
            Container(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Uploading…',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPOSER
// Stateful so it can listen to the TextEditingController and rebuild only
// itself (send-button state) without touching the parent Scaffold or the
// messages StreamBuilder.
// ─────────────────────────────────────────────────────────────────────────────

class _Composer extends StatefulWidget {
  const _Composer({
    required this.controller,
    required this.isBusy,
    required this.onSend,
    required this.onAttach,
    required this.onLexiBot,
  });

  final TextEditingController controller;
  final bool isBusy;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onLexiBot;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  static const Color _navy = Color(0xFF0C1D36);
  static const Color _gold = Color(0xFFCFA92A);

  bool get _canSend =>
      widget.controller.text.trim().isNotEmpty && !widget.isBusy;

  @override
  void initState() {
    super.initState();
    // Only _Composer rebuilds when text changes — not the whole screen.
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach Button
            Container(
              margin: const EdgeInsets.only(bottom: 2, right: 6),
              decoration: BoxDecoration(
                color: widget.isBusy
                    ? Colors.transparent
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.attach_file_rounded),
                color: widget.isBusy ? Colors.grey[300] : _navy,
                onPressed: widget.isBusy ? null : widget.onAttach,
                iconSize: 20,
              ),
            ),

            // Text field Capsule
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: widget.controller,
                  maxLines: null,
                  minLines: 1,
                  enabled: !widget.isBusy,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [LengthLimitingTextInputFormatter(4000)],
                  style: GoogleFonts.inter(color: _navy, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: GoogleFonts.inter(
                      color: const Color(0xFF94A3B8),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),

            // Ask LexiBot Button
            Container(
              margin: const EdgeInsets.only(left: 6, bottom: 2),
              decoration: BoxDecoration(
                color: widget.isBusy
                    ? Colors.transparent
                    : const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
              ),
              child: Tooltip(
                message: 'Ask LexiBot',
                child: IconButton(
                  icon: const Icon(Icons.smart_toy_outlined),
                  color: widget.isBusy ? Colors.grey[300] : _gold,
                  onPressed: widget.isBusy ? null : widget.onLexiBot,
                  iconSize: 20,
                ),
              ),
            ),

            // Send Button
            Container(
              margin: const EdgeInsets.only(left: 6, bottom: 2),
              decoration: BoxDecoration(
                color: _canSend ? _gold : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: _canSend ? Colors.white : const Color(0xFF94A3B8),
                ),
                iconSize: 18,
                onPressed: _canSend ? widget.onSend : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// INTERNAL ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum _AttachChoice { photo, file, vault }
