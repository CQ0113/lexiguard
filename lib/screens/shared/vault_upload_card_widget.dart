import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class VaultUploadCardWidget extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isUploading;
  final double progress;
  final VoidCallback onPickFile;
  final Widget? extraChild;

  const VaultUploadCardWidget({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isUploading,
    required this.progress,
    required this.onPickFile,
    this.extraChild,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.folder_outlined, color: Color(0xFF0B2447)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: const Color(0xFF0B2447),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF6B7280),
            ),
          ),
          if (extraChild != null) ...[
            const SizedBox(height: 12),
            extraChild!,
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isUploading ? null : onPickFile,
              icon: const Icon(Icons.upload_file_rounded),
              label: Text(
                isUploading ? 'Uploading...' : 'Choose File',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B2447),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          if (isUploading) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress > 0 ? progress : null,
                minHeight: 8,
                backgroundColor: const Color(0xFFE5E7EB),
                color: const Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload progress: $pct%',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF6B7280),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
