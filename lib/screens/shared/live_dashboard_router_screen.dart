import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/user_model.dart';
import '../../repositories/user_repository.dart';
import '../client/client_dashboard_screen.dart';
import '../lawyer/lawyer_dashboard_screen.dart';

class LiveDashboardRouterScreen extends StatelessWidget {
  const LiveDashboardRouterScreen({super.key, required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UserModel?>(
      stream: UserRepository().watchUser(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const _RouterStatusView(
            title: 'Unable to load profile',
            message:
                'Please sign in again. If this continues, verify your network and Firestore rules.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _RouterStatusView(
            title: 'Loading your workspace',
            message: 'Syncing your account and verification status...',
            showProgress: true,
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const _RouterStatusView(
            title: 'Setting up your account',
            message:
                'Your profile is being prepared. This usually takes a few seconds.',
            showProgress: true,
          );
        }

        if (user.role == UserRole.client) {
          return ClientDashboardScreen(user: user);
        }

        return LawyerDashboardScreen(user: user);
      },
    );
  }
}

class _RouterStatusView extends StatelessWidget {
  const _RouterStatusView({
    required this.title,
    required this.message,
    this.showProgress = false,
  });

  final String title;
  final String message;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C1D36),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showProgress) ...[
                const CircularProgressIndicator(color: Color(0xFFCFA92A)),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
