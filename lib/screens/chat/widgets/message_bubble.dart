import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/chat_message_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MESSAGE BUBBLE — stateless widget (Step 3) updated for attachments (Step 5)
//
// Renders a single chat message. Own messages (isOwn == true) appear right-
// aligned with a navy background; the other party's messages appear left-
// aligned with a light grey background.
//
// - text   → plain text inside the bubble.
// - image  → inline Image.network constrained to 240×320 px, tap opens a
//            full-screen InteractiveViewer dialog.
// - file   → horizontal chip with file icon, filename, and formatted size;
//            tap opens the download URL via url_launcher.
//
// Long-press toggles a timestamp line below the bubble.
// ─────────────────────────────────────────────────────────────────────────────

class MessageBubble extends StatefulWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwn,
    this.onDelete,
    this.onEdit,
  });

  final ChatMessage message;
  final bool isOwn;
  final VoidCallback? onDelete;
  final ValueChanged<String>? onEdit;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  static const Color _navy = Color(0xFF0C1D36);
  static const Color _ownBubbleBg = Color(0xFF0C1D36);
  static const Color _otherBubbleBg = Color(0xFFF1F5F9);

  bool _showTimestamp = false;
  Timer? _countdownTimer;
  Duration _timeLeft = Duration.zero;

  static final DateFormat _timeFmt = DateFormat('d MMM, h:mm a');

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    if (widget.message.expiresAt != null) {
      _calculateTimeLeft();
      if (_timeLeft > Duration.zero) {
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          _calculateTimeLeft();
          if (_timeLeft <= Duration.zero) {
            timer.cancel();
          }
          if (mounted) {
            setState(() {});
          }
        });
      }
    }
  }

  void _calculateTimeLeft() {
    final expiresAt = widget.message.expiresAt;
    if (expiresAt == null) {
      _timeLeft = Duration.zero;
      return;
    }
    final now = DateTime.now();
    _timeLeft = expiresAt.difference(now);
    if (_timeLeft.isNegative) {
      _timeLeft = Duration.zero;
    }
  }

  String _formatDuration(Duration d) {
    if (d <= Duration.zero) return 'Expired';
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    final List<String> parts = [];
    if (hours > 0) {
      parts.add('${hours}h');
    }
    if (minutes > 0 || hours > 0) {
      parts.add('${minutes}m');
    }
    parts.add('${seconds}s');

    return '${parts.join(' ')} left';
  }

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final isText = widget.message.type == MessageType.text;
        final hasTimer = widget.message.expiresAt != null;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Copy Text
              if (isText)
                ListTile(
                  leading: const Icon(
                    Icons.copy_rounded,
                    color: Color(0xFF0C1D36),
                  ),
                  title: Text(
                    'Copy Message Text',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Clipboard.setData(
                      ClipboardData(text: widget.message.text ?? ''),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Message copied to clipboard.',
                          style: GoogleFonts.inter(),
                        ),
                        backgroundColor: const Color(0xFF0C1D36),
                      ),
                    );
                  },
                ),
              // Message Info
              ListTile(
                leading: const Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF0C1D36),
                ),
                title: Text(
                  'Message Details',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  setState(() => _showTimestamp = !_showTimestamp);
                },
              ),
              // Edit Message
              if (widget.isOwn && isText && !hasTimer && widget.onEdit != null)
                ListTile(
                  leading: const Icon(
                    Icons.edit_outlined,
                    color: Color(0xFFCFA92A),
                  ),
                  title: Text(
                    'Edit Message',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showEditDialog();
                  },
                ),
              // Delete Message
              if (widget.isOwn && widget.onDelete != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                  ),
                  title: Text(
                    'Delete Message',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w500,
                      color: Colors.red,
                    ),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _confirmDelete();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog() {
    final editCtrl = TextEditingController(text: widget.message.text);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Edit Message',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0C1D36),
            ),
          ),
          content: TextField(
            controller: editCtrl,
            maxLines: null,
            decoration: InputDecoration(
              hintText: 'Enter new text...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
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
              onPressed: () {
                final newText = editCtrl.text.trim();
                if (newText.isNotEmpty && newText != widget.message.text) {
                  widget.onEdit?.call(newText);
                }
                Navigator.of(ctx).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            'Delete Message?',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.bold,
              color: Colors.red[700],
            ),
          ),
          content: Text(
            'Are you sure you want to delete this message? This action cannot be undone.',
            style: GoogleFonts.inter(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: Colors.grey[500]),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[700],
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                widget.onDelete?.call();
                Navigator.of(ctx).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // ── Formatted file size ───────────────────────────────────────────────────

  static String _formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ── Open download URL ─────────────────────────────────────────────────────

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      // Fallback: copy to clipboard with a SnackBar.
      if (!mounted) return;
      await Clipboard.setData(ClipboardData(text: url));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Link copied to clipboard.',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: _navy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ── Full-screen image viewer ──────────────────────────────────────────────

  void _openImageViewer(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build helpers ─────────────────────────────────────────────────────────

  Widget _buildImageContent() {
    final url = widget.message.attachmentDownloadUrl;
    if (url == null || url.isEmpty) {
      return _buildMissingAttachmentText();
    }
    return GestureDetector(
      onTap: () => _openImageViewer(url),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(widget.isOwn ? 14 : 2),
          bottomRight: Radius.circular(widget.isOwn ? 2 : 14),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240, maxHeight: 320),
          child: Image.network(
            url,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, progress) {
              if (progress == null) return child;
              return Container(
                width: 240,
                height: 160,
                color: widget.isOwn
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF0C1D36),
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              width: 160,
              height: 80,
              alignment: Alignment.center,
              child: Icon(
                Icons.broken_image_rounded,
                color: widget.isOwn ? Colors.white54 : Colors.grey[400],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileContent() {
    final isOwn = widget.isOwn;
    final msg = widget.message;
    final fileName = msg.attachmentName ?? 'File';
    final sizeText = _formatSize(msg.attachmentSize);

    return GestureDetector(
      onTap: () => _openUrl(msg.attachmentDownloadUrl),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isOwn ? _ownBubbleBg : _otherBubbleBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isOwn ? 16 : 4),
            bottomRight: Radius.circular(isOwn ? 4 : 16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.insert_drive_file_rounded,
              color: isOwn ? Colors.white70 : Colors.grey[600],
              size: 20,
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: GoogleFonts.inter(
                      color: isOwn ? Colors.white : _navy,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  if (sizeText.isNotEmpty)
                    Text(
                      sizeText,
                      style: GoogleFonts.inter(
                        color: isOwn ? Colors.white54 : Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.download_rounded,
              color: isOwn ? Colors.white54 : Colors.grey[500],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingAttachmentText() {
    return Text(
      '[attachment]',
      style: GoogleFonts.inter(
        color: widget.isOwn ? Colors.white : _navy,
        fontSize: 14,
      ),
    );
  }

  Widget _buildBubbleContent() {
    final msg = widget.message;
    if (msg.expiresAt != null) {
      return _buildExpiringLinkContent();
    }
    switch (msg.type) {
      case MessageType.image:
        return _buildImageContent();
      case MessageType.file:
        return _buildFileContent();
      case MessageType.text:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isOwn ? _ownBubbleBg : _otherBubbleBg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(widget.isOwn ? 16 : 4),
              bottomRight: Radius.circular(widget.isOwn ? 4 : 16),
            ),
          ),
          child: Text(
            msg.text ?? '',
            style: GoogleFonts.inter(
              color: widget.isOwn ? Colors.white : _navy,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        );
    }
  }

  Widget _buildExpiringLinkContent() {
    final isOwn = widget.isOwn;
    final msg = widget.message;
    final isExpired = _timeLeft <= Duration.zero;
    final fileName = msg.attachmentName ?? 'Vault Document';
    final timerText = _formatDuration(_timeLeft);

    final Color cardBg = isOwn
        ? const Color(0xFF0C1D36)
        : const Color(0xFFF1F5F9);
    final Color textColor = isOwn ? Colors.white : const Color(0xFF0C1D36);
    final Color accentColor = isExpired
        ? Colors.red[400]!
        : const Color(0xFFCFA92A);
    final Color timerColor = isExpired
        ? Colors.red[400]!
        : (isOwn ? const Color(0xFFCFA92A) : const Color(0xFFB45309));

    return GestureDetector(
      onTap: isExpired ? null : () => _openUrl(msg.attachmentDownloadUrl),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isOwn ? 16 : 4),
            bottomRight: Radius.circular(isOwn ? 4 : 16),
          ),
          border: Border.all(
            color: isExpired
                ? (isOwn ? Colors.white24 : Colors.grey[300]!)
                : const Color(0xFFCFA92A).withValues(alpha: 0.5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  isExpired
                      ? Icons.lock_outline_rounded
                      : Icons.lock_clock_outlined,
                  color: accentColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isExpired ? 'Expired Secure Link' : 'Secure Expiring Link',
                    style: GoogleFonts.inter(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(color: Colors.grey, height: 16, thickness: 0.5),
            Text(
              fileName,
              style: GoogleFonts.inter(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isExpired
                    ? Colors.red[50]
                    : (isOwn
                          ? Colors.white.withValues(alpha: 0.1)
                          : const Color(0xFFFEF3C7)),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isExpired
                        ? Icons.error_outline_rounded
                        : Icons.timer_outlined,
                    color: isExpired ? Colors.red[600] : timerColor,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    timerText,
                    style: GoogleFonts.inter(
                      color: isExpired ? Colors.red[700] : timerColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            if (!isExpired) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Tap to Access',
                    style: GoogleFonts.inter(
                      color: isOwn
                          ? const Color(0xFFCFA92A)
                          : const Color(0xFF0C1D36),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: isOwn
                        ? const Color(0xFFCFA92A)
                        : const Color(0xFF0C1D36),
                    size: 14,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwn = widget.isOwn;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      child: Column(
        crossAxisAlignment: isOwn
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _showOptionsMenu(context),
            child: Row(
              mainAxisAlignment: isOwn
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  child: _buildBubbleContent(),
                ),
              ],
            ),
          ),
          if (_showTimestamp) ...[
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                _timeFmt.format(widget.message.createdAt.toLocal()),
                style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
