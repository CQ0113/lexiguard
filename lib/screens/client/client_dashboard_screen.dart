import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/dummy_data.dart';
import '../../models/case_model.dart';
import '../../models/user_model.dart';
import '../login_screen.dart';
import '../shared/post_case_screen.dart';
import '../shared/case_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// CLIENT SHELL — matches MobileShell + all client screens from Figma
// Tabs: Home | Post Case | Chat | Vault | Sign | Profile
// ─────────────────────────────────────────────────────────────────────────────
class ClientDashboardScreen extends StatefulWidget {
  final UserModel user;
  const ClientDashboardScreen({super.key, required this.user});

  @override
  State<ClientDashboardScreen> createState() => _ClientDashboardScreenState();
}

class _ClientDashboardScreenState extends State<ClientDashboardScreen> {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);

  int _currentTab = 0;

  // Bottom nav tabs (from mobile-shell.tsx clientTabs)
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
        MaterialPageRoute(
          builder: (_) => PostCaseScreen(poster: widget.user),
        ),
      );
      if (result != null) setState(() {});
      return;
    }
    setState(() => _currentTab = idx);
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
                  // Logo circle
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(Icons.shield_outlined,
                          color: _navy, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('LexiGuard',
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600)),
                  const Spacer(),
                  // Notification bell
                  Stack(
                    children: [
                      const Icon(Icons.notifications_none_outlined,
                          color: Colors.white70, size: 22),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  // Logout
                  GestureDetector(
                    onTap: _logout,
                    child: const Icon(Icons.logout_outlined,
                        color: Colors.white70, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      // ── Body ─────────────────────────────────────────────────────────────
      body: IndexedStack(
        index: _currentTab <= 1 ? 0 : _currentTab - 1,
        children: [
          _ClientHomeTab(user: widget.user),
          _PlaceholderTab('Chat', Icons.chat_bubble_outline_rounded),
          _PlaceholderTab('Vault', Icons.folder_outlined),
          _PlaceholderTab('Sign', Icons.edit_document),
          _ClientProfileTab(user: widget.user),
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
  const _ClientHomeTab({required this.user});

  @override
  State<_ClientHomeTab> createState() => _ClientHomeTabState();
}

class _ClientHomeTabState extends State<_ClientHomeTab> {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);

  // Pending requests count (simulated from connection-context)
  final int _pendingCount = 2;

  // Quick actions (from client-dashboard.tsx exactly)
  static const _quickActions = [
    _QA(Icons.add_circle_outline_rounded, 'Post Case', _gold),
    _QA(Icons.smart_toy_outlined, 'LexiBot', _navy),
    _QA(Icons.search_rounded, 'Find Lawyer', Color(0xFF1A4B8C)),
    _QA(Icons.edit_document, 'E-Sign', Color(0xFF2E6AB4)),
  ];

  // Recent activity (from client-dashboard.tsx)
  static const _activities = [
    _ActivityItem(Icons.edit_document, 'Contract reviewed by AI',
        'Tenancy Agreement — 2 risks found', '2h ago'),
    _ActivityItem(Icons.chat_bubble_outline_rounded, 'New message from Pn. Aishah',
        'Regarding property dispute case', '5h ago'),
    _ActivityItem(Icons.folder_outlined, 'Document shared',
        'IC Copy — expires in 24h', '1d ago'),
  ];

  CaseModel? get _activeCase {
    try {
      return DummyData.cases.firstWhere((c) => c.clientId == widget.user.id);
    } catch (_) {
      return null;
    }
  }

  List<CaseModel> get _myCases => [
        ...DummyData.cases.where((c) => c.clientId == widget.user.id),
        ...DummyData.openCases.where((c) => c.clientId == widget.user.id),
      ];

  Future<void> _openPostCase() async {
    final result = await Navigator.of(context).push<CaseModel>(
      MaterialPageRoute(builder: (_) => PostCaseScreen(poster: widget.user)),
    );
    if (result != null) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final activeCase = _activeCase;

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
                  Text('Selamat Pagi',
                      style: GoogleFonts.inter(
                          color: Colors.grey[500], fontSize: 13)),
                  Text(widget.user.name,
                      style: GoogleFonts.inter(
                          color: _navy,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              GestureDetector(
                onTap: () {},
                child: Stack(
                  children: [
                    Icon(Icons.notifications_none_outlined,
                        color: Colors.grey[500], size: 24),
                    if (_pendingCount > 0)
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                              color: Colors.red, shape: BoxShape.circle),
                          child: Center(
                            child: Text('$_pendingCount',
                                style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700)),
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
          if (_pendingCount > 0) ...[
            GestureDetector(
              onTap: () {},
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFFD4AF37), Color(0xFFE8C84A)]),
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
                          child: const Icon(Icons.how_to_reg_outlined,
                              color: _gold, size: 16),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_pendingCount Lawyer${_pendingCount > 1 ? "s" : ""} Interested!',
                                style: GoogleFonts.inter(
                                    color: _navy,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700),
                              ),
                              Text('Tap to review and approve',
                                  style: GoogleFonts.inter(
                                      color: _navy.withValues(alpha: 0.7),
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: _navy.withValues(alpha: 0.6), size: 20),
                      ],
                    ),
                    // Avatar stack (from client-dashboard.tsx)
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        // Simulated avatar circles
                        ...['AK', 'FI'].map(
                          (init) => Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(right: 4),
                            decoration: BoxDecoration(
                              color: _navy,
                              shape: BoxShape.circle,
                              border: Border.all(color: _gold, width: 2),
                            ),
                            child: Center(
                              child: Text(init,
                                  style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('Aishah, Faizal',
                            style: GoogleFonts.inter(
                                color: _navy.withValues(alpha: 0.8),
                                fontSize: 11)),
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
            Container(
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
                      Text('ACTIVE CASE',
                          style: GoogleFonts.inter(
                              color: _gold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(activeCase.title,
                      style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  Text('Lawyer: Pn. Aishah binti Kamal',
                      style: GoogleFonts.inter(
                          color: Colors.white60, fontSize: 12)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: activeCase.progressPercent / 100,
                            backgroundColor:
                                Colors.white.withValues(alpha: 0.2),
                            valueColor:
                                const AlwaysStoppedAnimation<Color>(_gold),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${activeCase.progressPercent.toInt()}%',
                          style: GoogleFonts.inter(
                              color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('Next hearing: 15 April 2026',
                      style: GoogleFonts.inter(
                          color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],

          // ── Quick Actions (grid-cols-4, from client-dashboard.tsx) ───────
          Text('Quick Actions',
              style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: _quickActions.map((a) {
              return GestureDetector(
                onTap: a.label == 'Post Case' ? _openPostCase : () {},
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
                    Text(a.label,
                        style: GoogleFonts.inter(
                            color: Colors.grey[600], fontSize: 11)),
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
              Text('Recent Activity',
                  style: GoogleFonts.inter(
                      color: _navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              Text('View All',
                  style: GoogleFonts.inter(
                      color: _gold,
                      fontSize: 12,
                      fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 12),
          ..._activities.map((item) => _activityCard(item)),

          // ── My Cases ─────────────────────────────────────────────────────
          if (_myCases.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Cases',
                    style: GoogleFonts.inter(
                        color: _navy,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
                Text('View All',
                    style: GoogleFonts.inter(
                        color: _gold,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 12),
            ..._myCases.take(3).map((c) => _caseCard(c)),
          ],
        ],
      ),
    );
  }

  Widget _activityCard(_ActivityItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
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
                  Text(item.title,
                      style: GoogleFonts.inter(
                          color: _navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(item.subtitle,
                      style: GoogleFonts.inter(
                          color: Colors.grey[500], fontSize: 12),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Row(
              children: [
                Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 3),
                Text(item.time,
                    style: GoogleFonts.inter(
                        color: Colors.grey[400], fontSize: 11)),
              ],
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
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              CaseDetailScreen(caseModel: c, viewer: widget.user),
        )),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
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
                child: const Icon(Icons.gavel_outlined,
                    color: _navy, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        style: GoogleFonts.inter(
                            color: _navy,
                            fontSize: 13,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    Text(c.categoryLabel,
                        style: GoogleFonts.inter(
                            color: Colors.grey[500], fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: c.status == CaseStatus.active
                      ? _navy.withValues(alpha: 0.08)
                      : Colors.grey[100],
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  c.status.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: c.status == CaseStatus.active
                        ? _navy
                        : Colors.grey[500],
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

class _ClientProfileTab extends StatelessWidget {
  final UserModel user;
  const _ClientProfileTab({required this.user});

  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'My Profile',
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Manage your account details and preferences.',
            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
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
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _navy,
                    shape: BoxShape.circle,
                    border: Border.all(color: _gold, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _initials(user.name),
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
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
                        user.name,
                        style: GoogleFonts.inter(
                          color: _navy,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        user.email,
                        style: GoogleFonts.inter(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'CLIENT',
                    style: GoogleFonts.inter(
                      color: _gold,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _sectionCard(
            title: 'Personal information',
            children: [
              _profileRow('Full Name', user.name),
              const SizedBox(height: 8),
              _profileRow('Email', user.email),
              const SizedBox(height: 8),
              _profileRow('Phone', user.phone),
              const SizedBox(height: 8),
              _profileRow('Account ID', user.id),
            ],
          ),
          const SizedBox(height: 14),
          _sectionCard(
            title: 'Security',
            children: [
              _settingRow(Icons.lock_outline, 'Change Password', 'Recommended monthly'),
              const SizedBox(height: 8),
              _settingRow(Icons.verified_user_outlined, 'Two-Factor Authentication', 'Not enabled'),
              const SizedBox(height: 8),
              _settingRow(Icons.notifications_none, 'Notification Preferences', 'Push and email alerts'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _profileRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _settingRow(IconData icon, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: _navy.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 16, color: _navy),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: GoogleFonts.inter(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.chevron_right, color: Colors.grey[400], size: 18),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder for Chat / Vault / Sign tabs
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
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          Text('Coming soon',
              style:
                  GoogleFonts.inter(color: Colors.grey[300], fontSize: 12)),
        ],
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
