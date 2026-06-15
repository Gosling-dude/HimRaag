import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Dashboard access level, derived from Firebase Auth custom claims set by
/// `scripts/set_claims.js` and enforced by the Firestore security rules.
enum AdminRole { admin, artist, none }

class AdminSession {
  const AdminSession({
    required this.uid,
    required this.email,
    required this.role,
  });

  final String uid;
  final String email;
  final AdminRole role;

  bool get isAdmin => role == AdminRole.admin;
  bool get isArtist => role == AdminRole.artist;
}

/// Resolves the current Firebase user into an [AdminSession] with its role.
/// Emits null when signed out. Re-reads claims on every auth change.
final adminSessionProvider = StreamProvider<AdminSession?>((ref) async* {
  final auth = FirebaseAuth.instance;
  await for (final user in auth.authStateChanges()) {
    if (user == null) {
      yield null;
      continue;
    }
    // Force-refresh so a freshly-granted claim is picked up after re-login.
    final token = await user.getIdTokenResult(true);
    final claims = token.claims ?? const {};
    final role = claims['admin'] == true
        ? AdminRole.admin
        : claims['role'] == 'artist'
            ? AdminRole.artist
            : AdminRole.none;
    yield AdminSession(
      uid: user.uid,
      email: user.email ?? '',
      role: role,
    );
  }
});

/// Sign-in/out actions for the dashboard login screen.
class AdminAuthController {
  AdminAuthController(this._auth);

  final FirebaseAuth _auth;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _auth.signOut();
}

final adminAuthControllerProvider = Provider<AdminAuthController>(
  (ref) => AdminAuthController(FirebaseAuth.instance),
);
