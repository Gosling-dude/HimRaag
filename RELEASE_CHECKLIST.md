# HimRaag — Release Checklist

_Last updated: 2026-06-15_

Use this checklist before each release track promotion. Items marked **[BLOCKING]** must pass before the build ships. Items marked **[RECOMMENDED]** are strongly advised but not hard gates.

---

## Pre-Release Gates

### Credentials & Configuration

- [ ] **[BLOCKING]** `android/app/google-services.json` present and matches `himraag-prod`
- [ ] **[BLOCKING]** `lib/firebase_options.dart` generated for `himraag-prod` (`flutterfire configure --project=himraag-prod`)
- [ ] **[BLOCKING]** Firebase Authentication enabled in Console (Anonymous + Google providers)
- [ ] **[BLOCKING]** SHA-1 fingerprint of release keystore added to Firebase Console → Android app
- [ ] **[BLOCKING]** Release keystore path/alias/passwords configured in `android/local.properties`

### Backend

- [ ] **[BLOCKING]** Firestore rules deployed: `firebase deploy --only firestore`
- [ ] **[BLOCKING]** Firestore indexes deployed (included in above command)
- [ ] **[BLOCKING]** Firestore seeded with content: `GOOGLE_APPLICATION_CREDENTIALS=... node scripts/seed_firestore.js --commit` (omit `--commit` for a dry-run validation)
- [ ] **[BLOCKING]** All audio URLs in Firestore return HTTP 200 with `Content-Type: audio/mpeg`
- [ ] **[BLOCKING]** All artwork URLs in Firestore return HTTP 200 with `Content-Type: image/*`
- [ ] **[RECOMMENDED]** Audio URLs return `Accept-Ranges: bytes` (required for seeking)

### Build

- [ ] **[BLOCKING]** `flutter analyze` → 0 issues
- [ ] **[BLOCKING]** `flutter test` → all tests pass
- [ ] **[BLOCKING]** `flutter build appbundle --release` → produces `app-release.aab`
- [ ] **[BLOCKING]** APK/AAB signed with production keystore (not debug key)
- [ ] **[RECOMMENDED]** AAB size ≤ 40 MB (current: 27.2 MB ✅)

### Device Testing

- [ ] **[BLOCKING]** Install debug APK on at least one physical Android device
- [ ] **[BLOCKING]** Guest login (anonymous) completes successfully
- [ ] **[BLOCKING]** Home screen loads songs, albums, artists from Firestore
- [ ] **[BLOCKING]** Tap a song → audio starts playing within 3 seconds
- [ ] **[BLOCKING]** Pause / seek / resume work correctly
- [ ] **[BLOCKING]** Background playback works (minimize app, audio continues)
- [ ] **[BLOCKING]** Lock screen controls show song metadata and respond to play/pause
- [ ] **[BLOCKING]** Search returns results for a partial song title (e.g., "bedu")
- [ ] **[BLOCKING]** Artist page loads with bio, albums, and songs
- [ ] **[BLOCKING]** Album page loads with all songs and "Play All" works
- [ ] **[BLOCKING]** Favorite a song → appears in Library → Favorites tab
- [ ] **[RECOMMENDED]** Download a song → appears in Library → Downloads tab → plays offline
- [ ] **[RECOMMENDED]** Google Sign-In flow completes on a physical device
- [ ] **[RECOMMENDED]** Test on Android 8.0 (API 26) minimum target
- [ ] **[RECOMMENDED]** Test on Android 14 (API 34) for latest platform behaviour

### Content

- [ ] **[BLOCKING]** No Bollywood or English-language content in the seeded data
- [ ] **[BLOCKING]** All audio is licensed or public-domain Pahadi music (not SoundHelix)
- [ ] **[BLOCKING]** All artwork is licensed or original (not picsum.photos placeholders)
- [ ] **[RECOMMENDED]** At least 50 songs across all regions (Garhwali, Kumaoni, Jaunsari, Himachali)

### Play Store

- [ ] **[BLOCKING]** App title: "HimRaag - Pahadi Music"
- [ ] **[BLOCKING]** Privacy policy URL provided in Play Console
- [ ] **[BLOCKING]** Content rating questionnaire completed (likely Everyone rating)
- [ ] **[BLOCKING]** Store listing screenshots provided (minimum 2 phone screenshots)
- [ ] **[BLOCKING]** Short description (≤80 chars) and full description complete
- [ ] **[RECOMMENDED]** Feature graphic (1024×500 px) provided
- [ ] **[RECOMMENDED]** App icon matches the one in the APK (512×512 PNG)

---

## Internal Testing Track (current)

Minimum gate before inviting internal testers:

- [ ] Credentials configured ✅
- [ ] Anonymous login works on device
- [ ] At least one song plays end-to-end
- [ ] No crash on launch (`firebase_crashlytics` connected)
- [ ] APK signed and uploaded to Play Console

**Current status:** Credentials present, APK built, emulator E2E not verified.

---

## Known Open Items (must resolve before production)

| ID | Item | Priority |
|----|------|----------|
| L-01 | Replace SoundHelix with real licensed Pahadi audio | P0 |
| L-02 | Replace picsum.photos with real artwork | P0 |
| L-03 | Expand content library to ≥50 songs | P0 |
| L-12 | Implement Favorites tab song list | P1 |
| L-04 | Document guest-to-Google account upgrade flow | P2 |
| L-11 | Per-song download progress indicator | P2 |
| L-14 | Playlist creation UI | P3 |

_See `KNOWN_LIMITATIONS.md` for full descriptions._

---

## Content System & Demo Catalog

The seed catalog is **demo-only** (`license=DEMO_ONLY`, `isPublished=false`) and
must never ship publicly. See `docs/CONTENT_SYSTEM.md`.

- [ ] **[BLOCKING]** Release build sets `--dart-define=HIMRAAG_INTERNAL=false`
      (or all `DEMO_ONLY` docs are purged) so demo content is excluded
- [ ] **[BLOCKING]** Replace demo entries with licensed content via the import
      pipeline; every published song has a cleared license + exact `attribution`
- [ ] **[BLOCKING]** `node scripts/validate_catalog.js` → 0 rights issues,
      0 broken URLs, 0 orphan refs before promotion
- [ ] **[RECOMMENDED]** Admin web app: finalize `firebase_options.dart` `web`
      block (`flutterfire configure --platforms=web`) and deploy to Firebase
      Hosting (free tier) if the dashboard is hosted
- [ ] **[RECOMMENDED]** Admin/artist accounts provisioned via
      `scripts/set_claims.js`; no stray admin claims on test accounts

---

## Free-Tier Compliance Checklist

Confirm the app costs ₹0/month:

- [ ] `firebase_storage` package is NOT in `pubspec.yaml` ✅
- [ ] Firebase project is on Spark (free) plan — not Blaze ✅ _(verify in Console)_
- [ ] Audio served from free external CDN (not Firebase Storage) ✅
- [ ] Artwork served from free external CDN (not Firebase Storage) ✅
- [ ] No paid third-party services (Algolia, Twilio, etc.) ✅
- [ ] Firestore daily read/write usage below 80% of free limits _(monitor in Console)_
