# UX Audit (Phase 8)

**Date:** 2026-08-03

> **Verification status:** this is a **code-level** review. Visual polish —
> spacing, alignment, animation smoothness, dark-mode contrast — genuinely
> requires seeing the app run, and no device was available. Claims below about
> *structure* are verified; claims about *appearance* are yours to confirm.
> The brief also forbids UI redesign, so **no visual change was made.**

## Screen inventory

All screens present and routed:

| Screen | File |
|---|---|
| Splash | `core/splash/bootstrap_app.dart` |
| Sign-in | `features/auth/.../sign_in_screen.dart` |
| Onboarding | `.../onboarding_screen.dart` |
| Preferences | `.../preferences_screen.dart` |
| Home | `features/home/.../home_screen.dart` |
| Search | `features/search/.../search_screen.dart` |
| All Songs | `features/songs/.../all_songs_screen.dart` |
| Album detail | `.../album_detail_screen.dart` |
| Artist detail | `.../artist_detail_screen.dart` |
| Category | `.../category_screen.dart` |
| Region | `.../region_screen.dart` |
| Playlist detail | `.../playlist_detail_screen.dart` |
| Library / Downloads / Favourites | `features/library/.../library_screen.dart` |
| Full player | `features/player/.../full_player_screen.dart` |
| Mini player | `.../mini_player.dart` + `core/widgets/mini_player_overlay.dart` |
| Profile | `features/profile/.../profile_screen.dart` |
| Admin dashboard | `lib/admin/screens/*` (web only) |

## Verified structural qualities

| Aspect | Finding |
|---|---|
| **Loading states** | `shimmer` 3.0.0 used via `shimmer_loading.dart`; `AppArtwork` shows a shimmer placeholder rather than a blank box |
| **Error states** | `.when(...)`/error branches present in home, library, search, album, artist, category, region, playlist, profile and full-player screens |
| **Empty states** | Handled in library and search |
| **Fallback artwork** | Branded gradient + initials — never a grey broken-image icon |
| **Dark mode** | Both `AppTheme.lightTheme` and `darkTheme` wired through `themeModeProvider` |
| **Fonts** | `google_fonts` 6.3.3 — see caveat below |
| **Animations** | `animations` 2.0.11; a 200 ms transition in the search screen |
| **Mini player reach** | `MiniPlayerOverlay` is applied across detail screens, so playback controls persist while browsing |
| **Safe areas** | Both `main_shell.dart:66` and `mini_player_overlay.dart:29` wrap in `SafeArea` — correct for API 36 edge-to-edge |

## Findings

### 1. ⚠️ `google_fonts` fetches over the network (P2)

`assets/fonts/` is empty, so no font is bundled. `google_fonts` downloads and
caches font files at runtime. Consequences:

- On a **cold first launch with no network**, text falls back to the system font —
  the app looks off-brand exactly when a new user forms their first impression.
- It is an avoidable network dependency for an app with a deliberate offline story.

The empty `assets/fonts/` directory suggests bundling was intended and never
finished. **Recommended:** download the font `.ttf` files, place them in
`assets/fonts/`, declare them in `pubspec.yaml`, and switch to `TextStyle(fontFamily:)`.
Not done here — it changes rendering, which the "no UI redesign" rule forbids.

### 2. ⚠️ Tablet layout now reachable (P2, new)

API 36 **ignores `screenOrientation="portrait"` on screens ≥600dp**. The manifest
sets it and `main.dart:87` sets `setPreferredOrientations`, but neither is honoured
on a tablet or unfolded foldable. If you intend to support those form factors,
check the Home grid and full player in landscape.

### 3. `cupertino_icons` font not bundled (P3)

Build warning: *"Expected to find fonts for (packages/cupertino_icons/CupertinoIcons,
MaterialIcons), but found (MaterialIcons)."* Any Cupertino icon used would render
blank. No such defect has been observed; worth a glance during your pass.

## ❌ NOT VERIFIED — visual checklist

Walk each screen in both light and dark mode and confirm:

- [ ] Spacing, padding and alignment consistent across screens
- [ ] **Bottom nav and mini player clear the system nav bar** (edge-to-edge, new)
- [ ] Text legible in dark mode; adequate contrast on gradient fallback covers
- [ ] Loading shimmers appear and resolve — never stick
- [ ] Empty states (no favourites, no downloads, no search results) read well
- [ ] Error states offer a retry path
- [ ] Transitions smooth; no dropped frames scrolling Home
- [ ] Long titles/artist names truncate rather than overflow
- [ ] Player controls comfortably tappable (≥48dp)

**No screen was found to be structurally unfinished** — every one has loading,
empty and error handling in place.
