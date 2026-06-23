import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LEXIBOT DRAFT PANEL — SCRUM-17 Step 7
//
// A bottom-sheet assistant that calls the `generateLegalChatResponse`
// Cloud Function, shows the AI-generated answer + source chips, and lets
// the user copy, insert into the composer, or dismiss — without ever writing
// a message to Firestore automatically.
// ─────────────────────────────────────────────────────────────────────────────

/// Opens the LexiBot draft sheet and returns the answer text if the user
/// taps "Insert into composer", or `null` if they dismiss.
///
/// [callableOverride] is an optional testability seam — pass a fake async
/// function in widget tests instead of hitting Firebase Functions.
Future<String?> showLexiBotDraft(
  BuildContext context, {
  required String roomId,
  String? seedQuestion,
  String? attachmentStoragePath,
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)? callableOverride,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LexiBotPanel(
      roomId: roomId,
      seedQuestion: seedQuestion,
      attachmentStoragePath: attachmentStoragePath,
      callableOverride: callableOverride,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// PANEL WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _LexiBotPanel extends StatefulWidget {
  const _LexiBotPanel({
    required this.roomId,
    this.seedQuestion,
    this.attachmentStoragePath,
    this.callableOverride,
  });

  final String roomId;
  final String? seedQuestion;
  final String? attachmentStoragePath;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic>)?
      callableOverride;

  @override
  State<_LexiBotPanel> createState() => _LexiBotPanelState();
}

class _LexiBotPanelState extends State<_LexiBotPanel> {
  static const Color _navy = Color(0xFF0C1D36);
  static const Color _gold = Color(0xFFCFA92A);

  late final TextEditingController _questionCtrl;

  bool _loading = false;
  String? _answer;
  List<_Source> _sources = const [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _questionCtrl = TextEditingController(text: widget.seedQuestion ?? '');
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    super.dispose();
  }

  // ── Callable invocation ───────────────────────────────────────────────────

  Future<void> _submit() async {
    final question = _questionCtrl.text.trim();

    if (question.isEmpty) {
      setState(() {
        _errorMessage = 'Please type a question first.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _answer = null;
      _sources = const [];
    });

    try {
      final payload = <String, dynamic>{
        'question': question,
        'roomId': widget.roomId,
        if (widget.attachmentStoragePath != null)
          'attachmentStoragePath': widget.attachmentStoragePath,
      };

      final Map<String, dynamic> data;
      if (widget.callableOverride != null) {
        data = await widget.callableOverride!(payload);
      } else {
        final result = await FirebaseFunctions.instance
            .httpsCallable('generateLegalChatResponse')
            .call(payload);
        final raw = result.data as Map<Object?, Object?>;
        data = raw.map((k, v) => MapEntry(k.toString(), v));
      }

      final answer = data['answer'] as String? ?? '';
      final rawSources = data['sources'];
      final sources = <_Source>[];
      if (rawSources is List) {
        for (final s in rawSources) {
          if (s is Map) {
            sources.add(
              _Source(
                actName: (s['actName'] as String?) ?? '',
                sectionNo: (s['sectionNo'] as String?) ?? '',
                sourceUrl: (s['sourceUrl'] as String?) ?? '',
              ),
            );
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _answer = answer;
        _sources = sources;
        _loading = false;
      });
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _mapFunctionsError(e);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'LexiBot is temporarily unavailable. Try again.';
        _loading = false;
      });
    }
  }

  String _mapFunctionsError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Please sign in again to use LexiBot.';
      case 'permission-denied':
        return "You don't have access to this conversation.";
      case 'not-found':
        return 'This conversation could not be found.';
      case 'invalid-argument':
        return 'Please type a question first.';
      case 'internal':
        final msg = e.message;
        if (msg != null && msg.isNotEmpty) return msg;
        return 'LexiBot is temporarily unavailable. Try again.';
      default:
        return 'LexiBot is temporarily unavailable. Try again.';
    }
  }

  Future<void> _openSource(String url) async {
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ────────────────────────────────────────────────
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── AI Header card ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0C1D36), Color(0xFF163354)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _gold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _gold.withValues(alpha: 0.4),
                            ),
                          ),
                          child: const Icon(
                            Icons.smart_toy_rounded,
                            color: _gold,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'LexiBot',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'AI Malaysian Law Assistant',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Colors.amber[400],
                            size: 13,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'General information only — not formal legal advice. '
                              'Consult a qualified lawyer.',
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                fontStyle: FontStyle.italic,
                                color: Colors.amber[300],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Question input row ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 100),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: TextField(
                        controller: _questionCtrl,
                        maxLines: null,
                        minLines: 1,
                        enabled: !_loading,
                        keyboardType: TextInputType.multiline,
                        textCapitalization: TextCapitalization.sentences,
                        style: GoogleFonts.inter(
                          color: _navy,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask a question about Malaysian law…',
                          hintStyle: GoogleFonts.inter(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: _loading ? Colors.grey[200] : _navy,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _loading ? null : _submit,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: _loading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Thinking indicator ─────────────────────────────────────────
            if (_loading) ...[
              const SizedBox(height: 14),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: _ThinkingIndicator(),
              ),
            ],

            // ── Inline error ───────────────────────────────────────────────
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.red[600],
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: GoogleFonts.inter(
                            color: Colors.red[700],
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // ── Answer area ────────────────────────────────────────────────
            if (_answer != null) ...[
              const SizedBox(height: 12),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 220),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE8EDF2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Gold accent bar
                        Container(
                          width: 3,
                          decoration: const BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              _answer!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: _navy,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Sources ──────────────────────────────────────────────────
              if (_sources.isNotEmpty) ...[
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sources',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: _sources.map((s) {
                          final label = [s.actName, s.sectionNo]
                              .where((p) => p.isNotEmpty)
                              .join(' ');
                          return ActionChip(
                            label: Text(
                              label.isNotEmpty ? label : 'Source',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _navy,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            backgroundColor: const Color(0xFFF0F4FA),
                            side: const BorderSide(color: Color(0xFFD0DAE8)),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 0,
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: s.sourceUrl.isNotEmpty
                                ? () => _openSource(s.sourceUrl)
                                : null,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ],

            const SizedBox(height: 16),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF0F0F5)),

            // ── Action buttons ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(null),
                    child: Text(
                      'Cancel',
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (_answer != null) ...[
                    OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: Text(
                        'Copy',
                        style: GoogleFonts.inter(fontSize: 13),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: const BorderSide(color: Color(0xFF0C1D36)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        await Clipboard.setData(
                          ClipboardData(text: _answer!),
                        );
                        if (!mounted) return;
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              'Copied to clipboard.',
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
                      },
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: Text(
                          'Insert into composer',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(_answer),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANIMATED THINKING INDICATOR
// ─────────────────────────────────────────────────────────────────────────────

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.smart_toy_rounded, color: Color(0xFFCFA92A), size: 14),
        const SizedBox(width: 8),
        Text(
          'Searching Malaysian law',
          style: GoogleFonts.inter(
            fontSize: 12,
            color: Colors.grey[500],
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 2),
        AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                // Each dot peaks 0.33s apart
                final phase = ((_ctrl.value - i / 3.0) % 1.0);
                final opacity = (1.0 - (phase * 2 - 1.0).abs()).clamp(0.2, 1.0);
                return Opacity(
                  opacity: opacity,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      '.',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        color: const Color(0xFFCFA92A),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DATA
// ─────────────────────────────────────────────────────────────────────────────

class _Source {
  const _Source({
    required this.actName,
    required this.sectionNo,
    required this.sourceUrl,
  });

  final String actName;
  final String sectionNo;
  final String sourceUrl;
}
