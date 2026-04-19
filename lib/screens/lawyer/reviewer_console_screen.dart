import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReviewerConsoleScreen extends StatefulWidget {
  const ReviewerConsoleScreen({super.key});

  @override
  State<ReviewerConsoleScreen> createState() => _ReviewerConsoleScreenState();
}

class _ReviewerConsoleScreenState extends State<ReviewerConsoleScreen> {
  final Set<String> _inFlightDecisions = <String>{};

  Stream<QuerySnapshot<Map<String, dynamic>>> get _queueStream {
    return FirebaseFirestore.instance
        .collection('verification_requests')
        .where('queueStatus', isEqualTo: 'queued')
        .orderBy('updatedAt', descending: true)
        .limit(40)
        .snapshots();
  }

  Future<void> _reviewRequest({
    required String uid,
    required String action,
  }) async {
    final noteController = TextEditingController();

    final note = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            action == 'approve'
                ? 'Approve Verification'
                : 'Reject Verification',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700),
          ),
          content: TextField(
            controller: noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Optional reviewer note',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(noteController.text.trim());
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    noteController.dispose();

    if (note == null) {
      return;
    }

    setState(() => _inFlightDecisions.add(uid));

    try {
      await FirebaseFunctions.instance
          .httpsCallable('reviewVerificationRequest')
          .call({'uid': uid, 'action': action, 'reviewerNote': note});

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'approve'
                ? 'Verification approved for $uid.'
                : 'Verification rejected for $uid.',
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: action == 'approve'
              ? const Color(0xFF15803D)
              : const Color(0xFFB91C1C),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit decision: $error'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _inFlightDecisions.remove(uid));
      }
    }
  }

  Future<bool> _hasReviewerClaim() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final token = await user.getIdTokenResult();
    return token.claims?['reviewer'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Reviewer Console',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<bool>(
        future: _hasReviewerClaim(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (authSnapshot.data != true) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48, color: Color(0xFF6B7280)),
                    const SizedBox(height: 16),
                    Text(
                      'Access Denied',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0B2447),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'You do not have the reviewer role required to access this console.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF6B7280)),
                    ),
                  ],
                ),
              ),
            );
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _queueStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Unable to load queue: ${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: const Color(0xFFB91C1C)),
                ),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No queued verification requests.',
                style: GoogleFonts.inter(fontSize: 14),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final uid = (data['uid'] as String?) ?? docs[index].id;
              final legalName =
                  (data['legalFullName'] as String?) ?? 'Unknown legal name';
              final firmName = (data['firmName'] as String?) ?? 'Unknown firm';
              final jurisdiction =
                  (data['jurisdiction'] as String?) ?? 'unknown';
              final status =
                  (data['verificationStatus'] as String?) ?? 'pending';
              final reason = (data['queueReason'] as String?) ?? 'queued';
              final isSubmitting = _inFlightDecisions.contains(uid);

              return Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
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
                    Text(
                      legalName,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0B2447),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'UID: $uid',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Firm: $firmName',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Jurisdiction: $jurisdiction',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current status: $status',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Queue reason: $reason',
                      style: GoogleFonts.inter(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () => _reviewRequest(
                                    uid: uid,
                                    action: 'reject',
                                  ),
                            icon: const Icon(Icons.block_outlined, size: 16),
                            label: const Text('Reject'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isSubmitting
                                ? null
                                : () => _reviewRequest(
                                    uid: uid,
                                    action: 'approve',
                                  ),
                            icon: const Icon(Icons.verified_outlined, size: 16),
                            label: Text(isSubmitting ? 'Saving...' : 'Approve'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemCount: docs.length,
          );
        },
      );
        },
      ),
    );
  }
}
