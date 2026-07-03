import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/services/user_profile_service.dart';
import '../../../domain/models/user_profile.dart';
import 'auth_providers.dart';

/// Standalone Firestore handle (avoids importing home_providers here, which
/// would create an import cycle once Home consumes personalization).
final _profileFirestoreProvider =
    Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  return UserProfileService(ref.watch(_profileFirestoreProvider));
});

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  return UserProfileNotifier(ref);
});

/// Convenience selectors.
final onboardingCompletedProvider = Provider<bool>(
    (ref) => ref.watch(userProfileProvider).onboardingCompleted);

final followedArtistsProvider = Provider<Set<String>>(
    (ref) => ref.watch(userProfileProvider).followedArtistIds.toSet());

final isFollowingArtistProvider = Provider.family<bool, String>(
    (ref, artistId) => ref.watch(followedArtistsProvider).contains(artistId));

final continueListeningProvider = Provider<ContinueListening?>(
    (ref) => ref.watch(userProfileProvider).continueListening);

class UserProfileNotifier extends StateNotifier<UserProfile> {
  UserProfileNotifier(this._ref)
      : _service = _ref.read(userProfileServiceProvider),
        super(const UserProfile()) {
    state = _service.loadLocal();
    // When the Firebase user resolves, create/sync the per-user doc.
    _ref.listen(currentUserProvider, (prev, next) {
      if (next != null && next.uid != prev?.uid) {
        _syncRemote();
      }
    });
  }

  final Ref _ref;
  final UserProfileService _service;

  String? get _uid => _ref.read(currentUserProvider)?.uid;

  Future<void> _syncRemote() async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    final merged = await _service.ensureUserDoc(user);
    if (mounted) state = merged;
  }

  Future<void> _persist(UserProfile next) async {
    state = next;
    await _service.save(next, uid: _uid);
  }

  Future<void> setPreferences({
    List<String>? regions,
    List<String>? languages,
    List<String>? genres,
  }) async {
    await _persist(state.copyWith(
      preferredRegions: regions,
      preferredLanguages: languages,
      preferredGenres: genres,
    ));
  }

  Future<void> completeOnboarding({
    required List<String> regions,
    required List<String> languages,
    required List<String> genres,
  }) async {
    await _persist(state.copyWith(
      preferredRegions: regions,
      preferredLanguages: languages,
      preferredGenres: genres,
      onboardingCompleted: true,
    ));
  }

  Future<void> markOnboardingComplete() =>
      _persist(state.copyWith(onboardingCompleted: true));

  Future<void> toggleFollowArtist(String artistId) async {
    final set = state.followedArtistIds.toSet();
    set.contains(artistId) ? set.remove(artistId) : set.add(artistId);
    await _persist(state.copyWith(followedArtistIds: set.toList()));
  }

  Future<void> setContinueListening(ContinueListening cl) async {
    // Avoid write storms: only persist when the song or ~5s of position changed.
    final prev = state.continueListening;
    if (prev != null &&
        prev.songId == cl.songId &&
        (prev.positionMs - cl.positionMs).abs() < 15000) {
      return;
    }
    await _persist(state.copyWith(continueListening: cl));
  }

  Future<void> clearContinueListening() =>
      _persist(state.copyWith(clearContinueListening: true));
}
