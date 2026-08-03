# Personalization Audit (Phase 12)

**Date:** 2026-08-03

> **Phase 12 asked me to create two test users and compare their feeds.**
> I did **not** do this, deliberately: creating accounts writes real documents into
> the production `users` collection (19 real accounts today), and the brief says
> preserve Firestore. Creating and then deleting production data to generate a
> screenshot is not a trade I should make unasked.
>
> Instead: the personalization **data model and isolation guarantees are verified
> from code and live data**, and the two-user comparison is scripted below for you
> to run against the emulator or with throwaway accounts.
>
> *(An earlier `PERSONALIZATION_REPORT.md` from 2026-06-24 exists in the repo; this
> file supersedes it for the release audit.)*

## Per-user data model — verified

`users/{uid}` (from `user_profile_service.dart:53-65`):

| Field | Purpose |
|---|---|
| `uid`, `displayName`, `email`, `photoUrl`, `signInMethod` | Identity |
| `createdAt`, `lastSeenAt` | Server timestamps |
| `profile` | Preferred regions, languages, genres, followed artists, onboarding flag |
| `favorites` | Array of song IDs |
| `playlists` | User-created playlists |
| `recentlyPlayed` | History |
| `stats.totalPlays` | Counter |
| `profile.continueListening` | songId, title, artist, artwork, audioUrl, position, duration |

**Isolation is enforced server-side**, not just in the UI:
```
match /users/{userId} { allow read, write: if isOwner(userId); }
```
User A cannot read or write user B's document. Two users therefore *cannot* share
a feed. This is a rules-level guarantee, stronger than a UI-level one.

## Guest handling — verified

`user_profile_service.dart:47`:
```dart
if (user.uid.startsWith('guest_')) return local;
```
Guests **never touch Firestore**. Preferences live only in Hive on-device. Good for
privacy and for Play's Data Safety answers.

## Cross-device merge — verified

On sign-in (`:73`): `final merged = local.hasPreferences ? local : remote;`

Device-local preferences win if present, otherwise the account's stored profile is
adopted. So a user who personalizes on device A and then signs in on device B
inherits their profile rather than starting empty. Sensible, and it explains why
the guest→signed-in transition does not lose choices.

The whole `ensureUserDoc` path is wrapped in try/catch and returns local data on
failure (`:85-88`) — **personalization degrades to on-device rather than blocking
sign-in** if Firestore is unreachable.

## ❌ NOT VERIFIED — two-user comparison

Run this yourself with two throwaway Google accounts (or against the Firebase
emulator, which is safer):

1. Sign in as **User A** → onboarding → pick regions *Kangra*, genre *Folk*.
   Favourite 3 songs. Play 2 more. Force-quit.
2. Sign in as **User B** (different account) → pick *Kinnaur*, genre *Devotional*.
   Favourite 3 **different** songs.
3. Confirm:
   - [ ] Home rows differ between A and B
   - [ ] Favourites lists are disjoint
   - [ ] Recently-played lists are disjoint
   - [ ] "Continue listening" shows each user's own last track and position
   - [ ] Signing out of B and back into A restores A's data intact
   - [ ] Recommendations reflect each user's chosen regions/genres

To use the emulator instead of production:
```bash
firebase emulators:start --only firestore,auth
```

## Note on playlists

The `playlists` collection currently holds **0 documents** — the feature is built
and rules-protected but unused. Nothing to verify beyond the rules, which are
correct apart from one P3 hardening noted in FIRESTORE_AUDIT.md.
