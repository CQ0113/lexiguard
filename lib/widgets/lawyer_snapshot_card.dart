import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/connection_request_model.dart' show LawyerSnapshot;

/// Shared card widget that renders a [LawyerSnapshot].
///
/// Two display modes:
/// - [compact] = false (default): full card with all fields visible — used in
///   the express-interest sheet preview and the LawyerProfileSheet header.
/// - [compact] = true: list-tile style (avatar + name + firm on one row, no
///   expanded metadata) — used in connection-request list cards.
///
/// Optionally tappable via [onTap].
class LawyerSnapshotCard extends StatelessWidget {
  const LawyerSnapshotCard({
    super.key,
    required this.snapshot,
    this.compact = false,
    this.onTap,
  });

  final LawyerSnapshot snapshot;
  final bool compact;
  final VoidCallback? onTap;

  // ── Design tokens ──────────────────────────────────────────────────────────
  static const Color _navy = Color(0xFF0C1D36);
  static const Color _gold = Color(0xFFCFA92A);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: compact ? _buildCompact() : _buildFull(),
    );
  }

  // ── Full card ──────────────────────────────────────────────────────────────

  Widget _buildFull() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatarRow(size: 48),
        const SizedBox(height: 10),
        _buildMetaChips(),
        if (snapshot.verificationStatus == 'auto_verified') ...[
          const SizedBox(height: 8),
          _buildVerifiedBadge(),
        ],
        if (snapshot.barNumber != null) ...[
          const SizedBox(height: 6),
          Text(
            'BC# ${snapshot.barNumber}',
            style: GoogleFonts.inter(
              color: Colors.grey[400],
              fontSize: 11,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }

  // ── Compact list-tile ──────────────────────────────────────────────────────

  Widget _buildCompact() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _avatar(size: 40),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      snapshot.name,
                      style: GoogleFonts.inter(
                        color: _navy,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (snapshot.verificationStatus == 'auto_verified') ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, color: _gold, size: 13),
                  ],
                ],
              ),
              if (snapshot.firmName != null)
                Text(
                  snapshot.firmName!,
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildAvatarRow({required double size}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _avatar(size: size),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                snapshot.name,
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (snapshot.firmName != null) ...[
                const SizedBox(height: 2),
                Text(
                  snapshot.firmName!,
                  style: GoogleFonts.inter(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _avatar({required double size}) {
    final initial =
        snapshot.name.isNotEmpty ? snapshot.name[0].toUpperCase() : '?';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _gold, width: 2),
        color: _navy,
        image: snapshot.avatarUrl != null
            ? DecorationImage(
                image: NetworkImage(snapshot.avatarUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: snapshot.avatarUrl == null
          ? Center(
              child: Text(
                initial,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.38,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildMetaChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        if (snapshot.specialization != null) _pill(snapshot.specialization!),
        if (snapshot.yearsExperience != null)
          _pill('${snapshot.yearsExperience} yrs exp'),
        if (snapshot.rating != null)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: _gold, size: 14),
              const SizedBox(width: 2),
              Text(
                snapshot.rating!.toStringAsFixed(1),
                style: GoogleFonts.inter(
                  color: _navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        if (snapshot.jurisdiction != null) _pill(snapshot.jurisdiction!),
      ],
    );
  }

  Widget _buildVerifiedBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.verified_rounded, color: _gold, size: 14),
        const SizedBox(width: 4),
        Text(
          'Verified',
          style: GoogleFonts.inter(
            color: _gold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _navy.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: _navy,
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
