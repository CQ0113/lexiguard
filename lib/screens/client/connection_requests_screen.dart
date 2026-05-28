import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_model.dart';
import '../../repositories/connection_request_repository.dart';
import '../../widgets/lawyer_snapshot_card.dart';
import '../../widgets/lawyer_profile_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CONNECTION REQUESTS SCREEN — SCRUM-23
//
// Two-tab screen (Pending / History) where the client can review incoming
// lawyer expressions of interest, approve, or decline them.
// ─────────────────────────────────────────────────────────────────────────────

class ConnectionRequestsScreen extends StatefulWidget {
  const ConnectionRequestsScreen({
    super.key,
    required this.client,
    this.repository,
  });

  final UserModel client;
  final ConnectionRequestRepository? repository;

  @override
  State<ConnectionRequestsScreen> createState() =>
      _ConnectionRequestsScreenState();
}

class _ConnectionRequestsScreenState extends State<ConnectionRequestsScreen> {
  static const Color _navy = Color(0xFF0C1D36);
  static const Color _gold = Color(0xFFCFA92A);

  late final ConnectionRequestRepository _repo;

  @override
  void initState() {
    super.initState();
    _repo = widget.repository ?? ConnectionRequestRepository();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF2F2F7),
        appBar: AppBar(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          elevation: 0,
          title: Text(
            'Connection Requests',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          bottom: TabBar(
            labelColor: _gold,
            unselectedLabelColor: Colors.white54,
            indicatorColor: _gold,
            indicatorWeight: 2.5,
            labelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w400,
            ),
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _PendingTab(
              clientId: widget.client.id,
              client: widget.client,
              repo: _repo,
            ),
            _HistoryTab(clientId: widget.client.id, repo: _repo),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PENDING TAB
// ─────────────────────────────────────────────────────────────────────────────

class _PendingTab extends StatefulWidget {
  const _PendingTab({
    required this.clientId,
    required this.client,
    required this.repo,
  });

  final String clientId;
  final UserModel client;
  final ConnectionRequestRepository repo;

  @override
  State<_PendingTab> createState() => _PendingTabState();
}

class _PendingTabState extends State<_PendingTab> {
  // Incrementing this key forces StreamBuilder to re-subscribe on retry.
  int _streamKey = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectionRequestModel>>(
      key: ValueKey(_streamKey),
      stream: widget.repo.streamPendingForClient(widget.clientId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            message: snapshot.error.toString(),
            onRetry: () => setState(() => _streamKey++),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0C1D36)),
          );
        }

        final requests = snapshot.data ?? const [];

        if (requests.isEmpty) {
          return _EmptyState(
            icon: Icons.inbox_outlined,
            message: 'No pending requests',
            subtext: 'Lawyer expressions of interest will appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: requests.length,
          itemBuilder: (context, i) => _PendingRequestCard(
            request: requests[i],
            client: widget.client,
            repo: widget.repo,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY TAB
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.clientId, required this.repo});

  final String clientId;
  final ConnectionRequestRepository repo;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectionRequestModel>>(
      stream: repo.streamHistoryForClient(clientId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(message: snapshot.error.toString());
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0C1D36)),
          );
        }

        final requests = snapshot.data ?? const [];

        if (requests.isEmpty) {
          return _EmptyState(
            icon: Icons.history_outlined,
            message: 'No past requests',
            subtext:
                'Approved, declined and withdrawn requests will appear here.',
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: requests.length,
          itemBuilder: (context, i) =>
              _HistoryRequestCard(request: requests[i]),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PENDING REQUEST CARD
// ─────────────────────────────────────────────────────────────────────────────

class _PendingRequestCard extends StatefulWidget {
  const _PendingRequestCard({
    required this.request,
    required this.client,
    required this.repo,
  });

  final ConnectionRequestModel request;
  final UserModel client;
  final ConnectionRequestRepository repo;

  @override
  State<_PendingRequestCard> createState() => _PendingRequestCardState();
}

class _PendingRequestCardState extends State<_PendingRequestCard> {
  static const Color _navy = Color(0xFF0C1D36);
  static const Color _gold = Color(0xFFCFA92A);
  static const int _previewLength = 120;

  bool _expanded = false;
  bool _acting = false;

  @override
  Widget build(BuildContext context) {
    final req = widget.request;
    final snap = req.lawyerSnapshot;
    final shortRef = req.caseId.length >= 8
        ? req.caseId.substring(0, 8)
        : req.caseId;
    final messageShort = req.message.length > _previewLength;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Lawyer card (compact) ─────────────────────────────────────
            LawyerSnapshotCard(
              snapshot: snap,
              compact: true,
              onTap: () => LawyerProfileSheet.show(context, snapshot: snap),
            ),
            const SizedBox(height: 8),
            // ── Case reference ────────────────────────────────────────────
            Text(
              'Case reference: $shortRef…',
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 10),
            // ── Message preview ───────────────────────────────────────────
            Text(
              _expanded || !messageShort
                  ? req.message
                  : '${req.message.substring(0, _previewLength)}…',
              style: GoogleFonts.inter(color: _navy, fontSize: 13),
              maxLines: _expanded ? null : 2,
              overflow: _expanded ? null : TextOverflow.ellipsis,
            ),
            if (messageShort)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  _expanded ? 'Show less' : 'Read more',
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            // ── Action buttons ────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _acting
                      ? null
                      : () => LawyerProfileSheet.show(context, snapshot: snap),
                  child: Text(
                    'View profile',
                    style: GoogleFonts.inter(
                      color: _navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: _acting ? null : () => _confirmDecline(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade400),
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Decline',
                    style: GoogleFonts.inter(fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _acting ? null : () => _confirmApprove(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: _navy,
                    disabledBackgroundColor: Colors.grey[200],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: _acting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            color: Color(0xFF0C1D36),
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          'Approve',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Approve confirmation ──────────────────────────────────────────────────

  Future<void> _confirmApprove(BuildContext context) async {
    final lawyerName = widget.request.lawyerSnapshot.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Approve request',
          style: GoogleFonts.inter(
            color: const Color(0xFF0C1D36),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'By approving, $lawyerName will see your name, email, and phone. '
          "You'll both be able to message about this case. Continue?",
          style: GoogleFonts.inter(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCFA92A),
              foregroundColor: const Color(0xFF0C1D36),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Approve',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _doApprove(lawyerName);
  }

  Future<void> _doApprove(String lawyerName) async {
    setState(() => _acting = true);
    try {
      await widget.repo.approveRequest(
        requestId: widget.request.id,
        client: widget.client,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connected with $lawyerName.',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFF0C1D36),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not approve: ${e.toString()}',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      setState(() => _acting = false);
    }
  }

  // ── Decline bottom sheet ──────────────────────────────────────────────────

  Future<void> _confirmDecline(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeclineSheet(
        request: widget.request,
        repo: widget.repo,
        onDeclined: () {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Request declined.',
                style: GoogleFonts.inter(color: Colors.white),
              ),
              backgroundColor: Colors.grey[800],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
        onError: (msg) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
              backgroundColor: Colors.red[700],
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DECLINE SHEET
// ─────────────────────────────────────────────────────────────────────────────

class _DeclineSheet extends StatefulWidget {
  const _DeclineSheet({
    required this.request,
    required this.repo,
    required this.onDeclined,
    required this.onError,
  });

  final ConnectionRequestModel request;
  final ConnectionRequestRepository repo;
  final VoidCallback onDeclined;
  final void Function(String) onError;

  @override
  State<_DeclineSheet> createState() => _DeclineSheetState();
}

class _DeclineSheetState extends State<_DeclineSheet> {
  static const Color _navy = Color(0xFF0C1D36);

  static const _presets = [
    'Not a fit',
    'Already connected',
    'Out of budget',
    'Other',
  ];

  String _selected = 'Not a fit';
  final TextEditingController _otherCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  String get _reason =>
      _selected == 'Other' ? _otherCtrl.text.trim() : _selected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + bottomInset),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Decline request',
              style: GoogleFonts.inter(
                color: _navy,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Let us know why you\'re declining this request.',
              style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
            ),
            const SizedBox(height: 16),
            RadioGroup<String>(
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v!),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _presets
                    .map(
                      (preset) => RadioListTile<String>(
                        value: preset,
                        title: Text(
                          preset,
                          style: GoogleFonts.inter(color: _navy, fontSize: 14),
                        ),
                        activeColor: _navy,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                      ),
                    )
                    .toList(),
              ),
            ),
            if (_selected == 'Other') ...[
              const SizedBox(height: 8),
              TextField(
                controller: _otherCtrl,
                maxLength: 200,
                maxLines: 3,
                style: GoogleFonts.inter(color: _navy, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Describe your reason…',
                  hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[200],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Decline',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      await widget.repo.declineRequest(
        requestId: widget.request.id,
        reason: _reason.isNotEmpty ? _reason : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onDeclined();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onError('Could not decline: ${e.toString()}');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY REQUEST CARD
// ─────────────────────────────────────────────────────────────────────────────

class _HistoryRequestCard extends StatelessWidget {
  const _HistoryRequestCard({required this.request});

  final ConnectionRequestModel request;

  @override
  Widget build(BuildContext context) {
    final req = request;
    final snap = req.lawyerSnapshot;
    final shortRef = req.caseId.length >= 8
        ? req.caseId.substring(0, 8)
        : req.caseId;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Lawyer card (compact, tappable → profile sheet)
            LawyerSnapshotCard(
              snapshot: snap,
              compact: true,
              onTap: () => LawyerProfileSheet.show(context, snapshot: snap),
            ),
            const SizedBox(height: 8),
            // Case reference
            Text(
              'Case reference: $shortRef…',
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            // Message preview (2 lines)
            Text(
              req.message,
              style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            // Status pill (replaces action buttons)
            _buildStatusPill(req),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(ConnectionRequestModel req) {
    switch (req.status) {
      case ConnectionRequestStatus.approved:
        return _pill('Connected', Colors.green[700]!, Colors.green[50]!);

      case ConnectionRequestStatus.declined:
        if (req.declineReason == 'case_withdrawn') {
          return _pill('Case withdrawn', Colors.grey[600]!, Colors.grey[100]!);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _pill('Declined', Colors.grey[600]!, Colors.grey[100]!),
            if (req.declineReason != null && req.declineReason!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                req.declineReason!,
                style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11),
              ),
            ],
          ],
        );

      case ConnectionRequestStatus.withdrawn:
        return _pill(
          'Withdrawn by lawyer',
          Colors.grey[600]!,
          Colors.grey[100]!,
        );

      case ConnectionRequestStatus.expired:
        return _pill('Expired', Colors.grey[500]!, Colors.grey[100]!);

      case ConnectionRequestStatus.pending:
        // Shouldn't appear in history tab, but handle gracefully
        return _pill('Pending', Colors.orange[700]!, Colors.orange[50]!);
    }
  }

  Widget _pill(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED UTILITY WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.subtext,
  });

  final IconData icon;
  final String message;
  final String subtext;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              message,
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtext,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: GoogleFonts.inter(
                color: Colors.red[700],
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
