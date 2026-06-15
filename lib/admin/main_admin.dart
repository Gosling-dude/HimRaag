import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../artist/artist_dashboard.dart';
import '../core/theme/app_theme.dart';
import '../firebase_options.dart';
import 'admin_auth.dart';
import 'screens/admin_dashboard.dart';
import 'screens/login_screen.dart';

/// Entry point for the HimRaag content dashboard (Flutter Web).
///
///   Run:   flutter run   -d chrome -t lib/admin/main_admin.dart
///   Build: flutter build web        -t lib/admin/main_admin.dart
///
/// Access is gated by Firebase Auth custom claims (admin / artist) — set them
/// with scripts/set_claims.js. This is a separate target from the consumer app
/// (lib/main.dart) and shares the domain models + Firestore datasources.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: AdminApp()));
}

class AdminApp extends ConsumerWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'HimRaag Console',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: const _AuthGate(),
    );
  }
}

/// Routes by auth state + role: login → no-access / admin / artist dashboard.
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(adminSessionProvider);
    return sessionAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Auth error: $e'))),
      data: (session) {
        if (session == null) return const LoginScreen();
        switch (session.role) {
          case AdminRole.admin:
            return AdminDashboard(session: session);
          case AdminRole.artist:
            return ArtistDashboard(session: session);
          case AdminRole.none:
            return NoAccessScreen(email: session.email);
        }
      },
    );
  }
}
