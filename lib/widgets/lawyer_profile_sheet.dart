import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/connection_request_model.dart' show LawyerSnapshot;
import 'network_avatar.dart';

/// Fullscreen-ish modal that shows the full [LawyerSnapshot] profile.
///
/// Purely informational — no actions, no approve/decline.
///
/// Usage:
/// ```dart
/// await LawyerProfileSheet.show(context, snapshot: req.lawyerSnapshot);
/// ```
class LawyerProfileSheet {
  LawyerProfileSheet._();

  static Future<void> show(
    BuildContext context, {
    required LawyerSnapshot snapshot,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LawyerProfileSheetContent(snapshot: snapshot),
    );
  }
}

class _LawyerProfileSheetContent extends StatelessWidget {
  const _LawyerProfileSheetContent({required this.snapshot});

  final LawyerSnapshot snapshot;

  static const Color _navy = Color(0xFF0C1D36);
  static const Color _gold = Color(0xFFCFA92A);

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: EdgeInsets.zero,
                  children: [
                    _buildHeader(context),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [_buildInfoSection()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Navy gradient header ───────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final isVerified = snapshot.verificationStatus == 'auto_verified';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0C1D36), Color(0xFF1A3660)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          // Close button top-right
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white70, size: 22),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 4),
              // Large avatar
              NetworkAvatar(
                size: 80,
                name: snapshot.name,
                url: snapshot.avatarUrl,
                borderColor: _gold,
                borderWidth: 3,
                backgroundColor: Colors.white.withValues(alpha: 0.15),
                fontSize: 30,
              ),
              const SizedBox(height: 14),
              // Name
              Text(
                snapshot.name,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (snapshot.firmName != null) ...[
                const SizedBox(height: 4),
                Text(
                  snapshot.firmName!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
                ),
              ],
              if (isVerified) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _gold.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        color: _gold,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Malaysian Bar Verified',
                        style: GoogleFonts.inter(
                          color: _gold,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ── Info section ──────────────────────────────────────────────────────────

  Widget _buildInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chips row
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (snapshot.specialization != null)
              _chip(Icons.balance_outlined, snapshot.specialization!),
            if (snapshot.jurisdiction != null)
              _chip(Icons.location_on_outlined, snapshot.jurisdiction!),
            if (snapshot.yearsExperience != null)
              _chip(
                Icons.work_history_outlined,
                '${snapshot.yearsExperience} yrs experience',
              ),
          ],
        ),
        if (snapshot.rating != null) ...[
          const SizedBox(height: 16),
          _sectionLabel('Rating'),
          const SizedBox(height: 6),
          Row(
            children: [
              ...List.generate(5, (i) {
                return Icon(
                  i < snapshot.rating!.round()
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: _gold,
                  size: 20,
                );
              }),
              const SizedBox(width: 6),
              Text(
                snapshot.rating!.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
        if (snapshot.barNumber != null) ...[
          const SizedBox(height: 16),
          _sectionLabel('Bar Council Number'),
          const SizedBox(height: 6),
          Text(
            'BC# ${snapshot.barNumber}',
            style: GoogleFonts.inter(color: Colors.grey[600], fontSize: 13),
          ),
        ],
        const SizedBox(height: 24),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(
            'Profile information is captured at the time of the connection request and may not reflect the most recent updates.',
            style: GoogleFonts.inter(color: Colors.grey[500], fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        color: Colors.grey[500],
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _navy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _navy, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _navy,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
