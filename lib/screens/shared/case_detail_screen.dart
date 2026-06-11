import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/firebase/firebase_initializer.dart';
import '../../data/dummy_data.dart';
import '../../models/case_model.dart';
import '../../models/user_model.dart';
import '../../repositories/case_action_repository.dart';
import '../../repositories/case_repository.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/connection_request_repository.dart';
import '../../widgets/express_interest_sheet.dart';
import '../chat/chat_room_screen.dart';
import '../../widgets/lawyer_profile_sheet.dart';
import '../../services/case_matching_service.dart';

class CaseDetailScreen extends StatefulWidget {
  final CaseModel caseModel;
  final UserModel viewer; // the logged-in user viewing the case

  /// Optional: inject a [ConnectionRequestRepository] (e.g. for testing
  /// without a live Firebase). Defaults to a new instance for lawyer viewers.
  final ConnectionRequestRepository? repository;

  /// Optional: inject a [CaseActionHandler] (e.g. for testing).
  final CaseActionHandler? actionHandler;

  /// Optional: inject a [CaseRepository] (e.g. for testing with fake Firestore).
  final CaseRepository? caseRepository;

  /// When false, the screen renders from [caseModel] only (widget tests).
  final bool subscribeToLiveUpdates;

  final MatchResult? matchResult;

  const CaseDetailScreen({
    super.key,
    required this.caseModel,
    required this.viewer,
    this.repository,
    this.actionHandler,
    this.caseRepository,
    this.subscribeToLiveUpdates = true,
    this.matchResult,
  });

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  static const Color _navy = Color(0xFF0C1D36);
  static const Color _gold = Color(0xFFCFA92A);
  static const Color _bg = Color(0xFFF8FAFC);

  bool get _isTest => !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');

  late CaseModel _case;

  // Lazily created only for lawyer viewers so the widget can be constructed
  // in tests without a live Firebase connection.
  ConnectionRequestRepository? _repoInstance;
  ConnectionRequestRepository get _repo =>
      _repoInstance ??= widget.repository ?? ConnectionRequestRepository();

  CaseActionHandler? _actionInstance;
  CaseActionHandler get _actionHandler =>
      _actionInstance ??= widget.actionHandler ?? CaseActionRepository();

  bool _actionBusy = false;
  String? _actionInFlight;

  // Live case subscription — keeps fields like `interestedLawyerIds`,
  // `status`, `lawyerId` in sync after withdraw/decline/approve.
  StreamSubscription<CaseModel?>? _caseSub;

  bool _hasTriggeredRecommendation = false;
  bool _manualRecommendationBusy = false;
  final Set<String> _clientRequestBusyLawyerIds = {};

  bool _isAuthenticatedCaseOwner(CaseModel caseModel) {
    if (!_isClient || widget.viewer.id != caseModel.clientId) return false;

    // Tests and dummy-data previews can construct this screen before Firebase
    // is configured. In the live app, require the Firebase Auth user to match.
    if (!FirebaseInitializer.isReady) return widget.viewer.id.isNotEmpty;

    final currentUser = FirebaseAuth.instance.currentUser;
    return currentUser != null && currentUser.uid == widget.viewer.id;
  }

  bool _shouldGenerateRecommendations(CaseModel caseModel) {
    final lawyerId = caseModel.lawyerId?.trim();
    final recommendationStatus = caseModel.recommendationStatus?.trim();
    final canStartForStatus =
        recommendationStatus == null ||
        recommendationStatus.isEmpty ||
        recommendationStatus == 'failed';

    return _isAuthenticatedCaseOwner(caseModel) &&
        (lawyerId == null || lawyerId.isEmpty) &&
        caseModel.status == CaseStatus.pending &&
        canStartForStatus &&
        caseModel.lawyerRecommendations.isEmpty;
  }

  void _triggerRecommendationIfNeeded(CaseModel caseModel) {
    if (_hasTriggeredRecommendation) return;
    if (!_shouldGenerateRecommendations(caseModel)) return;

    _hasTriggeredRecommendation = true;
    unawaited(_triggerLawyerRecommendations(caseModel.id));
  }

  Future<void> _triggerLawyerRecommendations(
    String caseId, {
    bool showFailureSnack = false,
  }) async {
    try {
      await _actionHandler.recommendLawyers(caseId: caseId);
    } catch (error) {
      debugPrint('Error triggering recommendations on detail screen: $error');

      if (FirebaseInitializer.isReady) {
        await CaseRepository()
            .updateCaseRecommendationStatus(caseId, 'failed')
            .catchError((err) {
              debugPrint('Failed to update case recommendation status: $err');
            });
      }

      if (showFailureSnack && mounted) {
        _showSnack(
          'Could not start AI matching. Please try again.',
          Colors.redAccent,
        );
      }
    }
  }

  Future<void> _retryLawyerRecommendations() async {
    if (_manualRecommendationBusy) return;

    setState(() => _manualRecommendationBusy = true);
    await _triggerLawyerRecommendations(_case.id, showFailureSnack: true);
    if (mounted) {
      setState(() => _manualRecommendationBusy = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _case = widget.caseModel;

    if (widget.subscribeToLiveUpdates) {
      final repo = widget.caseRepository ?? CaseRepository();
      _caseSub = repo.watchCase(_case.id).listen((updated) {
        if (!mounted || updated == null) return;
        setState(() => _case = updated);
        _triggerRecommendationIfNeeded(updated);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _triggerRecommendationIfNeeded(_case);
      }
    });
  }

  @override
  void dispose() {
    _caseSub?.cancel();
    super.dispose();
  }

  bool get _isLawyer => widget.viewer.role == UserRole.lawyer;
  bool get _isClient => widget.viewer.role == UserRole.client;
  bool get _isCaseOwner => _isClient && widget.viewer.id == _case.clientId;

  bool get _canWithdrawCase =>
      _isCaseOwner &&
      _case.status == CaseStatus.pending &&
      (_case.lawyerId == null || _case.lawyerId!.isEmpty);

  bool get _canCloseCase =>
      _isCaseOwner &&
      _case.status == CaseStatus.active &&
      _case.lawyerId != null &&
      _case.lawyerId!.isNotEmpty;

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

  Future<void> _runCaseAction(
    String action,
    Future<void> Function() task,
  ) async {
    if (_actionBusy) return;
    setState(() {
      _actionBusy = true;
      _actionInFlight = action;
    });

    try {
      await task();
    } finally {
      if (mounted) {
        setState(() {
          _actionBusy = false;
          _actionInFlight = null;
        });
      }
    }
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

  Future<void> _confirmCaseWithdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Withdraw case?',
          style: GoogleFonts.inter(
            color: const Color(0xFF0C1D36),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Withdrawing will decline all pending lawyer interests for this case.',
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

    if (confirmed != true || !mounted) return;

    await _runCaseAction('withdraw', () async {
      try {
        await _actionHandler.withdrawCase(caseId: _case.id);
        if (mounted) {
          _showSnack('Case withdrawn.', Colors.grey[700]!);
        }
      } catch (e) {
        if (mounted) {
          _showSnack(
            'Could not withdraw case. Please try again.',
            Colors.redAccent,
          );
        }
      }
    });
  }

  Future<void> _confirmCloseCase() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Close case?',
          style: GoogleFonts.inter(
            color: const Color(0xFF0C1D36),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Optionally add a closure reason for your lawyer.',
              style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLength: 200,
              maxLines: 3,
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Reason (optional)',
                hintStyle: GoogleFonts.inter(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
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
              backgroundColor: _gold,
              foregroundColor: _navy,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Close case',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    final reason = reasonCtrl.text.trim();
    reasonCtrl.dispose();

    if (confirmed != true || !mounted) return;

    await _runCaseAction('close', () async {
      try {
        await _actionHandler.closeCase(
          caseId: _case.id,
          reason: reason.isEmpty ? null : reason,
        );
        if (mounted) {
          _showSnack('Case closed.', Colors.grey[700]!);
        }
      } catch (e) {
        if (mounted) {
          _showSnack(
            'Could not close case. Please try again.',
            Colors.redAccent,
          );
        }
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Only subscribe to the request stream for verified lawyers — clients and
    // unverified lawyers don't need it (unverified see a disabled button,
    // clients have no EOI surface at all).
    final requestStream = (_isLawyer && widget.viewer.canAccessMarketplace)
        ? _repo.watchRequest(caseId: _case.id, lawyerId: widget.viewer.id)
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
                  if (_isLawyer) _buildLawyerMatchAnalysisCard(),
                  _buildDescriptionCard(),
                  const SizedBox(height: 20),
                  _buildDetailsCard(),
                  const SizedBox(height: 20),
                  if (_isCaseOwner) _buildClientActionsCard(),
                  if (_isCaseOwner) const SizedBox(height: 20),
                  if (_case.attachments.isNotEmpty) _buildAttachmentsCard(),
                  if (_case.attachments.isNotEmpty) const SizedBox(height: 20),
                  if (_isCaseOwner) ...[
                    _buildRecommendationsSection(),
                    const SizedBox(height: 20),
                  ],
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
          : _buildClientChatFAB(),
    );
  }

  // ── Client "Chat with lawyer" FAB ────────────────────────────────────────
  //
  // Shown only when there's an approved connection on this case. Streams all
  // approved requests for the client and checks for a match on this case.
  Widget _buildClientChatFAB() {
    return StreamBuilder<List<ConnectionRequestModel>>(
      stream: _repo.streamHistoryForClient(widget.viewer.id),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const [];
        ConnectionRequestModel? approved;
        try {
          approved = requests.firstWhere(
            (r) => r.caseId == _case.id &&
                r.status == ConnectionRequestStatus.approved,
          );
        } catch (_) {
          approved = null;
        }

        if (approved == null) return const SizedBox.shrink();

        return _fab(
          label: 'Chat with lawyer',
          icon: Icons.chat_bubble_outline,
          bg: _gold,
          fg: _navy,
          onPressed: () => _openClientChat(approved!.id),
        );
      },
    );
  }

  Future<void> _openLawyerChat(String roomId) async {
    final chatRepo = ChatRepository();
    final room = await chatRepo.fetchRoom(roomId);
    if (!mounted) return;
    if (room == null) {
      _showSnack(
        'Chat room not found. It may have been created before chat was enabled.',
        Colors.grey[700]!,
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          currentUser: widget.viewer,
          room: room,
          repository: chatRepo,
        ),
      ),
    );
  }

  Future<void> _openClientChat(String roomId) async {
    final chatRepo = ChatRepository();
    final room = await chatRepo.fetchRoom(roomId);
    if (!mounted) return;
    if (room == null) {
      _showSnack(
        'Chat room not found. It may have been created before chat was enabled.',
        Colors.grey[700]!,
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatRoomScreen(
          currentUser: widget.viewer,
          room: room,
          repository: chatRepo,
        ),
      ),
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

  Widget _buildLawyerMatchAnalysisCard() {
    final match = widget.matchResult;
    if (match == null || match.matchPercentage <= 0) return const SizedBox.shrink();

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFDF5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFDE68A)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'AI Match Analysis',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF0C1D36),
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Text(
                      '${match.matchPercentage}% Match',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFB45309),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                match.matchReason,
                style: GoogleFonts.inter(
                  color: Colors.grey[700],
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
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

  /// True when the viewer is a lawyer who has not yet been approved for this case.
  bool get _isUnconnectedLawyer =>
      _isLawyer && _case.lawyerId != widget.viewer.id;

  Widget _buildDetailsCard() {
    final displayName = _isUnconnectedLawyer
        ? 'CLIENT-${_case.id.hashCode.abs() % 10000}'
        : _resolveClientUser().name;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.info_outline, 'Case Information'),
          const SizedBox(height: 16),
          _detailRow(Icons.person_outline, 'Client', displayName),
          _divider(),
          _detailRow(Icons.label_outline, 'Category', _case.categoryLabel),
          if (_case.location != null && _case.location!.isNotEmpty) ...[
            _divider(),
            _detailRow(Icons.location_on_outlined, 'Location', _case.location!),
          ],
          if (_case.budgetRange != null && _case.budgetRange!.isNotEmpty) ...[
            _divider(),
            _detailRow(Icons.payments_outlined, 'Budget', _case.budgetRange!),
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
          if (_case.closeReason != null && _case.closeReason!.isNotEmpty) ...[
            _divider(),
            _detailRow(
              Icons.note_outlined,
              'Closure Reason',
              _case.closeReason!,
              valueColor: Colors.grey[700],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildClientActionsCard() {
    if (!_canWithdrawCase && !_canCloseCase) {
      return const SizedBox.shrink();
    }

    final isWithdraw = _canWithdrawCase;
    final actionLabel = isWithdraw ? 'Withdraw case' : 'Close case';
    final helperText = isWithdraw
        ? 'Withdraw before accepting a lawyer. Pending interests will be declined.'
        : 'Close the case once resolved. Optionally add a reason for your lawyer.';
    final actionColor = isWithdraw ? Colors.redAccent : _gold;
    final actionTextColor = isWithdraw ? Colors.white : _navy;
    final busy =
        _actionBusy && _actionInFlight == (isWithdraw ? 'withdraw' : 'close');

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.manage_accounts_outlined, 'Case Actions'),
          const SizedBox(height: 8),
          Text(
            helperText,
            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: busy
                  ? null
                  : isWithdraw
                  ? _confirmCaseWithdraw
                  : _confirmCloseCase,
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: actionTextColor,
                disabledBackgroundColor: actionColor.withValues(alpha: 0.6),
                disabledForegroundColor: actionTextColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        value: _isTest ? 0.5 : null,
                        color: actionTextColor,
                      ),
                    )
                  : Text(
                      actionLabel,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
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
                const Icon(Icons.description_outlined, color: _navy, size: 16),
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
    if (_case.interestedLawyerIds.isEmpty) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(Icons.group_outlined, 'Interested Lawyers'),
            const SizedBox(height: 12),
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
            ),
          ],
        ),
      );
    }

    final repo = widget.repository ?? ConnectionRequestRepository();

    return StreamBuilder<List<ConnectionRequestModel>>(
      stream: repo.streamPendingForClient(widget.viewer.id),
      builder: (context, snapshot) {
        final allRequests = snapshot.data ?? [];
        final pendingRequests = allRequests
            .where((req) => req.caseId == _case.id)
            .toList();

        return _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _cardHeader(Icons.group_outlined, 'Interested Lawyers'),
              const SizedBox(height: 12),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  allRequests.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: CircularProgressIndicator(
                      value: _isTest ? 0.5 : null,
                    ),
                  ),
                )
              else if (pendingRequests.isEmpty)
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
                ...pendingRequests.map((req) => _lawyerTile(req)),
            ],
          ),
        );
      },
    );
  }

  Widget _lawyerTile(ConnectionRequestModel request) {
    final lawyer = request.lawyerSnapshot;
    final isVerified = lawyer.verificationStatus == 'auto_verified';
    final verificationLabel = isVerified
        ? 'Verified'
        : (lawyer.verificationStatus == 'pending' ? 'Pending' : 'Unverified');

    return GestureDetector(
      onTap: () => LawyerProfileSheet.show(context, snapshot: lawyer),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Avatar
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _gold, width: 2),
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
                              fontSize: 18,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lawyer.name,
                        style: GoogleFonts.inter(
                          color: _navy,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        lawyer.specialization ?? 'Legal Practitioner',
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Stars & Verification
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFCFA92A),
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${lawyer.rating ?? '-'}',
                          style: GoogleFonts.inter(
                            color: _navy,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isVerified
                            ? const Color(0xFFF0FDF4)
                            : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: isVerified
                              ? const Color(0xFFBBF7D0)
                              : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Text(
                        verificationLabel,
                        style: GoogleFonts.inter(
                          color: isVerified
                              ? const Color(0xFF15803D)
                              : const Color(0xFFD97706),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Message Preview
            Text(
              request.message,
              style: GoogleFonts.inter(color: _navy, fontSize: 13, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  'Tap to view profile',
                  style: GoogleFonts.inter(
                    color: _navy.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (!_isLawyer)
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final repo =
                            widget.repository ?? ConnectionRequestRepository();
                        await repo.approveRequest(
                          requestId: request.id,
                          client: widget.viewer,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Hired ${lawyer.name}!')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Failed: $e')));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gold,
                      foregroundColor: _navy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Hire',
                      style: GoogleFonts.inter(
                        fontSize: 13,
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

    // Connected (assigned to self OR request approved) — open chat
    if ((assignedLawyerId != null && assignedLawyerId == widget.viewer.id) ||
        request?.status == ConnectionRequestStatus.approved) {
      final roomId = request?.id ??
          ConnectionRequestRepository.docIdFor(
            caseId: _case.id,
            lawyerId: widget.viewer.id,
          );
      return _fab(
        label: 'Chat with client',
        icon: Icons.chat_bubble_outline,
        bg: _navy,
        fg: Colors.white,
        onPressed: () => _openLawyerChat(roomId),
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
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.grey[400], size: 16),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
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
      case CaseStatus.withdrawn:
        color = Colors.redAccent;
        label = 'Withdrawn';
        icon = Icons.remove_circle_outline;
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

  Widget _buildRecommendationsSection() {
    if (_case.status != CaseStatus.pending &&
        _case.lawyerRecommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    final status = _case.recommendationStatus?.trim();
    final hasRecommendations = _case.lawyerRecommendations.isNotEmpty;

    if (status == 'generating') {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(Icons.auto_awesome, 'AI Lawyer Recommendations'),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    value: _isTest ? 0.5 : null,
                    valueColor: const AlwaysStoppedAnimation<Color>(_navy),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Finding suitable lawyers...',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (status == 'failed' && !hasRecommendations) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(Icons.auto_awesome, 'AI Lawyer Recommendations'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'AI matching could not be completed. You can still review lawyer interests below.',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _manualRecommendationBusy
                    ? null
                    : _retryLawyerRecommendations,
                icon: _manualRecommendationBusy
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          value: _isTest ? 0.5 : null,
                        ),
                      )
                    : const Icon(Icons.refresh, size: 16),
                label: Text(
                  _manualRecommendationBusy ? 'Trying again...' : 'Try again',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (status == 'not_enough_lawyers' ||
        (status == 'completed' && !hasRecommendations)) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(Icons.auto_awesome, 'AI Lawyer Recommendations'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No suitable lawyers found. Try updating your case details or budget range to match more lawyers.',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (!hasRecommendations) {
      return _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardHeader(Icons.auto_awesome, 'AI Lawyer Recommendations'),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.auto_awesome_outlined, color: _gold, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Recommendations have not been generated yet. AI matching will start automatically when this case is eligible.',
                    style: GoogleFonts.inter(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, color: _gold, size: 18),
            const SizedBox(width: 8),
            Text(
              'AI Recommended Lawyers',
              style: GoogleFonts.inter(
                color: _navy,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._case.lawyerRecommendations.map(
          (rec) => _recommendedLawyerCard(rec),
        ),
      ],
    );
  }

  Widget _recommendedLawyerCard(LawyerRecommendation rec) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: _navy,
                ),
                child: Center(
                  child: Text(
                    rec.lawyerName.isNotEmpty
                        ? rec.lawyerName[0].toUpperCase()
                        : 'L',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec.lawyerName,
                      style: GoogleFonts.inter(
                        color: _navy,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rec.specialization,
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  '${rec.matchPercentage}% Match',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1D4ED8),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _recMiniChip(
                Icons.location_on_outlined,
                '${rec.practiceCity}, ${rec.practiceState}',
              ),
              _recMiniChip(
                Icons.work_history_outlined,
                '${rec.yearsExperience} yrs exp',
              ),
              if (rec.languages.isNotEmpty)
                _recMiniChip(
                  Icons.translate_outlined,
                  rec.languages.join(', '),
                ),
              _recMiniChip(
                Icons.payments_outlined,
                'RM ${rec.hourlyRate.toInt()}/hr',
              ),
            ],
          ),
          const SizedBox(height: 14),
          const SizedBox(height: 14),
          if (rec.matchReason.trim().isNotEmpty) ...[
            Text(
              'Why they fit your case:',
              style: GoogleFonts.inter(
                color: _navy,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check, color: Colors.green, size: 14),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rec.matchReason,
                    style: GoogleFonts.inter(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            height: 38,
            child: FirebaseInitializer.isReady
                ? StreamBuilder<ConnectionRequestModel?>(
                    stream: _repo.watchRequest(
                      caseId: _case.id,
                      lawyerId: rec.lawyerId,
                    ),
                    builder: (context, snapshot) =>
                        _requestLawyerButton(rec, snapshot.data),
                  )
                : _requestLawyerButton(rec, null),
          ),
        ],
      ),
    );
  }

  Widget _requestLawyerButton(
    LawyerRecommendation rec,
    ConnectionRequestModel? request,
  ) {
    final busy = _clientRequestBusyLawyerIds.contains(rec.lawyerId);
    final isPendingClientRequest =
        request?.isClientInitiated == true &&
        request?.status == ConnectionRequestStatus.pending;
    final isApprovedRequest =
        request?.status == ConnectionRequestStatus.approved;
    final isPendingLawyerInterest =
        request?.isLawyerInitiated == true &&
        request?.status == ConnectionRequestStatus.pending;
    final unavailable =
        _case.status != CaseStatus.pending ||
        (_case.lawyerId != null && _case.lawyerId!.isNotEmpty);

    final disabled =
        busy ||
        isPendingClientRequest ||
        isApprovedRequest ||
        isPendingLawyerInterest ||
        unavailable;

    final label = busy
        ? 'Sending...'
        : isPendingClientRequest
        ? 'Request sent'
        : isApprovedRequest
        ? 'Connected'
        : isPendingLawyerInterest
        ? 'Lawyer interested'
        : unavailable
        ? 'Unavailable'
        : 'Request this lawyer';

    return ElevatedButton(
      onPressed: disabled ? null : () => _showRequestLawyerDialog(rec),
      style: ElevatedButton.styleFrom(
        backgroundColor: _gold,
        foregroundColor: _navy,
        disabledBackgroundColor: Colors.grey[200],
        disabledForegroundColor: Colors.grey[500],
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  Widget _recMiniChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFF3F4F6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey[500]),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _showRequestLawyerDialog(LawyerRecommendation rec) async {
    if (!_isAuthenticatedCaseOwner(_case)) {
      _showSnack('Only the case owner can request a lawyer.', Colors.redAccent);
      return;
    }
    if (_case.status != CaseStatus.pending ||
        (_case.lawyerId != null && _case.lawyerId!.isNotEmpty)) {
      _showSnack('This case is no longer open for requests.', Colors.redAccent);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Request Connection',
          style: GoogleFonts.inter(color: _navy, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Would you like to request a connection with ${rec.lawyerName}? They will be notified to review your case details.',
          style: GoogleFonts.inter(color: Colors.grey[700], fontSize: 13),
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
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _gold,
              foregroundColor: _navy,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Send Request',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _clientRequestBusyLawyerIds.add(rec.lawyerId));
    try {
      final existingStatus = await _repo.sendClientRequestToLawyer(
        targetCase: _case,
        client: widget.viewer,
        lawyer: rec,
      );
      if (!mounted) return;

      switch (existingStatus) {
        case ConnectionRequestStatus.pending:
          _showSnack('Request already sent.', Colors.grey[700]!);
          break;
        case ConnectionRequestStatus.approved:
          _showSnack(
            'This lawyer is already connected to this case.',
            Colors.grey[700]!,
          );
          break;
        default:
          _showSnack(
            'Request sent to ${rec.lawyerName}!',
            const Color(0xFF2E7D32),
          );
      }
    } on CaseAlreadyConnectedException {
      if (mounted) {
        _showSnack(
          'This case is already connected to a lawyer.',
          Colors.redAccent,
        );
      }
    } catch (error) {
      debugPrint('Client lawyer request failed: $error');
      if (mounted) {
        _showSnack(
          'Could not send request. Please try again.',
          Colors.redAccent,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _clientRequestBusyLawyerIds.remove(rec.lawyerId));
      }
    }
  }
}
