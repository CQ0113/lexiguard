import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/firebase/firebase_initializer.dart';

/// Shown when the app starts without valid Firebase credentials.
class FirebaseSetupRequiredScreen extends StatelessWidget {
  const FirebaseSetupRequiredScreen({super.key});

  static const _navy = Color(0xFF0C1D36);
  static const _gold = Color(0xFFCFA92A);

  @override
  Widget build(BuildContext context) {
    final error = FirebaseInitializer.initializationError;

    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: _navy,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Backend setup required',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'LexiGuard needs Firebase configured on this device before you can sign in. '
                  'Run flutterfire configure locally, then restart the app.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Text(
                      error,
                      style: GoogleFonts.inter(
                        color: _gold,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
