# AUTH INTEGRATION REPORT

_Generated: 2026-06-24 — branch `feat/import-new-pahadi-songs`_

## Summary
HimRaag now ships **real user authentication wired in from first launch**, not deferred.
Firebase Auth (Google + anonymous guest) drives a per-user Firestore profile that powers
personalization. Guest mode is preserved and upgraded to a real anonymous identity so guests
also get personalization and cross-device sync if they later link an account.

## What was added / changed
| Area | File | Change |
|---|---|---|
| Guest = real identity | `lib/features/auth/providers/auth_providers.dart` | `continueAsGuest()` now calls `signInAnonymously()` (real Firebase uid). Falls back to a local-only guest id if anonymous auth is disabled — app stays usable. |
| Guest actually signs in | `lib/features/auth/presentation/screens/sign_in_screen.dart` | "Continue as Guest" previously just navigated; now it authenticates, then routes new users to the preferences step. |
| First-login user doc | `lib/data/services/user_profile_service.dart` | `ensureUserDoc()` creates `users/{uid}` on first login and merges any existing remote profile. All Firestore writes are best-effort (never block the UX). |
| Profile state | `lib/features/auth/providers/user_profile_providers.dart` | `UserProfileNotifier` (Hive-backed, Firestore-mirrored). Listens to `currentUserProvider` and syncs the per-user doc when the Firebase user resolves. |
| Profile model | `lib/domain/models/user_profile.dart` | `UserProfile` (regions/languages/genres/followedArtists/onboardingCompleted/continueListening) + `ContinueListening`. |
| Onboarding gate | `lib/core/router/app_router.dart` | New `/preferences` route; redirect forces a brand-new user through onboarding → sign-in/guest → preferences before the app. Once complete, sign-in stays optional. |
| Onboarding prefs UI | `lib/features/auth/presentation/screens/preferences_screen.dart` | Region/language/genre chip picker; "Skip" still completes onboarding so users are never stuck. |

## Auth flow
```
first launch → /onboarding (3 intro pages) → /sign-in
   → Google  ─┐
   → Guest   ─┴→ ensureUserDoc(users/{uid}) → /preferences (new user) → /home
returning user → /home   (sign-in optional; guest always available)
```

## Data model — `users/{uid}` (consumer-private)
```jsonc
{
  "uid", "displayName", "email", "photoUrl", "signInMethod",
  "createdAt", "lastSeenAt",
  "favorites": ["songId", ...],
  "profile": {
    "preferredRegions": [...], "preferredLanguages": [...], "preferredGenres": [...],
    "followedArtistIds": [...], "onboardingCompleted": true,
    "continueListening": { "songId","title","artistName","artworkUrl","audioUrl",
                           "positionMs","durationMs","updatedAt" }
  }
}
```

## Security
- `firestore.rules` already isolates `users/{uid}`: `allow read, write: if isOwner(userId)` + admin read-only. Verified — **consumer-private data is owner-scoped; admin/catalog collections are separate** (`songs`/`albums`/`artists` admin-write, public-read; `auditLogs` admin-only).
- No rule change was required for the new fields (they live inside the already-protected `users/{uid}` doc).
- **Dev action:** deploy rules with `firebase deploy --only firestore:rules` if not already current.
- **Dev action:** enable **Anonymous** sign-in in Firebase Console → Authentication → Sign-in method (Google already enabled). Without it, guest falls back to local-only mode automatically.

## Offline-first / cost
Hive is the source of truth for the UI; Firestore is a best-effort mirror. Continue-listening
writes are throttled to ≥15s deltas to stay comfortably inside the Firebase Spark free tier.

## Verification
- `flutter analyze`: **clean (0 issues)** after this phase.
- On-device sign-in / Google consent flow requires a device + live Firebase project — to be
  confirmed during device QA on the release APK.
