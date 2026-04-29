import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dotted_border/dotted_border.dart';

class VaultUploadCardWidget extends StatelessWidget {
  final bool isUploading;
  final double progress;
  final VoidCallback onPickFile;

  const VaultUploadCardWidget({
    super.key,
    required this.isUploading,
    required this.progress,
    required this.onPickFile,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);

    return GestureDetector(
      onTap: isUploading ? null : onPickFile,
      child: DottedBorder(
        color: const Color(0xFFCBD5E1),
        strokeWidth: 1.5,
        dashPattern: const [6, 4],
        borderType: BorderType.RRect,
        radius: const Radius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isUploading) ...[
                const CircularProgressIndicator(color: Color(0xFF0B2447)),
                const SizedBox(height: 12),
                Text(
                  'Uploading... $pct%',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF0B2447),
                  ),
                ),
              ] else ...[
                const Icon(
                  Icons.upload_file_outlined,
                  color: Color(0xFF64748B),
                  size: 32,
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap to upload documents',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: const Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PDF, JPG, PNG up to 25MB',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}