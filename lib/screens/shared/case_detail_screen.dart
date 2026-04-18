import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/dummy_data.dart';
import '../../models/case_model.dart';
import '../../models/user_model.dart';

class CaseDetailScreen extends StatefulWidget {
  final CaseModel caseModel;
  final UserModel viewer; // the logged-in user viewing the case

  const CaseDetailScreen({
    super.key,
    required this.caseModel,
    required this.viewer,
  });

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  static const Color _navy = Color(0xFF0C1D36);
  static const Color _gold = Color(0xFFCFA92A);
  static const Color _bg = Color(0xFFF8FAFC);

  late CaseModel _case;
  bool _isLoadingInterest = false;

  @override
  void initState() {
    super.initState();
    _case = widget.caseModel;
  }

  bool get _isLawyer => widget.viewer.role == UserRole.lawyer;
  bool get _canLawyerExpressInterest =>
      _isLawyer && widget.viewer.canAccessMarketplace;
  bool get _hasExpressedInterest =>
      _case.interestedLawyerIds.contains(widget.viewer.id);

  // ── Express / withdraw interest ──────────────────────────────────────────
  Future<void> _toggleInterest() async {
    setState(() => _isLoadingInterest = true);
    await Future.delayed(const Duration(milliseconds: 900));

    final updatedIds = List<String>.from(_case.interestedLawyerIds);
    if (_hasExpressedInterest) {
      updatedIds.remove(widget.viewer.id);
    } else {
      updatedIds.add(widget.viewer.id);
    }

    // Rebuild the case with the updated list
    final updated = CaseModel(
      id: _case.id,
      clientId: _case.clientId,
      lawyerId: _case.lawyerId,
      title: _case.title,
      description: _case.description,
      category: _case.category,
      status: _case.status,
      urgency: _case.urgency,
      progressPercent: _case.progressPercent,
      nextHearing: _case.nextHearing,
      createdAt: _case.createdAt,
      interestedLawyerIds: updatedIds,
    );

    // Persist into global dummy store
    final idx = DummyData.openCases.indexWhere((c) => c.id == _case.id);
    if (idx != -1) DummyData.openCases[idx] = updated;

    if (mounted) {
      setState(() {
        _case = updated;
        _isLoadingInterest = false;
      });
      if (!_hasExpressedInterest) {
        // hasExpressedInterest is checked BEFORE re-assignment above,
        // so if we just expressed interest, show confirmation
      }
      _showSnack(
        _hasExpressedInterest
            ? 'Interest withdrawn.'
            : '✓ Interest expressed! The client will be notified.',
        _hasExpressedInterest ? Colors.grey : const Color(0xFF2E7D32),
      );
    }
  }

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

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
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
                  if (_isLawyer) _buildInterestedLawyersSection(),
                  if (!_isLawyer) _buildInterestedLawyersSection(),
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
      floatingActionButton:
          _canLawyerExpressInterest && _case.status == CaseStatus.pending
          ? _buildInterestFAB()
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
              'Verification is still pending. Express interest will be enabled after your lawyer account is approved.',
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
    final clientUser = DummyData.users.firstWhere(
      (u) => u.id == _case.clientId,
      orElse: () => DummyData.users.first,
    );
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.info_outline, 'Case Information'),
          const SizedBox(height: 16),
          _detailRow(Icons.person_outline, 'Client', clientUser.name),
          _divider(),
          _detailRow(Icons.label_outline, 'Category', _case.categoryLabel),
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
              DummyData.users
                  .firstWhere(
                    (u) => u.id == _case.lawyerId,
                    orElse: () => DummyData.users.first,
                  )
                  .name,
              valueColor: const Color(0xFF2E7D32),
            ),
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

  // ── Express Interest FAB ─────────────────────────────────────────────────
  Widget _buildInterestFAB() {
    final expressed = _hasExpressedInterest;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _isLoadingInterest ? null : _toggleInterest,
          icon: _isLoadingInterest
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Icon(
                  expressed
                      ? Icons.handshake_outlined
                      : Icons.handshake_outlined,
                  size: 20,
                ),
          label: Text(
            expressed ? 'Withdraw Interest' : 'Express Interest',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: expressed ? Colors.grey[700] : _navy,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: expressed ? 0 : 4,
            shadowColor: _navy.withValues(alpha: 0.4),
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
          Text(
            value,
            style: GoogleFonts.inter(
              color: valueColor ?? _navy,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() =>
      Divider(color: Colors.grey[100], height: 1, thickness: 1);

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
