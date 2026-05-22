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
  });

  final ChatMessage message;
  final bool isOwn;

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  static const Color _navy = Color(0xFF0C1D36);
  static const Color _ownBubbleBg = Color(0xFF0C1D36);
  static const Color _otherBubbleBg = Color(0xFFF0F0F5);

  bool _showTimestamp = false;

  static final DateFormat _timeFmt = DateFormat('d MMM, h:mm a');

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    child: Icon(Icons.broken_image, color: Colors.white54, size: 48),
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

  @override
  Widget build(BuildContext context) {
    final isOwn = widget.isOwn;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 3),
      child: Column(
        crossAxisAlignment:
            isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => setState(() => _showTimestamp = !_showTimestamp),
            child: Row(
              mainAxisAlignment:
                  isOwn ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                style: GoogleFonts.inter(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
