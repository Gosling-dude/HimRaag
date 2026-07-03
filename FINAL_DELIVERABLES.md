# HimRaag — Pre-Production Stabilization: Final Deliverables

_Generated: 2026-07-04 · branch `feat/import-new-pahadi-songs`_

Everything below is factual runtime evidence from this session.

## Catalog totals (live Firestore)

| Metric | Value |
|---|---|
| Songs (total) | **956** (was 328: +629 imported after dedup/collision cleanup) |
| Songs consumer-visible (approved) | **613** |
| Songs in admin review queue (region unresolved, unpublished) | 343 |
| Artists | **217** |
| Albums | **173** |
| Bundled offline catalog | **697 songs / 148 artists / 102 albums** |

## Import funnel (`music/pahadi songs/` — 1009 MP3s)

scanned 1009 → 0 exact dups → 10 quality variants dropped → 63
mashups/medleys excluded → 301 already imported (exact source-file match) →
**635 new uniques** → 6 teaser/duplicate collisions removed → **629 imported**.
R2: **635/635 audio + artwork verified HTTP 200**; streaming spot-check
40/40 catalog-wide Range requests answered 200/206 (seek works at CDN level).

## Category distribution (consumer-visible Firestore)

| Region | Before | After |
|---|---|---|
| Garhwali | 3 | **215** |
| Himachali | 70 | **194** |
| Kumaoni | 5 | **77** |
| Jaunsari | 2 | **76** |
| Kinnauri | 1 | **51** |
| Sirmauri | 0 | 0 (no source material in the drop) |
| "Pahadi" dumping ground (bundle) | 169 | **93** (legacy live songs only; nothing new added) |

Classification: filename tokens (Latin + Devanagari) → curated artist→region
dictionary → public metadata (iTunes/MusicBrainz title+duration matches with
per-artist region voting). Ambiguous songs stay in the **admin review queue**
— never dumped into a generic bucket. Details: `CATEGORY_DISTRIBUTION_REPORT.md`.

## Metadata quality

- 351 new-batch songs gained real artist credits from public metadata (e.g.
  Narendra Singh Negi, Pappu Karki, Kedar Negi, Ajju Tomar); 150 existing
  "Unknown Artist" songs reattributed the same way.
- 357 release years recovered; search keywords + slugs regenerated everywhere.

## Artwork & artist images

- Song artwork (new batch): **505 official covers + 123 real regional
  photographs + 1 neutral placeholder** (of 629). Zero AI images, zero text
  cards. (`THUMBNAIL_AUDIT.md`)
- Artist photos: 12 genuine portraits hosted on R2 (Wikipedia lead images
  verified as musician pages / exact-match JioSaavn portraits — incl. Narendra
  Singh Negi, Meena Rana, Pritam Bharatwan, Mohan Upreti); remaining artists
  use their official song cover or the app's clean initials avatar — never an
  AI face. (`ARTIST_IMAGE_AUDIT.md`)

## Google Sign-In (P0) — FIXED

Root cause: **zero SHA fingerprints** registered on the Firebase Android app →
no Android OAuth client → `ApiException: 10`. Fixed by registering debug +
release SHA-1/SHA-256 via the Firebase Management API and refreshing
`google-services.json` (now 2 Android clients + 1 web client). Release APK's
signing cert verified byte-identical to the registered fingerprint via
`apksigner`. Full audit: `GOOGLE_SIGNIN_AUDIT.md`.

## Personalization

`users/{uid}` docs now carry: displayName, email, photo, sign-in method,
region/language/genre preferences, followed artists, favorites, playlists
field, recently played (last 25), listening-history counters + last-played,
onboarding state. First-run flow: onboarding → Google/guest sign-in →
preferences → personalized Home ("Made for You" ranking, preferred-region
rows first, Continue Listening). Guest mode uses Firebase anonymous auth
(verified enabled server-side).

## Data cleanup

Firestore verified clean: 0 demo/instrumental/test/placeholder tracks,
0 duplicate title+artist groups. (`DATA_CLEANUP_REPORT.md`)

## Regression & builds

| Check | Result |
|---|---|
| `flutter analyze` | **No issues found** |
| `flutter test` | **12/12 passed** |
| `flutter build apk --release` | ✅ `build\app\outputs\flutter-apk\app-release.apk` — **59.8 MB** |
| `flutter build appbundle --release` | ✅ `build\app\outputs\bundle\release\app-release.aab` — **60.7 MB** |
| Release signing | Dedicated upload keystore (`.env/`, gitignored); `apksigner` verified |
| targetSdk | **35** (Play requirement); Gradle 8.12 / AGP 8.7.3 / Flutter 3.44.4 |

Toolchain repairs this session: Flutter 3.44 SDK breakages fixed (`RepeatMode`
collision, `CupertinoPageTransitionsBuilder` move, deprecated form-field
`value`, google_fonts 6.3.0 const-eval crash, Gradle/AGP minimums).

## Play Store readiness checklist

- [x] Google Sign-In configuration complete for debug + release certs
- [x] Release AAB signed with dedicated upload key
- [x] targetSdk 35, compileSdk 35, minSdk 24
- [x] No secrets in repo (`.env/`, keystore, `google-services.json` gitignored)
- [x] Catalog balanced, artwork real, playback URLs verified streaming
- [x] Background playback + notification controls (audio_service manifest
  wiring verified; runtime-verified in a previous session's device QA)
- [ ] **On-device smoke test** — no Android device/emulator was available on
  this machine (no hypervisor installed). Install the fresh APK on hardware
  and tap through: Google sign-in → onboarding → personalized Home → playback.
- [ ] After the first Play Console upload: copy the **Play App Signing**
  SHA-1/SHA-256 (Console → App integrity) into Firebase project settings —
  required for Google Sign-In on Play-delivered builds.

## Artifact paths

- APK: `D:\Personal Projects\HimRaag\build\app\outputs\flutter-apk\app-release.apk` (59.8 MB)
- AAB: `D:\Personal Projects\HimRaag\build\app\outputs\bundle\release\app-release.aab` (60.7 MB)
