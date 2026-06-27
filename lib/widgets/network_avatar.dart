import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A circular avatar that loads a [url] via [Image.network] and gracefully
/// falls back to an initial-letter placeholder on any load error (e.g. CORS
/// on Flutter Web).
///
/// Using [Image.network] with an [errorBuilder] is the correct approach for
/// Flutter Web because [DecorationImage] on a [BoxDecoration] does NOT expose
/// an error-callback, so any network failure (statusCode 0 / CORS) becomes an
/// uncaught exception that cascades into `!isDisposed` assertion errors.
class NetworkAvatar extends StatelessWidget {
  const NetworkAvatar({
    super.key,
    required this.size,
    required this.name,
    this.url,
    this.borderColor,
    this.borderWidth = 2.0,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
  });

  final double size;
  final String name;
  final String? url;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;

  String get _initial => name.isNotEmpty ? name[0].toUpperCase() : '?';

  Widget _placeholder() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? const Color(0xFF0C1D36),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      child: Center(
        child: Text(
          _initial,
          style: GoogleFonts.inter(
            color: textColor ?? Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: fontSize ?? size * 0.38,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveUrl = url;
    if (effectiveUrl == null || effectiveUrl.isEmpty) {
      return _placeholder();
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? const Color(0xFF0C1D36),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: borderWidth)
            : null,
      ),
      child: ClipOval(
        child: Image.network(
          effectiveUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _placeholder(),
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return _placeholder();
          },
        ),
      ),
    );
  }
}
