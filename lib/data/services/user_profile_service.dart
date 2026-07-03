import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../domain/models/app_user.dart';
import '../../domain/models/user_profile.dart';
import '../local/hive_boxes.dart';

/// Persists the per-user [UserProfile] offline-first in Hive and mirrors it to
/// Firestore `users/{uid}` when a Firebase user exists. All Firestore writes are
/// best-effort: a network/permission failure never blocks the local UX (the app
/// stays fully usable offline and for guests).
class UserProfileService {
  UserProfileService(this._firestore);

  final FirebaseFirestore _firestore;

  static const String _key = 'user_profile';

  // ── Local (Hive) ───────────────────────────────────────────────────────────

  UserProfile loadLocal() {
    final raw = HiveBoxes.settings.get(_key);
    if (raw is String && raw.isNotEmpty) {
      try {
        return UserProfile.fromMap(
            Map<String, dynamic>.from(json.decode(raw) as Map));
      } catch (_) {/* fall through to default */}
    }
    return const UserProfile();
  }

  Future<void> saveLocal(UserProfile profile) async {
    await HiveBoxes.settings.put(_key, json.encode(profile.toMap()));
  }

  // ── Remote (Firestore) ───────────────────────────────────────────────────

  /// Creates the per-user doc on first login and merges any existing remote
  /// profile with the local one. Local wins when the user already chose
  /// preferences on this device; otherwise the remote profile is adopted so
  /// personalization follows the account across devices.
  Future<UserProfile> ensureUserDoc(AppUser user) async {
    final local = loadLocal();
    // Pure-local guests (no Firebase uid) never touch Firestore.
    if (user.uid.startsWith('guest_')) return local;

    final ref = _firestore.collection('users').doc(user.uid);
    try {
      final snap = await ref.get();
      if (!snap.exists) {
        await ref.set({
          'uid': user.uid,
          'displayName': user.displayName,
          'email': user.email,
          'photoUrl': user.photoUrl,
          'signInMethod': user.signInMethod.name,
          'createdAt': FieldValue.serverTimestamp(),
          'profile': local.toMap(),
          'favorites': <String>[],
          'playlists': <Map<String, dynamic>>[],
          'recentlyPlayed': <Map<String, dynamic>>[],
          'stats': {'totalPlays': 0},
        });
        debugPrint('[USER] CREATED users/${user.uid}');
        return local;
      }
      final data = snap.data();
      final remote =
          UserProfile.fromMap((data?['profile'] as Map?)?.cast<String, dynamic>());
      // First time on this device but account already personalized elsewhere.
      final merged = local.hasPreferences ? local : remote;
      await ref.set({
        'displayName': user.displayName,
        'email': user.email,
        'photoUrl': user.photoUrl,
        'signInMethod': user.signInMethod.name,
        'lastSeenAt': FieldValue.serverTimestamp(),
        'profile': merged.toMap(),
      }, SetOptions(merge: true));
      await saveLocal(merged);
      debugPrint('[USER] SYNCED users/${user.uid}');
      return merged;
    } catch (e) {
      debugPrint('[USER] ensureUserDoc best-effort failed: $e');
      return local;
    }
  }

  /// Persists [profile] locally and mirrors to Firestore for non-guest users.
  Future<void> save(UserProfile profile, {String? uid}) async {
    await saveLocal(profile);
    if (uid == null || uid.startsWith('guest_')) return;
    try {
      await _firestore.collection('users').doc(uid).set(
        {'profile': profile.toMap(), 'lastSeenAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[USER] save mirror failed (kept locally): $e');
    }
  }

  /// Mirrors the favorites set to the user doc (consumer-private). Local Hive
  /// remains the source of truth for the UI.
  Future<void> syncFavorites(Set<String> favorites, {String? uid}) async {
    if (uid == null || uid.startsWith('guest_')) return;
    try {
      await _firestore.collection('users').doc(uid).set(
        {'favorites': favorites.toList()},
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('[USER] favorites mirror failed: $e');
    }
  }

  /// Records a play in the user doc: refreshes the `recentlyPlayed` list (most
  /// recent first, capped) and increments listening-history counters. Hive
  /// remains the local source of truth; this is a best-effort mirror so the
  /// account's history follows the user across devices.
  Future<void> logPlay({
    required String songId,
    required String title,
    required String artistName,
    required List<Map<String, dynamic>> recentlyPlayed,
    String? uid,
  }) async {
    if (uid == null || uid.startsWith('guest_')) return;
    try {
      await _firestore.collection('users').doc(uid).set({
        'recentlyPlayed': recentlyPlayed,
        'stats': {'totalPlays': FieldValue.increment(1)},
        'listenCounts': {songId: FieldValue.increment(1)},
        'lastPlayed': {
          'songId': songId,
          'title': title,
          'artistName': artistName,
          'at': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[USER] play mirror failed: $e');
    }
  }
}
