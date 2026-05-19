import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/case_model.dart';
import '../models/user_model.dart';
import '../repositories/connection_request_repository.dart';
import 'lawyer_snapshot_card.dart';

/// Bottom sheet that lets a verified lawyer compose and send an Expression of
/// Interest (EOI) for a posted client case.
///
/// Usage:
/// ```dart
/// final sent = await ExpressInterestSheet.show(
///   context,
///   targetCase: theCase,
///   lawyer: widget.viewer,
/// );
/// if (sent == true) { /* CTA rebuilds via StreamBuilder */ }
/// ```
class ExpressInterestSheet extends StatefulWidget {
  const ExpressInterestSheet._({
    required this.targetCase,
    required this.lawyer,
    required this.repository,
  });

  final CaseModel targetCase;
  final UserModel lawyer;
  final ConnectionRequestRepository repository;

  // ── Public entry-point ────────────────────────────────────────────────────

  /// Opens the bottom sheet. Returns `true` if the request was sent
  /// successfully, `false` / `null` otherwise.
  static Future<bool> show(
    BuildContext context, {
    required CaseModel targetCase,
    required UserModel lawyer,
    ConnectionRequestRepository? repository,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ExpressInterestSheet._(
        targetCase: targetCase,
        lawyer: lawyer,
        repository: repository ?? ConnectionRequestRepository(),
      ),
    );
    return result ?? false;
  }

  @override
  State<ExpressInterestSheet> createState() => _ExpressInterestSheetState();
}

class _ExpressInterestSheetState extends State<ExpressInterestSheet> {
  // ── Design tokens ─────────────────────────────────────────────────────────
  static const Color _navy = Color(0xFF0C1D36);
  static const Color _errorRed = Color(0xFFDC2626);
  static const Color _borderGrey = Color(0xFFE5E7EB);

  // ── State ─────────────────────────────────────────────────────────────────
  final TextEditingController _msgCtrl = TextEditingController();
  bool _sending = false;
  String? _errorText;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  // ── Send logic ────────────────────────────────────────────────────────────

  bool get _canSend {
    final len = _msgCtrl.text.trim().length;
    return !_sending && len >= 50 && len <= 500;
  }

  Future<void> _send() async {
    if (!_canSend) return;

    setState(() {
      _sending = true;
      _errorText = null;
    });

    try {
      await widget.repository.sendRequest(
        targetCase: widget.targetCase,
        lawyer: widget.lawyer,
        message: _msgCtrl.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Expression of interest sent.',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: _navy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );

      Navigator.of(context).pop(true);
    } on DuplicateRequestException {
      setState(() {
        _errorText = 'You already have an open request on this case.';
        _sending = false;
      });
    } on RequestDeclinedException {
      setState(() {
        _errorText = 'This client has previously declined your request.';
        _sending = false;
      });
    } on CaseAlreadyConnectedException {
      setState(() {
        _errorText = 'This case has just been connected to another lawyer.';
        _sending = false;
      });
    } on LawyerNotVerifiedException {
      setState(() {
        _errorText = 'Complete verification to send requests.';
        _sending = false;
      });
    } on MessageLengthException {
      setState(() {
        _errorText = 'Message must be between 50 and 500 characters.';
        _sending = false;
      });
    } catch (e) {
      setState(() {
        _errorText = kDebugMode
            ? 'Something went wrong. Please try again.\n$e'
            : 'Something went wrong. Please try again.';
        _sending = false;
      });
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDragHandle(),
            const SizedBox(height: 16),
            _buildTitle(),
            const SizedBox(height: 16),
            _buildCaseSummaryChip(),
            const SizedBox(height: 20),
            _buildLawyerCard(),
            const SizedBox(height: 20),
            _buildMessageField(),
            if (_errorText != null) ...[
              const SizedBox(height: 8),
              _buildErrorBanner(),
            ],
            const SizedBox(height: 20),
            _buildSendButton(),
            const SizedBox(height: 12),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ── Drag handle ───────────────────────────────────────────────────────────

  Widget _buildDragHandle() {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ── Title ─────────────────────────────────────────────────────────────────

  Widget _buildTitle() {
    return Text(
      'Send Expression of Interest',
      style: GoogleFonts.inter(
        color: _navy,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  // ── Case summary chip ─────────────────────────────────────────────────────

  Widget _buildCaseSummaryChip() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _borderGrey),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.targetCase.title,
              style: GoogleFonts.inter(
                color: _navy,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          _categoryBadge(widget.targetCase.categoryLabel),
        ],
      ),
    );
  }

  Widget _categoryBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _navy.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: _navy,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ── Lawyer card preview ───────────────────────────────────────────────────

  Widget _buildLawyerCard() {
    final snapshot = LawyerSnapshot.fromUser(widget.lawyer);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your card — what the client will see',
            style: GoogleFonts.inter(
              color: Colors.grey[500],
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          LawyerSnapshotCard(snapshot: snapshot),
        ],
      ),
    );
  }

  // ── Message TextField ─────────────────────────────────────────────────────

  Widget _buildMessageField() {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _msgCtrl,
      builder: (context2, value, child2) {
        final length = value.text.trim().length;
        final charCountColor = length < 50 ? _errorRed : Colors.grey[400]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextField(
              controller: _msgCtrl,
              maxLines: 4,
              maxLength: 500,
              buildCounter: (_,
                  {required currentLength,
                  required isFocused,
                  required maxLength}) =>
                  null, // hide built-in counter; we show our own below
              style: GoogleFonts.inter(color: _navy, fontSize: 14),
              decoration: InputDecoration(
                labelText: 'Initial message',
                labelStyle: GoogleFonts.inter(color: Colors.grey[500]),
                helperText:
                    'Do not share contact info — your identity is hidden until the client approves.',
                helperStyle: GoogleFonts.inter(
                  color: _errorRed.withValues(alpha: 0.85),
                  fontSize: 11,
                ),
                helperMaxLines: 2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _borderGrey),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _borderGrey),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: _navy.withValues(alpha: 0.6)),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$length/500',
              style: GoogleFonts.inter(
                color: charCountColor,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        );
      },
    );
  }

  // ── Error banner ──────────────────────────────────────────────────────────

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _errorRed.withValues(alpha: 0.25)),
      ),
      child: Text(
        _errorText!,
        style: GoogleFonts.inter(
          color: _errorRed,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  // ── Send button ───────────────────────────────────────────────────────────

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: _msgCtrl,
        builder: (context2, value, child2) {
          final len = value.text.trim().length;
          final enabled = !_sending && len >= 50 && len <= 500;
          return ElevatedButton(
            onPressed: enabled ? _send : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[200],
              disabledForegroundColor: Colors.grey[400],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            child: _sending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Text(
                    'Send Expression of Interest',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
          );
        },
      ),
    );
  }

  // ── Footer ────────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Center(
      child: Text(
        'By sending, you agree to engage professionally per Bar standards.',
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          color: Colors.grey[400],
          fontSize: 11,
        ),
      ),
    );
  }
}
