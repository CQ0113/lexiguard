import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/dummy_data.dart';
import '../../models/case_model.dart';
import '../../models/user_model.dart';
import '../../repositories/case_repository.dart';
import '../../repositories/connection_request_repository.dart';
import '../login_screen.dart';
import '../shared/post_case_screen.dart';
import '../shared/case_detail_screen.dart';
import '../shared/profile_screen.dart';
import '../shared/vault_tab_router_screen.dart';
import 'connection_requests_screen.dart';
import '../chat/chat_list_screen.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/vault_document_repository.dart';
import 'client_signature_screen.dart';
import 'lexibot_chat_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CLIENT SHELL — matches MobileShell + all client screens from Figma
// Tabs: Home | Post Case | Chat | Vault | Sign | Profile
// ─────────────────────────────────────────────────────────────────────────────
class ClientDashboardScreen extends StatefulWidget {
  final UserModel user;
  final CaseRepository? caseRepository;
  final ConnectionRequestRepository? connectionRequestRepository;
  final ChatRepository? chatRepository;
  final VaultDocumentRepository? vaultRepository;

  const ClientDashboardScreen({
    super.key,
    required this.user,
    this.caseRepository,
    this.connectionRequestRepository,
    this.chatRepository,
    this.vaultRepository,
  });

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);

  int _currentTab = 0;

  // Bottom nav tabs (following your exact 6 tabs)
  static const _tabs = [
    _Tab(Icons.grid_view_rounded, 'Home'),
    _Tab(Icons.add_circle_outline_rounded, 'Post Case'),
    _Tab(Icons.chat_bubble_outline_rounded, 'Chat'),
    _Tab(Icons.folder_outlined, 'Vault'),
    _Tab(Icons.edit_document, 'Sign'),
    _Tab(Icons.person_outline_rounded, 'Profile'),
  ];

  Future<void> _onTabTap(int idx) async {
    if (idx == 1) {
      // Post Case — navigate as full screen
      final result = await Navigator.of(context).push<CaseModel>(
        MaterialPageRoute(builder: (_) => PostCaseScreen(poster: widget.user)),
      );
      if (result != null) {
        setState(() {});
        if (mounted) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CaseDetailScreen(caseModel: result, viewer: widget.user),
            ),
          );
        }
      }
      return;
    }

    // Switched to internal tab navigation instead of Navigator.push
    setState(() => _currentTab = idx);
  }

  void _switchToTab(int index) {
    if (index == 1 || index < 0 || index >= _tabs.length) return;
    setState(() => _currentTab = index);
  }

  void _goHome() {
    setState(() => _currentTab = 0);
  }

  void _showNotificationsSnackBar() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'You have no new notifications. You will be alerted when a lawyer connects or shares a document.',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: _navy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not sign out cleanly. Returning to login.',
            style: GoogleFonts.inter(color: Colors.white),
          ),
          backgroundColor: const Color(0xFFB91C1C),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      // ── Navy top header (from mobile-shell.tsx) ──────────────────────────
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          color: _navy,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: _goHome,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.shield_outlined,
                              color: _navy,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LexiGuard',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Notification bell
                  GestureDetector(
                    onTap: _showNotificationsSnackBar,
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      children: [
                        const Icon(
                          Icons.notifications_none_outlined,
                          color: Colors.white70,
                          size: 22,
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Logout
                  GestureDetector(
                    onTap: _logout,
                    child: const Icon(
                      Icons.logout_outlined,
                      color: Colors.white70,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // ── Body ─────────────────────────────────────────────────────────────
      body: IndexedStack(
        // The math maps the bottom nav index to the list of 5 screens below
        // (skipping index 1 because Post Case is a push overlay)
        index: _currentTab <= 1 ? 0 : _currentTab - 1,
        children: [
          _ClientHomeTab(
            user: widget.user,
            onSwitchTab: _switchToTab,
            onShowNotifications: _showNotificationsSnackBar,
            caseRepository: widget.caseRepository,
            connectionRequestRepository: widget.connectionRequestRepository,
          ), // Maps to index 0 (Home)
          ChatListScreen(
            currentUser: widget.user,
            repository: widget.chatRepository,
          ), // Maps to index 2 (Chat)
          VaultTabRouterScreen(
            user: widget.user,
            repository: widget.vaultRepository,
          ), // Maps to index 3 (Vault)
          ClientSignatureScreen(
            clientUser: widget.user,
            repository: widget.vaultRepository,
          ), // Maps to index 4 (Sign)
          ProfileScreen(
            user: widget.user,
            embedded: true,
          ), // Maps to index 5 (Profile)
        ],
      ),
      // ── Bottom nav (from mobile-shell.tsx) ───────────────────────────────
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final active = _currentTab == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tabs[i].icon,
                          size: 22,
                          color: active ? _navy : Colors.grey[400],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tabs[i].label,
                          style: GoogleFonts.inter(
                            color: active ? _navy : Colors.grey[400],
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Gold underline indicator
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: active ? 20 : 0,
                          height: 2,
                          decoration: BoxDecoration(
                            color: _gold,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME TAB — exact match of client-dashboard.tsx
// ─────────────────────────────────────────────────────────────────────────────
class _ClientHomeTab extends StatefulWidget {
  final UserModel user;
  final ValueChanged<int> onSwitchTab;
  final VoidCallback onShowNotifications;
  final CaseRepository? caseRepository;
  final ConnectionRequestRepository? connectionRequestRepository;

  const _ClientHomeTab({
    required this.user,
    required this.onSwitchTab,
    required this.onShowNotifications,
    this.caseRepository,
    this.connectionRequestRepository,
  });

  @override
  State<_ClientHomeTab> createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends State<_ClientHomeTab> {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);
  late final CaseRepository _caseRepository;
  late final ConnectionRequestRepository _connRepo;
  late final Stream<List<ConnectionRequestModel>> _pendingStream;

  @override
  void initState() {
    super.initState();
    _caseRepository = widget.caseRepository ?? CaseRepository();
    _connRepo = widget.connectionRequestRepository ?? ConnectionRequestRepository();
    _pendingStream = _connRepo.streamPendingForClient(widget.user.id);
  }

  // Quick actions (from client-dashboard.tsx exactly)
  static const _quickActions = [
    _QA(Icons.add_circle_outline_rounded, 'Post Case', _gold),
    _QA(Icons.smart_toy_outlined, 'LexiBot', _navy),
    _QA(Icons.search_rounded, 'Find Lawyer', Color(0xFF1A4B8C)),
    _QA(Icons.edit_document, 'E-Sign', Color(0xFF2E6AB4)),
  ];

  // Recent activity (from client-dashboard.tsx)
  static const _activities = [
    _ActivityItem(
      Icons.edit_document,
      'Contract reviewed by AI',
      'Tenancy Agreement — 2 risks found',
      '2h ago',
    ),
    _ActivityItem(
      Icons.chat_bubble_outline_rounded,
      'New message from Pn. Aishah',
      'Regarding property dispute case',
      '5h ago',
    ),
    _ActivityItem(
      Icons.folder_outlined,
      'Document shared',
      'IC Copy — expires in 24h',
      '1d ago',
    ),
  ];

  CaseModel? _activeCaseFrom(List<CaseModel> cases) {
    for (final caseModel in cases) {
      if (caseModel.status == CaseStatus.active) {
        return caseModel;
      }
    }
    return null;
  }

  String _lawyerLabelFor(CaseModel caseModel) {
    if (caseModel.lawyerId == null || caseModel.lawyerId!.isEmpty) {
      return 'Lawyer: Awaiting assignment';
    }

    try {
      final lawyer = DummyData.users.firstWhere(
        (u) => u.id == caseModel.lawyerId,
      );
      return 'Lawyer: ${lawyer.name}';
    } catch (_) {
      return 'Lawyer assigned';
    }
  }

  String _hearingLabelFor(CaseModel caseModel) {
    if (caseModel.nextHearing == null) {
      return 'Next hearing: To be scheduled';
    }

    return 'Next hearing: ${DateFormat('d MMMM yyyy').format(caseModel.nextHearing!)}';
  }

  Future<void> _openPostCase() async {
    final result = await Navigator.of(context).push<CaseModel>(
      MaterialPageRoute(builder: (_) => PostCaseScreen(poster: widget.user)),
    );
    if (result != null) {
      setState(() {});
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CaseDetailScreen(caseModel: result, viewer: widget.user),
          ),
        );
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
          backgroundColor: _navy,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  void _openConnectionRequests() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConnectionRequestsScreen(
          client: widget.user,
          repository: _connRepo,
        ),
      ),
    );
  }

  void _openLexiBotEntry() {
    widget.onSwitchTab(2);
    _showSnackBar(
      'LexiBot is active in your chat rooms to help draft responses, or will be available here soon!',
    );
  }

  VoidCallback _quickActionTap(_QA action) {
    switch (action.label) {
      case 'Post Case':
        return () => _openPostCase();
      case 'LexiBot':
        return _openLexiBotEntry;
      case 'Find Lawyer':
        return _openConnectionRequests;
      case 'E-Sign':
        return () => widget.onSwitchTab(4);
    }
    return () => _showSnackBar('${action.label} will be available soon.');
  }

  VoidCallback _activityTap(_ActivityItem item) {
    switch (item.title) {
      case 'Contract reviewed by AI':
        return () => widget.onSwitchTab(4);
      case 'New message from Pn. Aishah':
        return () => widget.onSwitchTab(2);
      case 'Document shared':
        return () => widget.onSwitchTab(3);
    }
    return () => _showSnackBar('Activity details will be available soon.');
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ConnectionRequestModel>>(
      stream: _pendingStream,
      builder: (context, pendingSnap) {
        if (pendingSnap.hasError) {
          debugPrint(
            '[ClientDashboard] pendingStream error: ${pendingSnap.error}',
          );
        }
        final pendingRequests = pendingSnap.data ?? const [];
        return _buildWithPending(pendingRequests);
      },
    );
  }

  int _statusSortPriority(CaseStatus status) {
    switch (status) {
      case CaseStatus.pending:
        return 0;
      case CaseStatus.active:
        return 1;
      case CaseStatus.closed:
        return 2;
      case CaseStatus.withdrawn:
        return 3;
    }
  }

  Widget _buildWithPending(List<ConnectionRequestModel> pendingRequests) {
    return StreamBuilder<List<CaseModel>>(
      stream: _caseRepository.streamClientCases(clientId: widget.user.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0B2447)),
          );
        }

        final myCases = List<CaseModel>.from(snapshot.data ?? const <CaseModel>[]);
        myCases.sort((a, b) {
          final priorityA = _statusSortPriority(a.status);
          final priorityB = _statusSortPriority(b.status);
          if (priorityA != priorityB) {
            return priorityA.compareTo(priorityB);
          }
          return b.createdAt.compareTo(a.createdAt);
        });

        final activeCase = _activeCaseFrom(myCases);
        return _buildContent(
          myCases: myCases,
          activeCase: activeCase,
          pendingRequests: pendingRequests,
        );
      },
    );
  }

  Widget _buildContent({
    required List<CaseModel> myCases,
    required CaseModel? activeCase,
    required List<ConnectionRequestModel> pendingRequests,
  }) {
    final pendingCount = pendingRequests.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ──────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome back',
                    style: GoogleFonts.inter(
                      color: Colors.grey[500],
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    widget.user.name,
                    style: GoogleFonts.inter(
                      color: _navy,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: widget.onShowNotifications,
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  children: [
                    Icon(
                      Icons.notifications_none_outlined,
                      color: Colors.grey[500],
                      size: 24,
                    ),
                    if (pendingCount > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$pendingCount',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Pending lawyers banner (gold gradient, from client-dashboard.tsx) ─
          if (pendingCount > 0) ...[
            GestureDetector(
              onTap: _openConnectionRequests,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFD4AF37), Color(0xFFE8C84A)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _navy,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.how_to_reg_outlined,
                            color: _gold,
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$pendingCount Lawyer${pendingCount > 1 ? "s" : ""} Interested!',
                                style: GoogleFonts.inter(
                                  color: _navy,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'Tap to review and approve',
                                style: GoogleFonts.inter(
                                  color: _navy.withValues(alpha: 0.7),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right,
                          color: _navy.withValues(alpha: 0.6),
                          size: 20,
                        ),
                      ],
                    ),
                    // Avatar stack — up to 3 real avatars from pending requests
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        ...pendingRequests.take(3).map((req) {
                          final snap = req.lawyerSnapshot;
                          final initial = snap.name.isNotEmpty
                              ? snap.name[0].toUpperCase()
                              : '?';
                          return Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: _navy,
                              shape: BoxShape.circle,
                              border: Border.all(color: _gold, width: 2),
                              image: snap.avatarUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(snap.avatarUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: snap.avatarUrl == null
                                ? Center(
                                    child: Text(
                                      initial,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        }),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            pendingRequests
                                .take(3)
                                .map(
                                  (r) => r.lawyerSnapshot.name.split(' ').first,
                                )
                                .join(', '),
                            style: GoogleFonts.inter(
                              color: _navy.withValues(alpha: 0.8),
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Active Case card (navy, from client-dashboard.tsx) ─────────
          if (activeCase != null) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CaseDetailScreen(caseModel: activeCase, viewer: widget.user),
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _navy,
                  borderRadius: BorderRadius.circular(16),
                ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.balance, color: _gold, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'ACTIVE CASE',
                        style: GoogleFonts.inter(
                          color: _gold,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activeCase.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    _lawyerLabelFor(activeCase),
                    style: GoogleFonts.inter(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: activeCase.progressPercent / 100,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.2,
                            ),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              _gold,
                            ),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${activeCase.progressPercent.toInt()}%',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _hearingLabelFor(activeCase),
                    style: GoogleFonts.inter(
                      color: Colors.white38,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            )),
            const SizedBox(height: 24),
          ],

          // ── Quick Actions (grid-cols-4, from client-dashboard.tsx) ───────
          Text(
            'Quick Actions',
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _quickActions.map((a) {
              return GestureDetector(
                onTap: _quickActionTap(a),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: a.color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(a.icon, color: a.color, size: 24),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      a.label,
                      style: GoogleFonts.inter(
                        color: Colors.grey[600],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // ── Recent Activity ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Activity',
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: () => _showSnackBar(
                  'Full activity history will be available soon.',
                ),
                behavior: HitTestBehavior.opaque,
                child: Text(
                  'View All',
                  style: GoogleFonts.inter(
                    color: _gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._activities.map((item) => _activityCard(item)),

          // ── My Cases ─────────────────────────────────────────────────────
          if (myCases.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Cases',
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AllCasesScreen(
                          cases: myCases,
                          user: widget.user,
                          caseRepository: _caseRepository,
                        ),
                      ),
                    );
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(
                      color: _gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...myCases.take(3).map((c) => _caseCard(c)),
          ],
        ],
      ),
    );
  }

  Widget _activityCard(_ActivityItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: _activityTap(item),
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: _navy, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: GoogleFonts.inter(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      item.subtitle,
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                  const SizedBox(width: 3),
                  Text(
                    item.time,
                    style: GoogleFonts.inter(
                      color: Colors.grey[400],
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _caseCard(CaseModel c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CaseDetailScreen(caseModel: c, viewer: widget.user),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.gavel_outlined, color: _navy, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      style: GoogleFonts.inter(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      c.categoryLabel,
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: () {
                    switch (c.status) {
                      case CaseStatus.pending:
                        return const Color(0xFFFEF3C7); // soft amber
                      case CaseStatus.active:
                        return const Color(0xFFD1FAE5); // soft green
                      case CaseStatus.withdrawn:
                        return const Color(0xFFFEE2E2); // soft red
                      case CaseStatus.closed:
                        return const Color(0xFFE5E7EB); // soft gray
                    }
                  }(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  c.status == CaseStatus.active ? 'APPROVED' : c.status.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: () {
                      switch (c.status) {
                        case CaseStatus.pending:
                          return const Color(0xFFB45309); // dark amber
                        case CaseStatus.active:
                          return const Color(0xFF065F46); // dark green
                        case CaseStatus.withdrawn:
                          return const Color(0xFF991B1B); // dark red
                        case CaseStatus.closed:
                          return const Color(0xFF374151); // dark gray
                      }
                    }(),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder for unfinished tabs
// ─────────────────────────────────────────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  final String label;
  final IconData icon;
  const _PlaceholderTab(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            'Coming soon',
            style: GoogleFonts.inter(color: Colors.grey[300], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ALL CASES SCREEN — Popup Screen with Real-time Stream & Priority Sorting
// ─────────────────────────────────────────────────────────────────────────────
class AllCasesScreen extends StatefulWidget {
  final List<CaseModel> cases;
  final UserModel user;
  final CaseRepository caseRepository;

  const AllCasesScreen({
    super.key,
    required this.cases,
    required this.user,
    required this.caseRepository,
  });

  @override
  State<AllCasesScreen> createState() => _AllCasesScreenState();
}

class _AllCasesScreenState extends State<AllCasesScreen> {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);
  String _selectedFilter = 'all';

  int _statusSortPriority(CaseStatus status) {
    switch (status) {
      case CaseStatus.pending:
        return 0;
      case CaseStatus.active:
        return 1;
      case CaseStatus.closed:
        return 2;
      case CaseStatus.withdrawn:
        return 3;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        title: Text(
          'My Cases',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth > 720) {
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _filterChip('all', 'All', Icons.all_inbox_rounded),
                      const SizedBox(width: 12),
                      _filterChip('pending', 'Pending', Icons.pending_actions_rounded),
                      const SizedBox(width: 12),
                      _filterChip('approved', 'Approved', Icons.check_circle_rounded),
                      const SizedBox(width: 12),
                      _filterChip('withdrawn', 'Withdrawn', Icons.backspace_rounded),
                      const SizedBox(width: 12),
                      _filterChip('closed', 'Closed', Icons.lock_rounded),
                    ],
                  );
                } else {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        _filterChip('all', 'All', Icons.all_inbox_rounded),
                        const SizedBox(width: 8),
                        _filterChip('pending', 'Pending', Icons.pending_actions_rounded),
                        const SizedBox(width: 8),
                        _filterChip('approved', 'Approved', Icons.check_circle_rounded),
                        const SizedBox(width: 8),
                        _filterChip('withdrawn', 'Withdrawn', Icons.backspace_rounded),
                        const SizedBox(width: 8),
                        _filterChip('closed', 'Closed', Icons.lock_rounded),
                      ],
                    ),
                  );
                }
              },
            ),
          ),
          // Cases Stream Builder
          Expanded(
            child: StreamBuilder<List<CaseModel>>(
              stream: widget.caseRepository.streamClientCases(clientId: widget.user.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: _navy),
                  );
                }

                var cases = List<CaseModel>.from(snapshot.data ?? const <CaseModel>[]);

                // 1. Sort cases: Priority-based sorting, then by createdAt descending
                cases.sort((a, b) {
                  final priorityA = _statusSortPriority(a.status);
                  final priorityB = _statusSortPriority(b.status);
                  if (priorityA != priorityB) {
                    return priorityA.compareTo(priorityB);
                  }
                  return b.createdAt.compareTo(a.createdAt);
                });

                // 2. Filter cases based on chosen chip
                if (_selectedFilter != 'all') {
                  cases = cases.where((c) {
                    if (_selectedFilter == 'pending') {
                      return c.status == CaseStatus.pending;
                    } else if (_selectedFilter == 'approved') {
                      return c.status == CaseStatus.active;
                    } else if (_selectedFilter == 'withdrawn') {
                      return c.status == CaseStatus.withdrawn;
                    } else if (_selectedFilter == 'closed') {
                      return c.status == CaseStatus.closed;
                    }
                    return true;
                  }).toList();
                }

                if (cases.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.gavel_outlined, size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(
                          'No cases found for this filter.',
                          style: GoogleFonts.inter(
                            color: Colors.grey[500],
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  itemCount: cases.length,
                  itemBuilder: (context, index) {
                    return _caseCard(cases[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String filter, String label, IconData icon) {
    final active = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = filter;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _navy : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: active ? _navy : const Color(0xFFE5E7EB),
            width: 1.5,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: _navy.withValues(alpha: 0.2),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  )
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? _gold : Colors.grey[500],
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                color: active ? Colors.white : Colors.grey[700],
                fontSize: 12,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _caseCard(CaseModel c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CaseDetailScreen(caseModel: c, viewer: widget.user),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _navy.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.gavel_outlined, color: _navy, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.title,
                      style: GoogleFonts.inter(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      c.categoryLabel,
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: () {
                    switch (c.status) {
                      case CaseStatus.pending:
                        return const Color(0xFFFEF3C7); // soft amber
                      case CaseStatus.active:
                        return const Color(0xFFD1FAE5); // soft green
                      case CaseStatus.withdrawn:
                        return const Color(0xFFFEE2E2); // soft red
                      case CaseStatus.closed:
                        return const Color(0xFFE5E7EB); // soft gray
                    }
                  }(),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  c.status == CaseStatus.active ? 'APPROVED' : c.status.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: () {
                      switch (c.status) {
                        case CaseStatus.pending:
                          return const Color(0xFFB45309); // dark amber
                        case CaseStatus.active:
                          return const Color(0xFF065F46); // dark green
                        case CaseStatus.withdrawn:
                          return const Color(0xFF991B1B); // dark red
                        case CaseStatus.closed:
                          return const Color(0xFF374151); // dark gray
                      }
                    }(),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data classes
// ─────────────────────────────────────────────────────────────────────────────
class _Tab {
  final IconData icon;
  final String label;
  const _Tab(this.icon, this.label);
}

class _QA {
  final IconData icon;
  final String label;
  final Color color;
  const _QA(this.icon, this.label, this.color);
}

class _ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  const _ActivityItem(this.icon, this.title, this.subtitle, this.time);
}
