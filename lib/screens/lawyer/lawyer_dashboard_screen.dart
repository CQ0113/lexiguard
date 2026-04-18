import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/dummy_data.dart';
import '../../models/case_model.dart';
import '../../models/user_model.dart';
import '../shared/case_detail_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LAWYER SHELL — matches MobileShell + all lawyer screens from Figma
// Tabs: CRM | My Cases | Chat | Forms | Docs
// ─────────────────────────────────────────────────────────────────────────────
class LawyerDashboardScreen extends StatefulWidget {
  final UserModel user;
  const LawyerDashboardScreen({super.key, required this.user});

  @override
  State<LawyerDashboardScreen> createState() => _LawyerDashboardScreenState();
}

class _LawyerDashboardScreenState extends State<LawyerDashboardScreen> {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);

  int _currentTab = 0;

  // Lawyer tabs (from mobile-shell.tsx lawyerTabs)
  static const _tabs = [
    _Tab(Icons.grid_view_rounded, 'CRM'),
    _Tab(Icons.work_outline_rounded, 'My Cases'),
    _Tab(Icons.chat_bubble_outline_rounded, 'Chat'),
    _Tab(Icons.description_outlined, 'Forms'),
    _Tab(Icons.folder_outlined, 'Docs'),
  ];

  bool get _isVerifiedLawyer => widget.user.canAccessMarketplace;

  bool _isTabLocked(int index) => !_isVerifiedLawyer && index > 0;

  List<Widget> get _verifiedTabs {
    return [
      _LawyerCRMTab(user: widget.user),
      _LawyerMyCasesTab(user: widget.user),
      _PlaceholderTab('Chat', Icons.chat_bubble_outline_rounded),
      _PlaceholderTab('Forms', Icons.description_outlined),
      _PlaceholderTab('Docs', Icons.folder_outlined),
    ];
  }

  List<Widget> get _sandboxTabs {
    return [
      _VerificationStatusTab(user: widget.user),
      _VerificationLockedTab(user: widget.user),
      _VerificationLockedTab(user: widget.user),
      _VerificationLockedTab(user: widget.user),
      _VerificationLockedTab(user: widget.user),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      // ── Navy top header ─────────────────────────────────────────────────
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
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
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
        index: _currentTab,
        children: _isVerifiedLawyer ? _verifiedTabs : _sandboxTabs,
      ),
      // ── Bottom nav ──────────────────────────────────────────────────────
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
                  onTap: () => setState(() => _currentTab = i),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _isTabLocked(i) ? Icons.lock_outline : _tabs[i].icon,
                          size: 22,
                          color: active
                              ? _navy
                              : (_isTabLocked(i)
                                    ? Colors.grey[350]
                                    : Colors.grey[400]),
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
// CRM TAB — exact match of lawyer-dashboard.tsx
// ─────────────────────────────────────────────────────────────────────────────
class _LawyerCRMTab extends StatelessWidget {
  final UserModel user;
  const _LawyerCRMTab({required this.user});

  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);

  // Stats from lawyer-dashboard.tsx exactly
  static const _stats = [
    _Stat(
      'Active Leads',
      '24',
      '+3 this week',
      Icons.group_outlined,
      Color(0xFF0B2447),
    ),
    _Stat(
      'Pending Docs',
      '8',
      '2 urgent',
      Icons.description_outlined,
      Color(0xFFD4AF37),
    ),
    _Stat(
      'Revenue (MTD)',
      'RM 12.4K',
      '+18%',
      Icons.attach_money,
      Color(0xFF2E8B57),
    ),
    _Stat(
      'Avg Rating',
      '4.9',
      '127 reviews',
      Icons.star_outline,
      Color(0xFFE6A817),
    ),
  ];

  // Leads from lawyer-dashboard.tsx exactly
  static const _leads = [
    _Lead(
      'Tan Wei Ming',
      'Property Dispute — Penang',
      'Hot Lead',
      'Today',
      'high',
    ),
    _Lead(
      'Nurul Izzah',
      'Divorce Proceedings',
      'Follow Up',
      'Yesterday',
      'medium',
    ),
    _Lead('Siva a/l Rajan', 'Employment Termination', 'New', '2d ago', 'low'),
    _Lead(
      'Lim Boon Keat',
      'Criminal Defense — KL',
      'Hot Lead',
      '3d ago',
      'high',
    ),
  ];

  static const _barH = [40, 65, 85, 55, 70, 90, 45];
  static const _barDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  Color _urgencyBg(String u) {
    if (u == 'high') return const Color(0xFFFEF2F2);
    if (u == 'medium') return const Color(0xFFFFFBEB);
    return const Color(0xFFEFF6FF);
  }

  Color _urgencyFg(String u) {
    if (u == 'high') return const Color(0xFFDC2626);
    if (u == 'medium') return const Color(0xFFD97706);
    return const Color(0xFF2563EB);
  }

  List<CaseModel> get _activeCases =>
      DummyData.cases.where((c) => c.lawyerId == user.id).toList();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Greeting ─────────────────────────────────────────────────────
          Text(
            'Welcome back',
            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
          ),
          Text(
            user.name,
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 20),

          // ── New connection banners (green) ────────────────────────────────
          ..._activeCases.map((c) => _connectionCard(context, c)),
          if (_activeCases.isNotEmpty) const SizedBox(height: 10),

          // ── Pending interest status (blue) ────────────────────────────────
          _pendingCard(),
          const SizedBox(height: 6),

          // ── Stats 2×2 grid ────────────────────────────────────────────────
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.65,
            children: _stats.map((s) => _statCard(s)).toList(),
          ),
          const SizedBox(height: 20),

          // ── Lead Pipeline chart ───────────────────────────────────────────
          _pipelineChart(),
          const SizedBox(height: 20),

          // ── Recent Leads ──────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Leads',
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'View All',
                style: GoogleFonts.inter(
                  color: _gold,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._leads.map((l) => _leadCard(l)),
        ],
      ),
    );
  }

  Widget _connectionCard(BuildContext context, CaseModel c) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF22C55E),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.lock_open_outlined,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 11,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'NEW CONNECTION',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF15803D),
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Client revealed their identity',
                        style: GoogleFonts.inter(
                          color: _navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.work_outline,
                            size: 11,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              c.title,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF15803D),
                                fontSize: 11,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.chat_bubble_outline, size: 15),
                    label: Text(
                      'Chat',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CaseDetailScreen(
                        caseModel: c,
                        viewer: DummyData.users.firstWhere(
                          (u) => u.role == UserRole.lawyer,
                        ),
                      ),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _navy,
                    side: const BorderSide(color: _navy),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'View Case',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
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

  Widget _pendingCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.access_time, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '1 pending request',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF1E3A8A),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Awaiting client approval to reveal identity',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF3B82F6),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Color(0xFF93C5FD), size: 16),
        ],
      ),
    );
  }

  Widget _statCard(_Stat s) {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(s.icon, color: s.color, size: 20),
              Text(
                s.change,
                style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.value,
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            s.label,
            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _pipelineChart() {
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
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Lead Pipeline',
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(Icons.bar_chart, color: Colors.grey[400], size: 16),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(_barH.length, (i) {
                final isHighlight = i == 5; // Saturday
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: i < _barH.length - 1 ? 4 : 0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: FractionallySizedBox(
                              heightFactor: _barH[i] / 100,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: isHighlight
                                      ? _gold
                                      : _navy.withValues(
                                          alpha: 0.15 + i * 0.12,
                                        ),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(4),
                                    topRight: Radius.circular(4),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _barDays[i],
                          style: GoogleFonts.inter(
                            color: Colors.grey[400],
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leadCard(_Lead lead) {
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
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead.name,
                      style: GoogleFonts.inter(
                        color: _navy,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      lead.matter,
                      style: GoogleFonts.inter(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _urgencyBg(lead.urgency),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    lead.status,
                    style: GoogleFonts.inter(
                      color: _urgencyFg(lead.urgency),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 4),
                    Text(
                      lead.date,
                      style: GoogleFonts.inter(
                        color: Colors.grey[400],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _navy.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.phone_outlined,
                        color: _navy,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        color: _gold,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MY CASES TAB — exact match of lawyer-my-cases.tsx
// ─────────────────────────────────────────────────────────────────────────────
class _LawyerMyCasesTab extends StatefulWidget {
  final UserModel user;
  const _LawyerMyCasesTab({required this.user});

  @override
  State<_LawyerMyCasesTab> createState() => _LawyerMyCasesTabState();
}

class _LawyerMyCasesTabState extends State<_LawyerMyCasesTab> {
  static const _navy = Color(0xFF0B2447);
  static const _gold = Color(0xFFD4AF37);

  String _activeTab = 'all'; // all | active | pending
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<CaseModel> get _allCases =>
      DummyData.cases.where((c) => c.lawyerId == widget.user.id).toList();

  List<CaseModel> get _openCases => DummyData.openCases;

  // Simulate "connected" (active) and "pending" cases
  List<CaseModel> get _connectedCases => _allCases;
  List<CaseModel> get _pendingCases => _openCases.take(1).toList();

  List<CaseModel> get _filtered {
    List<CaseModel> list;
    if (_activeTab == 'active') {
      list = _connectedCases;
    } else if (_activeTab == 'pending') {
      list = _pendingCases;
    } else {
      list = [..._connectedCases, ..._pendingCases];
    }
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list
        .where(
          (c) =>
              c.title.toLowerCase().contains(q) ||
              c.categoryLabel.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────────────────────
          Text(
            'My Cases',
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Cases you\'ve expressed interest in or are actively working on',
            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 16),

          // ── Search ──────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search cases or clients...',
                hintStyle: GoogleFonts.inter(
                  color: Colors.grey[400],
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey[400],
                  size: 18,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ── Tab filters ─────────────────────────────────────────────────
          Row(
            children: [
              _filterTab(
                'all',
                'All',
                _connectedCases.length + _pendingCases.length,
              ),
              const SizedBox(width: 8),
              _filterTab('active', 'Connected', _connectedCases.length),
              const SizedBox(width: 8),
              _filterTab('pending', 'Pending', _pendingCases.length),
            ],
          ),
          const SizedBox(height: 16),

          // ── Browse more cases CTA (from lawyer-my-cases.tsx) ─────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _gold.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _gold,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: _navy, size: 16),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Browse Open Cases',
                        style: GoogleFonts.inter(
                          color: _navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Find new cases and express interest',
                        style: GoogleFonts.inter(
                          color: _navy.withValues(alpha: 0.6),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: _gold, size: 18),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Case list ───────────────────────────────────────────────────
          if (filtered.isEmpty)
            _emptyState()
          else
            ...filtered.map((c) {
              final isConnected = _connectedCases.contains(c);
              return _myCaseCard(context, c, isConnected);
            }),
        ],
      ),
    );
  }

  Widget _filterTab(String key, String label, int count) {
    final active = _activeTab == key;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _navy : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: active ? null : Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: active ? Colors.white : Colors.grey[500],
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: active
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    color: active ? Colors.white : Colors.grey[500],
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.work_outline,
                size: 32,
                color: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _searchCtrl.text.isNotEmpty
                  ? 'No matching cases'
                  : 'No cases yet',
              style: GoogleFonts.inter(
                color: Colors.grey[500],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _searchCtrl.text.isNotEmpty
                  ? 'Try a different search term'
                  : 'Express interest in cases from the Case Board',
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _myCaseCard(BuildContext context, CaseModel c, bool isConnected) {
    // Status bar config (from lawyer-my-cases.tsx)
    final statusBg = isConnected
        ? const Color(0xFFF0FDF4)
        : const Color(0xFFFFFBEB);
    final statusBorder = isConnected
        ? const Color(0xFFBBF7D0)
        : const Color(0xFFFDE68A);
    final statusText = isConnected
        ? const Color(0xFF16A34A)
        : const Color(0xFFD97706);
    final statusLabel = isConnected ? 'CONNECTED' : 'AWAITING';
    final statusIcon = isConnected
        ? Icons.lock_open_outlined
        : Icons.access_time;

    // Urgency
    Color urgencyBg, urgencyFg;
    String urgencyLabel;
    switch (c.urgency) {
      case CaseUrgency.high:
        urgencyBg = const Color(0xFFFEF2F2);
        urgencyFg = const Color(0xFFEF4444);
        urgencyLabel = 'HIGH';
        break;
      case CaseUrgency.medium:
        urgencyBg = const Color(0xFFFFFBEB);
        urgencyFg = const Color(0xFFF59E0B);
        urgencyLabel = 'MEDIUM';
        break;
      case CaseUrgency.low:
        urgencyBg = const Color(0xFFEFF6FF);
        urgencyFg = const Color(0xFF3B82F6);
        urgencyLabel = 'LOW';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
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
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Status bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: statusBg,
                border: Border(bottom: BorderSide(color: statusBorder)),
              ),
              child: Row(
                children: [
                  Icon(statusIcon, color: statusText, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: GoogleFonts.inter(
                      color: statusText,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Case info
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isConnected ? _navy : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: isConnected
                            ? Center(
                                child: Text(
                                  c.clientId.substring(0, 2).toUpperCase(),
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : Icon(
                                Icons.lock_outline,
                                color: Colors.grey[400],
                                size: 20,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConnected
                                  ? DummyData.users
                                        .firstWhere(
                                          (u) => u.id == c.clientId,
                                          orElse: () => DummyData.users.first,
                                        )
                                        .name
                                  : 'CLIENT-${c.id.hashCode.abs() % 10000}',
                              style: GoogleFonts.inter(
                                color: _navy,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              c.title,
                              style: GoogleFonts.inter(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Tags
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          c.categoryLabel,
                          style: GoogleFonts.inter(
                            color: _gold,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: urgencyBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          urgencyLabel,
                          style: GoogleFonts.inter(
                            color: urgencyFg,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Contracts CTA (if connected)
                  if (isConnected) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _gold.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _gold.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.edit_document,
                            color: _gold,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Send Contract',
                              style: GoogleFonts.inter(
                                color: _navy,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: _gold,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      if (isConnected) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {},
                            icon: const Icon(
                              Icons.chat_bubble_outline,
                              size: 15,
                            ),
                            label: Text(
                              'Chat',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navy,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.phone_outlined, size: 15),
                          label: Text(
                            'Call',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF16A34A),
                            side: const BorderSide(color: Color(0xFFBBF7D0)),
                            backgroundColor: const Color(0xFFF0FDF4),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ] else
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.access_time,
                                  color: Color(0xFFD97706),
                                  size: 15,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Awaiting Client Approval',
                                  style: GoogleFonts.inter(
                                    color: const Color(0xFFD97706),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VerificationStatusTab extends StatelessWidget {
  final UserModel user;
  const _VerificationStatusTab({required this.user});

  static const _navy = Color(0xFF0B2447);

  String _titleForStatus() {
    switch (user.verificationStatus) {
      case VerificationStatus.pending:
      case VerificationStatus.manualReviewRequired:
        return 'Verification in progress';
      case VerificationStatus.rejected:
        return 'Verification needs attention';
      case VerificationStatus.reverificationDue:
        return 'Reverification required';
      case VerificationStatus.suspended:
        return 'Account temporarily suspended';
      case VerificationStatus.unsubmitted:
        return 'Verification not started';
      case VerificationStatus.autoVerified:
        return 'Verified lawyer account';
    }
  }

  String _messageForStatus() {
    switch (user.verificationStatus) {
      case VerificationStatus.pending:
        return 'Your submission was received. We are now validating your details against bar records.';
      case VerificationStatus.manualReviewRequired:
        return 'Automated verification was inconclusive. Our team is reviewing your submission manually.';
      case VerificationStatus.rejected:
        return 'Submitted details did not match records. Please resubmit with your exact registered legal name and bar number.';
      case VerificationStatus.reverificationDue:
        return 'Your last verification is outdated. Complete reverification to regain full marketplace access.';
      case VerificationStatus.suspended:
        return 'Marketplace access is paused due to a trust and safety flag. Contact support if this looks incorrect.';
      case VerificationStatus.unsubmitted:
        return 'Submit your legal profile and bar details to begin verification.';
      case VerificationStatus.autoVerified:
        return 'Your verification is complete and marketplace access is enabled.';
    }
  }

  Color _statusColor() {
    switch (user.verificationStatus) {
      case VerificationStatus.pending:
      case VerificationStatus.manualReviewRequired:
      case VerificationStatus.reverificationDue:
        return const Color(0xFF1D4ED8);
      case VerificationStatus.rejected:
      case VerificationStatus.suspended:
        return const Color(0xFFB91C1C);
      case VerificationStatus.unsubmitted:
        return const Color(0xFFD97706);
      case VerificationStatus.autoVerified:
        return const Color(0xFF15803D);
    }
  }

  IconData _statusIcon() {
    switch (user.verificationStatus) {
      case VerificationStatus.pending:
      case VerificationStatus.manualReviewRequired:
        return Icons.hourglass_top_rounded;
      case VerificationStatus.rejected:
      case VerificationStatus.suspended:
        return Icons.error_outline;
      case VerificationStatus.reverificationDue:
        return Icons.update_outlined;
      case VerificationStatus.unsubmitted:
        return Icons.assignment_late_outlined;
      case VerificationStatus.autoVerified:
        return Icons.verified;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Verification Center',
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            'Sandbox mode is active until verification is approved.',
            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 13),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_statusIcon(), color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _titleForStatus(),
                        style: GoogleFonts.inter(
                          color: _navy,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _messageForStatus(),
                        style: GoogleFonts.inter(
                          color: Colors.grey[700],
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current profile details',
                  style: GoogleFonts.inter(
                    color: _navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _profileRow('Legal Name', user.legalFullName ?? user.name),
                const SizedBox(height: 8),
                _profileRow('Bar Number', user.barNumber ?? 'Not provided'),
                const SizedBox(height: 8),
                _profileRow('Firm', user.firmName ?? 'Not provided'),
                const SizedBox(height: 8),
                _profileRow('Jurisdiction', user.jurisdiction ?? 'peninsular'),
                const SizedBox(height: 8),
                _profileRow('Status', user.verificationStatus.label),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFEEF2FF),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFC7D2FE)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Color(0xFF3730A3),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Complete verification to unlock marketplace access and client communication features.',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF312E81),
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          ),
        ),
      ],
    );
  }
}

class _VerificationLockedTab extends StatelessWidget {
  final UserModel user;
  const _VerificationLockedTab({required this.user});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Icon(
                Icons.lock_outline,
                color: Color(0xFFD97706),
                size: 30,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Access locked',
              style: GoogleFonts.inter(
                color: const Color(0xFF0B2447),
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Complete verification to unlock this section.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.grey[600],
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                'Current status: ${user.verificationStatus.label}',
                style: GoogleFonts.inter(
                  color: const Color(0xFF1E3A8A),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared placeholder tab for unimplemented tabs
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
// Data classes
// ─────────────────────────────────────────────────────────────────────────────
class _Tab {
  final IconData icon;
  final String label;
  const _Tab(this.icon, this.label);
}

class _Stat {
  final String label, value, change;
  final IconData icon;
  final Color color;
  const _Stat(this.label, this.value, this.change, this.icon, this.color);
}

class _Lead {
  final String name, matter, status, date, urgency;
  const _Lead(this.name, this.matter, this.status, this.date, this.urgency);
}
