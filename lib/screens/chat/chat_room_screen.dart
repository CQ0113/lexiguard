import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_model.dart';
import '../../repositories/chat_repository.dart';
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

  // ── Derived from the room — never from arbitrary input ────────────────────

  bool get _isClient => widget.currentUser.role == UserRole.client;

  UserRole get _senderRole =>
      _isClient ? UserRole.client : UserRole.lawyer;

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
    _textCtrl.addListener(() => setState(() {}));
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

  bool get _isBusy => _isSending || _isUploading;

  bool get _canSend => _textCtrl.text.trim().isNotEmpty && !_isBusy;

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
        content: Text(
          message,
          style: GoogleFonts.inter(color: Colors.white),
        ),
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
      await _repo.sendAttachmentMessage(
        roomId: widget.room.id,
        senderId: widget.currentUser.id,
        senderRole: _senderRole,
        recipientId: _recipientId,
        bytes: bytes,
        fileName: fileName,
        mimeType: mimeType,
        type: msgType,
      );
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
  static String _mimeFromExtension(String fileName, {required String fallback}) {
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
      // No pending attachment state exists in this screen — pass null.
      attachmentStoragePath: null,
    );
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
              leading: const Icon(Icons.image_rounded, color: Color(0xFF0C1D36)),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (chosen == null) return;
    await _pickAndSendAttachment(imageOnly: chosen == _AttachChoice.photo);
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    _otherName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
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
                    size: 14,
                  ),
                ],
              ],
            ),
            Text(
              room.caseTitle,
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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
                        return MessageBubble(
                          message: msg,
                          isOwn: msg.senderId == widget.currentUser.id,
                        );
                      },
                    );
                  },
                ),
              ),

              // ── Composer ──────────────────────────────────────────────────
              _Composer(
                controller: _textCtrl,
                canSend: _canSend,
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
// ─────────────────────────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.canSend,
    required this.isBusy,
    required this.onSend,
    required this.onAttach,
    required this.onLexiBot,
  });

  final TextEditingController controller;
  final bool canSend;
  final bool isBusy;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onLexiBot;

  static const Color _navy = Color(0xFF0C1D36);
  static const Color _gold = Color(0xFFCFA92A);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Attach — enabled in Step 5
            IconButton(
              icon: const Icon(Icons.attach_file_rounded),
              color: isBusy ? Colors.grey[300] : _navy,
              onPressed: isBusy ? null : onAttach,
              iconSize: 22,
            ),

            // Text field
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: controller,
                  maxLines: null,
                  minLines: 1,
                  enabled: !isBusy,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(4000),
                  ],
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontSize: 14,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type a message…',
                    hintStyle: GoogleFonts.inter(
                      color: Colors.grey[400],
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

            // Ask LexiBot
            Tooltip(
              message: 'Ask LexiBot',
              child: IconButton(
                icon: const Icon(Icons.smart_toy_outlined),
                color: isBusy ? Colors.grey[300] : _gold,
                onPressed: isBusy ? null : onLexiBot,
                iconSize: 22,
              ),
            ),

            // Send
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color: canSend ? _gold : Colors.grey[300],
                ),
                iconSize: 24,
                onPressed: canSend ? onSend : null,
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

enum _AttachChoice { photo, file }
