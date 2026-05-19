import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/dummy_data.dart';
import '../../models/case_model.dart';
import '../../models/user_model.dart';
import '../../repositories/connection_request_repository.dart';
import '../../widgets/express_interest_sheet.dart';

class CaseDetailScreen extends StatefulWidget {
  final CaseModel caseModel;
  final UserModel viewer; // the logged-in user viewing the case

  /// Optional: inject a [ConnectionRequestRepository] (e.g. for testing
  /// without a live Firebase). Defaults to a new instance for lawyer viewers.
  final ConnectionRequestRepository? repository;

  const CaseDetailScreen({
    super.key,
    required this.caseModel,
    required this.viewer,
    this.repository,
  });

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  static const Color _navy = Color(0xFF0C1D36);
  static const Color _gold = Color(0xFFCFA92A);
  static const Color _bg = Color(0xFFF8FAFC);

  late CaseModel _case;

  // Lazily created only for lawyer viewers so the widget can be constructed
  // in tests without a live Firebase connection.
  ConnectionRequestRepository? _repoInstance;
  ConnectionRequestRepository get _repo =>
      _repoInstance ??= widget.repository ?? ConnectionRequestRepository();

  @override
  void initState() {
    super.initState();
    _case = widget.caseModel;
  }

  bool get _isLawyer => widget.viewer.role == UserRole.lawyer;

  UserModel _resolveClientUser() {
    try {
      return DummyData.users.firstWhere((u) => u.id == _case.clientId);
    } catch (_) {
      if (widget.viewer.role == UserRole.client &&
          widget.viewer.id == _case.clientId) {
        return widget.viewer;
      }
      return DummyData.users.first;
    }
  }

  String _assignedLawyerLabel() {
    final lawyerId = _case.lawyerId;
    if (lawyerId == null || lawyerId.isEmpty) {
      return 'Awaiting assignment';
    }

    try {
      return DummyData.users.firstWhere((u) => u.id == lawyerId).name;
    } catch (_) {
      return 'Assigned lawyer';
    }
  }

  // ── Snackbar helper ──────────────────────────────────────────────────────
  void _showSnack(String msg, Color bg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Withdraw confirmation dialog ─────────────────────────────────────────
  Future<void> _confirmWithdraw(String requestId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Withdraw interest?',
          style: GoogleFonts.inter(
            color: const Color(0xFF0C1D36),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Withdraw your expression of interest? You can re-send later if you change your mind.',
          style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Withdraw',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repo.withdrawRequest(requestId);
        if (mounted) {
          _showSnack('Interest withdrawn.', Colors.grey[700]!);
        }
      } catch (e) {
        if (mounted) {
          _showSnack('Could not withdraw. Please try again.', Colors.redAccent);
        }
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Only subscribe to the request stream for verified lawyers — clients and
    // unverified lawyers don't need it (unverified see a disabled button,
    // clients have no EOI surface at all).
    final requestStream = (_isLawyer && widget.viewer.canAccessMarketplace)
        ? _repo.watchRequest(
            caseId: _case.id,
            lawyerId: widget.viewer.id,
          )
        : null;

    return Scaffold(
      backgroundColor: _bg,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusRow(),
                  if (_isLawyer && !widget.viewer.canAccessMarketplace)
                    const SizedBox(height: 14),
                  if (_isLawyer && !widget.viewer.canAccessMarketplace)
                    _buildVerificationLockNotice(),
                  const SizedBox(height: 20),
                  _buildDescriptionCard(),
                  const SizedBox(height: 20),
                  _buildDetailsCard(),
                  const SizedBox(height: 20),
                  if (_case.attachments.isNotEmpty) _buildAttachmentsCard(),
                  if (_case.attachments.isNotEmpty) const SizedBox(height: 20),
                  _buildInterestedLawyersSection(),
                  const SizedBox(height: 20),
                  if (_case.progressPercent > 0) _buildProgressCard(),
                  if (_case.progressPercent > 0) const SizedBox(height: 20),
                  const SizedBox(height: 80), // space for FAB
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _isLawyer
          ? (requestStream != null
              ? StreamBuilder<ConnectionRequestModel?>(
                  stream: requestStream,
                  builder: (ctx, snapshot) {
                    final request = snapshot.data;
                    return _buildLawyerFAB(request);
                  },
                )
              : _buildLawyerFAB(null))
          : null,
    );
  }

  Widget _buildVerificationLockNotice() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline, color: Color(0xFFD97706), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _lockMessageForStatus(widget.viewer.verificationStatus),
              style: GoogleFonts.inter(
                color: const Color(0xFF92400E),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _lockMessageForStatus(VerificationStatus status) {
    switch (status) {
      case VerificationStatus.pending:
        return 'Verification is still pending. Express interest will be enabled after your lawyer account is approved.';
      case VerificationStatus.manualReviewRequired:
        return 'Your submission is under manual review. Express interest will unlock once the review is completed.';
      case VerificationStatus.rejected:
        return 'Your verification was rejected. Update your legal details and resubmit to regain case marketplace access.';
      case VerificationStatus.reverificationDue:
        return 'Reverification is required before you can express interest in new cases.';
      case VerificationStatus.suspended:
        return 'Your lawyer account is currently suspended. Contact support to restore marketplace access.';
      case VerificationStatus.unsubmitted:
        return 'Complete verification to unlock case marketplace actions.';
      case VerificationStatus.autoVerified:
        return 'Your account is verified.';
    }
  }

  // ── Sliver AppBar (hero) ─────────────────────────────────────────────────
  Widget _buildSliverAppBar() {
    final urgencyColor = _urgencyColor(_case.urgency);
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: _navy,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 18,
        ),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.share_outlined, color: Colors.white),
          onPressed: () {},
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0C1D36), Color(0xFF1A3560)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      _chip(
                        _case.categoryLabel,
                        _categoryColor(_case.category),
                      ),
                      const SizedBox(width: 8),
                      _chip(_case.urgencyLabel, urgencyColor),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _case.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_outlined,
                        color: Colors.white54,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Posted ${_timeAgo(_case.createdAt)}',
                        style: GoogleFonts.inter(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Status Row ───────────────────────────────────────────────────────────
  Widget _buildStatusRow() {
    return Row(
      children: [
        _statusPill(_case.status),
        const Spacer(),
        if (_case.interestedLawyerIds.isNotEmpty)
          Row(
            children: [
              const Icon(
                Icons.group_outlined,
                color: Color(0xFFCFA92A),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${_case.interestedLawyerIds.length} lawyer${_case.interestedLawyerIds.length > 1 ? 's' : ''} interested',
                style: GoogleFonts.inter(
                  color: _gold,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ],
          ),
      ],
    );
  }

  // ── Description Card ─────────────────────────────────────────────────────
  Widget _buildDescriptionCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.description_outlined, 'Case Description'),
          const SizedBox(height: 12),
          Text(
            _case.description,
            style: GoogleFonts.inter(
              color: Colors.grey[700],
              fontSize: 14,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }

  // ── Details Card ─────────────────────────────────────────────────────────
  Widget _buildDetailsCard() {
    final clientUser = _resolveClientUser();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.info_outline, 'Case Information'),
          const SizedBox(height: 16),
          _detailRow(Icons.person_outline, 'Client', clientUser.name),
          _divider(),
          _detailRow(Icons.label_outline, 'Category', _case.categoryLabel),
          if (_case.location != null && _case.location!.isNotEmpty) ...[
            _divider(),
            _detailRow(Icons.location_on_outlined, 'Location', _case.location!),
          ],
          if (_case.budgetRange != null && _case.budgetRange!.isNotEmpty) ...[
            _divider(),
            _detailRow(
              Icons.payments_outlined,
              'Budget',
              _case.budgetRange!,
            ),
          ],
          _divider(),
          _detailRow(
            Icons.calendar_today_outlined,
            'Filed On',
            DateFormat('d MMMM yyyy').format(_case.createdAt),
          ),
          if (_case.nextHearing != null) ...[
            _divider(),
            _detailRow(
              Icons.event_available_outlined,
              'Next Hearing',
              DateFormat('d MMMM yyyy  •  hh:mm a').format(_case.nextHearing!),
              valueColor: Colors.redAccent,
            ),
          ],
          if (_case.lawyerId != null) ...[
            _divider(),
            _detailRow(
              Icons.balance_outlined,
              'Assigned Lawyer',
              _assignedLawyerLabel(),
              valueColor: const Color(0xFF2E7D32),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAttachmentsCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.attach_file, 'Attachments'),
          const SizedBox(height: 12),
          for (final attachment in _case.attachments) ...[
            Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: _navy,
                  size: 16,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    attachment.fileName,
                    style: GoogleFonts.inter(
                      color: Colors.grey[700],
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  _formatFileSize(attachment.sizeBytes),
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (attachment != _case.attachments.last) _divider(),
          ],
        ],
      ),
    );
  }

  // ── Interested Lawyers ───────────────────────────────────────────────────
  Widget _buildInterestedLawyersSection() {
    final interested = DummyData.users
        .where((u) => _case.interestedLawyerIds.contains(u.id))
        .toList();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.group_outlined, 'Interested Lawyers'),
          const SizedBox(height: 12),
          if (interested.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.hourglass_empty,
                    color: Colors.grey[300],
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'No lawyers have expressed interest yet.',
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            ...interested.map((lawyer) => _lawyerTile(lawyer)),
        ],
      ),
    );
  }

  Widget _lawyerTile(UserModel lawyer) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _gold, width: 1.5),
              image: lawyer.avatarUrl != null
                  ? DecorationImage(
                      image: NetworkImage(lawyer.avatarUrl!),
                      fit: BoxFit.cover,
                    )
                  : null,
              color: _navy,
            ),
            child: lawyer.avatarUrl == null
                ? Center(
                    child: Text(
                      lawyer.name[0],
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lawyer.name,
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  lawyer.specialization ?? 'Legal Practitioner',
                  style: GoogleFonts.inter(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: lawyer.isVerified
                        ? const Color(0xFFF0FDF4)
                        : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: lawyer.isVerified
                          ? const Color(0xFFBBF7D0)
                          : const Color(0xFFFDE68A),
                    ),
                  ),
                  child: Text(
                    lawyer.isVerified
                        ? 'Verified'
                        : lawyer.verificationStatus.label,
                    style: GoogleFonts.inter(
                      color: lawyer.isVerified
                          ? const Color(0xFF15803D)
                          : const Color(0xFFD97706),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Stars
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFCFA92A),
                    size: 14,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${lawyer.rating ?? '-'}',
                    style: GoogleFonts.inter(
                      color: _navy,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              // If viewer is client, show hire button
              if (!_isLawyer)
                GestureDetector(
                  onTap: () {},
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _navy,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Hire',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Progress Card ────────────────────────────────────────────────────────
  Widget _buildProgressCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.timeline_outlined, 'Case Progress'),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _case.progressPercent / 100,
                    backgroundColor: Colors.grey[100],
                    color: _navy,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_case.progressPercent.toInt()}%',
                style: GoogleFonts.inter(
                  color: _navy,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Lawyer EOI FAB — state machine ───────────────────────────────────────
  //
  // State table (viewer is always a lawyer here):
  //
  //  Lawyer not verified               → disabled "Verify to send requests"
  //  Case assigned to another lawyer   → disabled "Case assigned to another lawyer"
  //  Case assigned to THIS lawyer      → "Connected" pill (green, no-op)
  //  No request OR withdrawn/expired   → gold "Express Interest" → opens sheet
  //  Pending request                   → "Pending review" + "Withdraw" secondary
  //  Declined request                  → disabled "Request declined"
  //  Approved request                  → "Connected" pill (treat same as assigned)
  //
  Widget _buildLawyerFAB(ConnectionRequestModel? request) {
    // Guard: not verified
    if (!widget.viewer.canAccessMarketplace) {
      return _fab(
        label: 'Verify to send requests',
        icon: Icons.lock_outline,
        bg: Colors.grey[300]!,
        fg: Colors.grey[600]!,
        onPressed: null,
      );
    }

    // Guard: case assigned to another lawyer
    final assignedLawyerId = _case.lawyerId;
    if (assignedLawyerId != null &&
        assignedLawyerId.isNotEmpty &&
        assignedLawyerId != widget.viewer.id) {
      return _fab(
        label: 'Case assigned to another lawyer',
        icon: Icons.info_outline,
        bg: Colors.grey[200]!,
        fg: Colors.grey[500]!,
        onPressed: null,
      );
    }

    // Connected (assigned to self OR request approved)
    if ((assignedLawyerId != null && assignedLawyerId == widget.viewer.id) ||
        request?.status == ConnectionRequestStatus.approved) {
      return _fab(
        label: 'Connected',
        icon: Icons.check_circle_outline,
        bg: const Color(0xFF2E7D32),
        fg: Colors.white,
        onPressed: null, // future: open chat
      );
    }

    // Declined — terminal, no re-send
    if (request?.status == ConnectionRequestStatus.declined) {
      return _fab(
        label: 'Request declined',
        icon: Icons.cancel_outlined,
        bg: Colors.grey[200]!,
        fg: Colors.grey[500]!,
        onPressed: null,
      );
    }

    // Pending — show "Pending review" + Withdraw secondary
    if (request?.status == ConnectionRequestStatus.pending) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: null, // no primary action while pending
                icon: const Icon(Icons.hourglass_empty, size: 18),
                label: Text(
                  'Pending review',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.grey[600],
                  disabledBackgroundColor: Colors.grey[200],
                  disabledForegroundColor: Colors.grey[600],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => _confirmWithdraw(request!.id),
              child: Text(
                'Withdraw',
                style: GoogleFonts.inter(
                  color: Colors.redAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // No request, or withdrawn/expired — show primary "Express Interest" CTA
    // Also only show for pending cases (seeking lawyer)
    if (_case.status != CaseStatus.pending) {
      return const SizedBox.shrink();
    }

    return _fab(
      label: 'Express Interest',
      icon: Icons.handshake_outlined,
      bg: _gold,
      fg: _navy,
      onPressed: () async {
        await ExpressInterestSheet.show(
          context,
          targetCase: _case,
          lawyer: widget.viewer,
          repository: _repo,
        );
        // Stream automatically updates FAB state — no setState needed.
      },
    );
  }

  Widget _fab({
    required String label,
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback? onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: bg,
            disabledForegroundColor: fg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: onPressed != null ? 2 : 0,
            shadowColor: _navy.withValues(alpha: 0.2),
          ),
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────
  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: _navy, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.inter(
            color: _navy,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey[400], size: 16),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                color: valueColor ?? _navy,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(color: Colors.grey[100], height: 1, thickness: 1);

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusPill(CaseStatus status) {
    Color color;
    String label;
    IconData icon;
    switch (status) {
      case CaseStatus.active:
        color = const Color(0xFF2E7D32);
        label = 'Active';
        icon = Icons.play_circle_outline;
        break;
      case CaseStatus.pending:
        color = Colors.orange;
        label = 'Open — Seeking Lawyer';
        icon = Icons.hourglass_empty;
        break;
      case CaseStatus.closed:
        color = Colors.grey;
        label = 'Closed';
        icon = Icons.check_circle_outline;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Color _urgencyColor(CaseUrgency u) {
    switch (u) {
      case CaseUrgency.high:
        return Colors.redAccent;
      case CaseUrgency.medium:
        return Colors.orange;
      case CaseUrgency.low:
        return const Color(0xFF2E7D32);
    }
  }

  Color _categoryColor(CaseCategory c) {
    switch (c) {
      case CaseCategory.property:
        return const Color(0xFF1565C0);
      case CaseCategory.family:
        return const Color(0xFFAD1457);
      case CaseCategory.criminal:
        return const Color(0xFFB71C1C);
      case CaseCategory.commercial:
        return const Color(0xFF00695C);
      case CaseCategory.employment:
        return const Color(0xFF6A1B9A);
      case CaseCategory.other:
        return const Color(0xFF546E7A);
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
