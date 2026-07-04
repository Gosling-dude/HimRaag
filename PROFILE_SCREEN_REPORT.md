# Profile Screen Report

Date: 2026-07-04 · Branch: `feat/import-new-pahadi-songs`

## Entry point

**Top-right avatar on the Home app bar** (`_ProfileAvatarButton` in
`lib/features/home/presentation/screens/home_screen.dart`), next to the search icon —
the same pattern Spotify/YouTube Music use. It shows the Google account photo when
available, otherwise the user's initial, otherwise a person icon. Tapping opens
`/profile`. No bottom-nav or drawer redesign was needed; the existing shell is
untouched.

## Screen: `lib/features/profile/presentation/screens/profile_screen.dart` (route `/profile`)

### Displays

| Item | Source |
|---|---|
| Profile photo (or initial avatar) | `AppUser.photoUrl` (Firebase Auth / Google) |
| Display name | `AppUser.displayLabel` |
| Email | `AppUser.email` (hidden for guests without email) |
| Account creation date | `AppUser.createdAt` (Firebase Auth metadata) |
| Sign-in method badge | Google account / Guest account |
| Preferred regions | `UserProfile.preferredRegions` |
| Preferred languages | `UserProfile.preferredLanguages` |
| Preferred genres | `UserProfile.preferredGenres` (bonus) |
| Favorite songs count | `favoritesProvider` (Hive `favorites` box) |
| Playlist count | 0 — user playlists are not a shipped feature yet; the count is shown factually |
| Recently played count | Hive `recently_played` box length |
| Download count | `downloadedSongsProvider` |
| Storage used by downloads | `DownloadService.getTotalDownloadedSizeBytes()` (MB/GB formatted) |
| Account info | sign-in method, created date, truncated UID |

**Passwords are never displayed** — the app uses Google/anonymous auth and never holds
a password at all.

### Actions

- **Change display name** — pencil next to the name; writes via
  `FirebaseAuth.updateDisplayName()` + `reload()`. `authStateProvider` was switched
  from `authStateChanges()` to `userChanges()` (a strict superset — same
  sign-in/sign-out events plus profile updates) so the new name appears instantly on
  Profile and Home.
- **Change preferred region / language — Edit Preferences** — opens the existing
  `/preferences?from=settings` screen (reused, not duplicated).
- **Sign out** — confirmation dialog (explains local data stays on device), then
  `AuthRepository.signOut()` and navigation to `/sign-in`.
- **Change avatar** — *not implemented* (listed as optional). It would require
  `image_picker` + Firebase Storage, two new dependencies and a storage bucket —
  out of scope for a polish-only RC. The Google account photo is used automatically.

### Signed-out state

If nobody is signed in, the screen shows a clean "You are not signed in" state with a
Sign In button — it never crashes on a null user.

### Polish details

- Dark premium cards (`AppColors.cardDark`, 14 px radii) consistent with the app theme.
- 2×2 stats grid, chip-style preference tags, badges for account type / member-since.
- Mini player floats over the Profile screen when music is playing (route is wrapped
  in `MiniPlayerOverlay`); list bottom padding (120 px) keeps content clear of it.

## Verification

- `flutter analyze` — no issues.
- `flutter test` — 12/12 passed.
- No existing provider or service was modified except the `userChanges()` swap
  described above; auth, personalization sync, favorites and downloads code paths are
  untouched.
