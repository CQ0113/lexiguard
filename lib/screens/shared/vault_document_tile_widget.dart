import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/vault_document_model.dart';

class VaultDocumentTileWidget extends StatelessWidget {
  final VaultDocumentModel document;
  final VoidCallback onTap;
  final Widget? trailing; 
  final String? extraSubtitle;

  const VaultDocumentTileWidget({
    super.key,
    required this.document,
    required this.onTap,
    this.trailing,
    this.extraSubtitle,
  });

  @override
  Widget build(BuildContext context) {
    // Format date like "28 Mar 2026"
    final createdLabel = document.createdAt == null
        ? 'Pending'
        : DateFormat('dd MMM yyyy').format(document.createdAt!);
    
    // Format size into MB or KB
    String sizeLabel = '';
    if (document.sizeBytes != null) {
      if (document.sizeBytes! >= 1024 * 1024) {
        sizeLabel = '${(document.sizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        sizeLabel = '${(document.sizeBytes! / 1024).toStringAsFixed(0)} KB';
      }
    }

    final isImage = document.fileName.toLowerCase().endsWith('.png') || 
                    document.fileName.toLowerCase().endsWith('.jpg') || 
                    document.fileName.toLowerCase().endsWith('.jpeg');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(
                isImage ? Icons.image_outlined : Icons.description_outlined,
                color: const Color(0xFF0B2447),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${sizeLabel.isNotEmpty ? "$sizeLabel  •  " : ""}$createdLabel',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  if (extraSubtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      extraSubtitle!,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF94A3B8),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
