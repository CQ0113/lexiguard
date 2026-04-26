import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/vault_document_model.dart';

class VaultDocumentTileWidget extends StatelessWidget {
  final VaultDocumentModel document;
  final bool canDelete;
  final VoidCallback? onDelete;

  const VaultDocumentTileWidget({
    super.key,
    required this.document,
    required this.canDelete,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final createdLabel = document.createdAt == null
        ? 'Pending timestamp'
        : DateFormat('dd MMM yyyy, h:mm a').format(document.createdAt!);
    final sizeKb = document.sizeBytes == null
        ? null
        : (document.sizeBytes! / 1024).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.description_outlined,
              color: Color(0xFF0B2447),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  document.fileName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: const Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Uploaded: $createdLabel',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                if (sizeKb != null)
                  Text(
                    'Size: $sizeKb KB',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
              ],
            ),
          ),
          if (canDelete)
            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete file',
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Color(0xFFB91C1C),
              ),
            ),
        ],
      ),
    );
  }
}
