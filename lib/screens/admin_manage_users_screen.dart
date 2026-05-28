import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/firebase/firebase_initializer.dart';
import '../data/dummy_data.dart';
import '../models/user_model.dart';
import 'login_screen.dart';

enum _AdminReviewStage { toReview, done }

class _LawyerReviewItem {
  const _LawyerReviewItem({required this.lawyer, this.adminReviewStage});

  final UserModel lawyer;
  final String? adminReviewStage;
}

class AdminManageUsersScreen extends StatefulWidget {
  const AdminManageUsersScreen({super.key});

  @override
  State<AdminManageUsersScreen> createState() => _AdminManageUsersScreenState();
}

class _AdminManageUsersScreenState extends State<AdminManageUsersScreen> {
  final Color _primaryBlue = const Color(0xFF0C1D36);
  final Color _goldAccent = const Color(0xFFCFA92A);
  final ScrollController _boardScrollController = ScrollController();
  final Set<String> _decisionInFlight = <String>{};

  Stream<QuerySnapshot<Map<String, dynamic>>> get _lawyerStream {
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'lawyer')
        .snapshots();
  }

  Future<void> _moveLawyer(UserModel lawyer, _AdminReviewStage stage) async {
    if (!FirebaseInitializer.isReady || lawyer.id.startsWith('lawyer_')) {
      _showMessage('Demo data cannot be updated.');
      return;
    }

    final payload = <String, dynamic>{
      'adminReviewStage': _stageWire(stage),
      'adminReviewUpdatedAt': FieldValue.serverTimestamp(),
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(lawyer.id)
          .set(payload, SetOptions(merge: true));
    } catch (error) {
      _showMessage('Could not update lawyer review status: $error');
      return;
    }

    _showMessage(
      '${lawyer.legalFullName ?? lawyer.name} moved to ${_stageTitle(stage)}.',
    );
  }

  Future<void> _decideLawyerVerification({
    required UserModel lawyer,
    required bool approved,
  }) async {
    if (!FirebaseInitializer.isReady || lawyer.id.startsWith('lawyer_')) {
      _showMessage('Demo data cannot be updated.');
      return;
    }

    setState(() => _decisionInFlight.add(lawyer.id));

    final payload = <String, dynamic>{
      'adminReviewStage': _stageWire(_AdminReviewStage.done),
      'adminReviewDecision': approved ? 'approved' : 'rejected',
      'adminReviewUpdatedAt': FieldValue.serverTimestamp(),
      'adminReviewedAt': FieldValue.serverTimestamp(),
      'barCouncilVerified': approved,
      'verificationBadge': approved,
      'verificationBadgeVisible': approved,
      'verificationStatus': approved
          ? VerificationStatus.autoVerified.wireValue
          : VerificationStatus.rejected.wireValue,
      if (approved) ...{
        'verifiedAt': FieldValue.serverTimestamp(),
        'lastVerifiedAt': FieldValue.serverTimestamp(),
      } else ...{
        'verifiedAt': FieldValue.delete(),
        'lastVerifiedAt': FieldValue.delete(),
        'rejectedAt': FieldValue.serverTimestamp(),
      },
    };

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(lawyer.id)
          .set(payload, SetOptions(merge: true));
    } catch (error) {
      _showMessage('Could not save review decision: $error');
      return;
    } finally {
      if (mounted) {
        setState(() => _decisionInFlight.remove(lawyer.id));
      }
    }

    _showMessage(
      '${lawyer.legalFullName ?? lawyer.name} ${approved ? 'approved' : 'rejected'} and moved to Done.',
    );
  }

  Future<void> _signOut() async {
    if (FirebaseInitializer.isReady) {
      await FirebaseAuth.instance.signOut();
    }
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (_) => false,
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _boardScrollController.dispose();
    super.dispose();
  }

  List<_LawyerReviewItem> _lawyersFromSnapshot(
    QuerySnapshot<Map<String, dynamic>>? snapshot,
  ) {
    final docs = snapshot?.docs ?? [];
    if (docs.isEmpty) {
      return DummyData.users
          .where((user) => user.role == UserRole.lawyer)
          .map((user) => _LawyerReviewItem(lawyer: user))
          .toList();
    }

    return docs.map((doc) {
      final data = doc.data();
      return _LawyerReviewItem(
        lawyer: UserModel.fromFirestore(doc),
        adminReviewStage: data['adminReviewStage']?.toString(),
      );
    }).toList();
  }

  _AdminReviewStage _stageFor(_LawyerReviewItem item) {
    final lawyer = item.lawyer;
    final dataStage = _stageFromWire(item.adminReviewStage);
    if (dataStage != null) return dataStage;

    if (lawyer.verificationStatus == VerificationStatus.autoVerified) {
      return _AdminReviewStage.done;
    }
    if (lawyer.verificationStatus == VerificationStatus.rejected) {
      return _AdminReviewStage.done;
    }
    return _AdminReviewStage.toReview;
  }

  _AdminReviewStage? _stageFromWire(String? stage) {
    switch (stage) {
      case 'to_review':
        return _AdminReviewStage.toReview;
      case 'in_review':
        return _AdminReviewStage.toReview;
      case 'done':
        return _AdminReviewStage.done;
      default:
        return null;
    }
  }

  String _stageWire(_AdminReviewStage stage) {
    switch (stage) {
      case _AdminReviewStage.toReview:
        return 'to_review';
      case _AdminReviewStage.done:
        return 'done';
    }
  }

  String _stageTitle(_AdminReviewStage stage) {
    switch (stage) {
      case _AdminReviewStage.toReview:
        return 'To Review';
      case _AdminReviewStage.done:
        return 'Done';
    }
  }

  Color _stageColor(_AdminReviewStage stage) {
    switch (stage) {
      case _AdminReviewStage.toReview:
        return const Color(0xFFF59E0B);
      case _AdminReviewStage.done:
        return const Color(0xFF16A34A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primaryBlue,
        elevation: 0,
        title: Text(
          'Manage Users',
          style: GoogleFonts.inter(fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Logout',
            onPressed: _signOut,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseInitializer.isReady ? _lawyerStream : null,
        builder: (context, snapshot) {
          final lawyerItems = _lawyersFromSnapshot(snapshot.data);
          final grouped = <_AdminReviewStage, List<UserModel>>{
            _AdminReviewStage.toReview: [],
            _AdminReviewStage.done: [],
          };

          for (final item in lawyerItems) {
            grouped[_stageFor(item)]!.add(item.lawyer);
          }

          final hasError = snapshot.hasError;

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                color: Colors.white,
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Malaysian Bar verification board',
                      style: GoogleFonts.inter(
                        color: _primaryBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Chip(
                      avatar: Icon(
                        hasError ? Icons.cloud_off_outlined : Icons.balance,
                        color: _goldAccent,
                        size: 18,
                      ),
                      label: Text(
                        hasError
                            ? 'Showing demo lawyers'
                            : '${lawyerItems.length} lawyer registrations',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: const Color(0xFFFFFBEB),
                      side: const BorderSide(color: Color(0xFFFDE68A)),
                    ),
                  ],
                ),
              ),
              if (hasError)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: const Color(0xFFFEF2F2),
                  child: Text(
                    'Unable to load Firebase users: ${snapshot.error}. Make sure the admin account exists and Firestore rules are deployed.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF991B1B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final useRows = constraints.maxWidth < 840;
                    final columns = _AdminReviewStage.values.map((stage) {
                      return _KanbanColumn(
                        title: _stageTitle(stage),
                        color: _stageColor(stage),
                        lawyers: grouped[stage]!,
                        onMove: _moveLawyer,
                        onDecide: _decideLawyerVerification,
                        stage: stage,
                        busyLawyerIds: _decisionInFlight,
                        scrollInternally: !useRows,
                      );
                    }).toList();

                    if (useRows) {
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemBuilder: (context, index) => columns[index],
                        separatorBuilder: (_, _) => const SizedBox(height: 16),
                        itemCount: columns.length,
                      );
                    }

                    final boardWidth = constraints.maxWidth < 760
                        ? 760.0
                        : constraints.maxWidth;

                    return Scrollbar(
                      controller: _boardScrollController,
                      thumbVisibility: true,
                      child: SingleChildScrollView(
                        controller: _boardScrollController,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: boardWidth,
                          height: constraints.maxHeight,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final column in columns)
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: column,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.title,
    required this.color,
    required this.lawyers,
    required this.onMove,
    required this.onDecide,
    required this.stage,
    required this.busyLawyerIds,
    required this.scrollInternally,
  });

  final String title;
  final Color color;
  final List<UserModel> lawyers;
  final Future<void> Function(UserModel lawyer, _AdminReviewStage stage) onMove;
  final Future<void> Function({
    required UserModel lawyer,
    required bool approved,
  })
  onDecide;
  final _AdminReviewStage stage;
  final Set<String> busyLawyerIds;
  final bool scrollInternally;

  @override
  Widget build(BuildContext context) {
    final cardList = ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      primary: false,
      shrinkWrap: !scrollInternally,
      physics: scrollInternally
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final lawyer = lawyers[index];
        return _LawyerReviewCard(
          lawyer: lawyer,
          stage: stage,
          isBusy: busyLawyerIds.contains(lawyer.id),
          onMove: onMove,
          onDecide: onDecide,
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemCount: lawyers.length,
    );

    return Container(
      constraints: const BoxConstraints(minHeight: 240),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0C1D36),
                    ),
                  ),
                ),
                Text(
                  lawyers.length.toString(),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (lawyers.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'No lawyers here.',
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 13,
                ),
              ),
            )
          else if (scrollInternally)
            Expanded(child: cardList)
          else
            cardList,
        ],
      ),
    );
  }
}

class _LawyerReviewCard extends StatelessWidget {
  const _LawyerReviewCard({
    required this.lawyer,
    required this.stage,
    required this.isBusy,
    required this.onMove,
    required this.onDecide,
  });

  final UserModel lawyer;
  final _AdminReviewStage stage;
  final bool isBusy;
  final Future<void> Function(UserModel lawyer, _AdminReviewStage stage) onMove;
  final Future<void> Function({
    required UserModel lawyer,
    required bool approved,
  })
  onDecide;

  @override
  Widget build(BuildContext context) {
    final name = lawyer.legalFullName?.isNotEmpty == true
        ? lawyer.legalFullName!
        : lawyer.name;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF0C1D36),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (stage == _AdminReviewStage.done)
                PopupMenuButton<_AdminReviewStage>(
                  tooltip: 'Move',
                  onSelected: (stage) => onMove(lawyer, stage),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _AdminReviewStage.toReview,
                      child: Text('Move to To Review'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          _InfoLine(icon: Icons.email_outlined, text: lawyer.email),
          _InfoLine(
            icon: Icons.business_outlined,
            text: lawyer.firmName ?? 'Firm not provided',
          ),
          _InfoLine(
            icon: Icons.badge_outlined,
            text: lawyer.barNumber ?? 'Bar number not provided',
          ),
          _InfoLine(
            icon: Icons.location_on_outlined,
            text:
                '${lawyer.practiceCity ?? 'City not provided'}, ${lawyer.practiceState ?? 'State not provided'}',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusPill(text: lawyer.verificationStatus.label),
              _StatusPill(text: lawyer.jurisdiction ?? 'unknown jurisdiction'),
            ],
          ),
          if (stage == _AdminReviewStage.toReview) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => onDecide(lawyer: lawyer, approved: false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFB91C1C),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: Text(
                      'Reject',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isBusy
                        ? null
                        : () => onDecide(lawyer: lawyer, approved: true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF15803D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      isBusy ? 'Saving' : 'Approve',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF64748B)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: const Color(0xFF475569),
                fontSize: 12,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: const Color(0xFF475569),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
