import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:uuid/uuid.dart';

import '../../../domain/models/app_user.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final authStateProvider = StreamProvider<AppUser?>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges().map((user) {
    if (user == null) return null;
    return AppUser(
      uid: user.uid,
      signInMethod:
          user.isAnonymous ? UserSignInMethod.guest : UserSignInMethod.google,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
      createdAt: user.metadata.creationTime,
    );
  });
});

final currentUserProvider = Provider<AppUser?>((ref) {
  return ref.watch(authStateProvider).valueOrNull;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    auth: ref.watch(firebaseAuthProvider),
    googleSignIn: GoogleSignIn(),
  );
});

class AuthRepository {
  AuthRepository({required this.auth, required this.googleSignIn});

  final FirebaseAuth auth;
  final GoogleSignIn googleSignIn;

  Future<AppUser> signInWithGoogle() async {
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Sign in cancelled');

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await auth.signInWithCredential(credential);
    final user = userCredential.user!;

    return AppUser(
      uid: user.uid,
      signInMethod: UserSignInMethod.google,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
      createdAt: user.metadata.creationTime,
    );
  }

  Future<AppUser> continueAsGuest() async {
    final guestId = 'guest_${const Uuid().v4()}';
    return AppUser(
      uid: guestId,
      signInMethod: UserSignInMethod.guest,
    );
  }

  Future<void> signOut() async {
    await Future.wait([
      auth.signOut(),
      googleSignIn.signOut(),
    ]);
  }

  bool get isSignedIn => auth.currentUser != null;
}
