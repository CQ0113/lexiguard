import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/client/client_dashboard_screen.dart';
import 'screens/lawyer/lawyer_dashboard_screen.dart';
import 'services/user_service.dart';
import 'models/user_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LexiGuard Malaysia',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0C1D36)),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      home: const AuthGate(),
    );
  }
}

/// Listens to Firebase auth state and routes the user appropriately.
/// - Signed out → LoginScreen
/// - Signed in → fetch Firestore user → correct Dashboard
/// - Loading → splash/spinner
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still connecting
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        // Signed out
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // Signed in — load their Firestore profile
        return _DashboardLoader(uid: snapshot.data!.uid);
      },
    );
  }
}

/// Fetches the user's Firestore document and routes to the correct dashboard.
class _DashboardLoader extends StatelessWidget {
  final String uid;
  const _DashboardLoader({required this.uid});

  @override
  Widget build(BuildContext context) {
    final userService = UserService();
    return FutureBuilder<UserModel?>(
      future: userService.getUserById(uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _SplashScreen();
        }

        if (snap.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFF0C1D36),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.redAccent, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load profile. This might occur if this is a newly recreated Firebase project and Firestore Database has not been initialized yet.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Error: ${snap.error}',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCFA92A)),
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: Text('Sign Out', style: GoogleFonts.inter(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // If user doc not found (edge case)
        if (!snap.hasData || snap.data == null) {
          return Scaffold(
            backgroundColor: const Color(0xFF0C1D36),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.person_off_outlined, color: Colors.amber, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      'Account Details Missing',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You are logged into Firebase Authentication, but your Firestore user document is missing.\n\nThis happens if you manually created the account in the Firebase Console without using the app\'s Register screen, or if Firestore was wiped out.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFCFA92A)),
                      onPressed: () => FirebaseAuth.instance.signOut(),
                      child: Text('Sign Out & Register Again', style: GoogleFonts.inter(color: Colors.white)),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final user = snap.data!;
        if (user.role == UserRole.client) {
          return ClientDashboardScreen(user: user);
        } else {
          return LawyerDashboardScreen(user: user);
        }
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0C1D36),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield_outlined, size: 60, color: Colors.white),
            SizedBox(height: 24),
            CircularProgressIndicator(
              color: Color(0xFFCFA92A),
              strokeWidth: 2.5,
            ),
          ],
        ),
      ),
    );
  }
}
