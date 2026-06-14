# HimRaag — Deployment Guide

## Free-Tier Architecture (₹0/month)

HimRaag runs entirely on Firebase's **Spark (free) plan** with no paid services.

| Service | Provider | Cost | Limit |
|---------|----------|------|-------|
| Authentication | Firebase Auth | Free | Unlimited MAU |
| Database | Cloud Firestore | Free | 1 GB storage, 50k reads/day, 20k writes/day |
| Analytics | Firebase Analytics | Free | Unlimited |
| Crash reporting | Firebase Crashlytics | Free | Unlimited |
| Audio streaming | External CDN (SoundHelix / self-hosted) | Free | Depends on host |
| Artwork / images | External CDN (picsum.photos / self-hosted) | Free | Depends on host |
| Firebase Storage | **Not used** | — | — |

### How audio and images work

Audio files and artwork are served as plain HTTP URLs stored in Firestore fields
(`audioUrl`, `artworkUrl`). The app streams/downloads directly from those URLs using
`just_audio` and `dio`. Firebase Storage is **not involved** and the `firebase_storage`
SDK package is **not a dependency**.

### Migrating to Firebase Storage (future / paid)

When you need to self-host audio in Firebase Storage (requires Blaze plan):

1. Upgrade project to Blaze plan in Firebase Console.
2. Enable Storage → `us-central1`.
3. Upload MP3s to `gs://himraag-prod.firebasestorage.app/audio/<songId>.mp3`.
4. Upload artwork to `gs://himraag-prod.firebasestorage.app/artwork/<albumId>.jpg`.
5. Update `AUDIO` / `ART` / `IMG` constants in `scripts/seed_firestore.js` with the
   public Storage URLs (or signed URLs if private).
6. Re-run `node scripts/seed_firestore.js` to update Firestore.
7. Un-comment the storage path constants in `lib/core/constants/firebase_constants.dart`.
8. Deploy storage rules: `firebase deploy --only storage`.

---

## Firebase Project

- **Project ID**: `himraag-prod`
- **Project Number**: `39471021909`
- **Android App ID**: `1:39471021909:android:1fb835736cc307e6f7b9dc`
- **Storage Bucket**: `himraag-prod.firebasestorage.app` _(reserved, currently unused)_

## Prerequisites

| Tool | Version | Install |
|------|---------|---------|
| Flutter | 3.27.1 | `flutter.dev` |
| Dart | 3.6.0 | bundled with Flutter |
| Java | 21 (Temurin) | `adoptium.net` |
| Android SDK | API 34 | `sdkmanager "platforms;android-34"` |
| Firebase CLI | ≥ 15.x | `npm install -g firebase-tools` |
| Node.js | ≥ 18 | `nodejs.org` |

## Credentials Setup

These files are gitignored and must be obtained per environment:

### 1. `android/app/google-services.json`

Download from Firebase Console:
> Project Settings → Your apps → Android → Download google-services.json

Place at `android/app/google-services.json`.

### 2. `lib/firebase_options.dart`

Generate with FlutterFire CLI after placing `google-services.json`:

```bash
dart pub global activate flutterfire_cli
flutterfire configure --project=himraag-prod
```

### 3. Service Account Key (for seeding / admin scripts)

> Firebase Console → Project Settings → Service Accounts → Generate new private key

Save to a secure path and set:
```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

## Android Build

### Debug

```bash
flutter pub get
flutter build apk --debug
```

### Release (Play Store)

1. Create a release keystore (one-time):
   ```bash
   keytool -genkey -v -keystore himraag-release.jks \
     -alias himraag -keyalg RSA -keysize 2048 -validity 10000
   ```

2. Add to `android/local.properties`:
   ```
   keystoreFile=/absolute/path/to/himraag-release.jks
   keystoreAlias=himraag
   keystorePassword=YOUR_STORE_PASSWORD
   keystoreStorePassword=YOUR_STORE_PASSWORD
   ```

3. Build:
   ```bash
   flutter build appbundle --release
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`

## Firebase Setup (one-time per environment)

### Firestore

Rules and indexes are in the repo:

```bash
firebase deploy --only firestore
```

### Authentication (requires Console action first)

1. Go to: https://console.firebase.google.com/project/himraag-prod/authentication
2. Click **Get Started**
3. Enable **Anonymous** provider (Sign-in providers → Anonymous → Enable)
4. Enable **Google** provider (Sign-in providers → Google → Enable)
   - Add your release SHA-1 fingerprint:
     ```bash
     keytool -list -v -keystore himraag-release.jks -alias himraag
     ```
   - Add the SHA-1 to: Firebase Console → Project Settings → Android app → Add fingerprint

### Storage

Storage is **not used** in the current free-tier setup. The `storage.rules` file is
kept in the repo for future use but does not need to be deployed now.

## Seed Development Data

```bash
cd scripts
npm install
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
node seed_firestore.js
```

Seeds: 5 artists, 3 albums, 10 songs, 6 categories.

Audio URLs default to SoundHelix royalty-free samples. Artwork uses picsum.photos
placeholder images. Both are free public CDNs suitable for development and demo.

## Firebase Deploy (production)

```bash
firebase deploy --only firestore
```

Deploys Firestore rules and indexes. Storage rules are skipped until Storage is enabled.

## Play Store Submission

1. Build signed AAB: see Release Build above
2. Upload `app-release.aab` to Play Console → Internal Testing track
3. Complete store listing, privacy policy URL, and content rating questionnaire

## Environment Checklist

```
[ ] google-services.json placed at android/app/
[ ] lib/firebase_options.dart generated via flutterfire configure
[ ] Firebase Authentication initialized (Console → Get Started)
[ ] Anonymous auth provider enabled
[ ] Google auth provider enabled + SHA-1 fingerprint added
[ ] Release keystore created and local.properties configured
[ ] Firestore seeded: node scripts/seed_firestore.js
[ ] firebase deploy --only firestore
[ ] flutter analyze → 0 errors
[ ] flutter build appbundle --release → app-release.aab produced
```
