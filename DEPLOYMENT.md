# HimRaag — Deployment Guide

## Firebase Project

- **Project ID**: `himraag-prod`
- **Project Number**: `39471021909`
- **Android App ID**: `1:39471021909:android:1fb835736cc307e6f7b9dc`
- **Storage Bucket**: `himraag-prod.firebasestorage.app`

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
   flutter build appbundle --release \
     --dart-define=ALGOLIA_APP_ID=YOUR_APP_ID \
     --dart-define=ALGOLIA_SEARCH_KEY=YOUR_SEARCH_ONLY_KEY
   ```
   Output: `build/app/outputs/bundle/release/app-release.aab`

> **Note**: Without `--dart-define` flags, search returns no results. Get keys from Algolia dashboard.

## Firebase Setup (one-time per environment)

### Firestore

Rules and indexes are in the repo and deploy automatically:

```bash
firebase deploy --only firestore
```

### Storage (requires Console action first)

Storage **must** be initialized manually before deploying rules:

1. Go to: https://console.firebase.google.com/project/himraag-prod/storage
2. Click **Get Started** → choose **us-central1** → Done
3. Then deploy rules:
   ```bash
   firebase deploy --only storage
   ```

### Authentication (requires Console action first)

Auth **must** be initialized manually before providers can be enabled:

1. Go to: https://console.firebase.google.com/project/himraag-prod/authentication
2. Click **Get Started**
3. Enable **Anonymous** provider (Sign-in providers → Anonymous → Enable)
4. Enable **Google** provider (Sign-in providers → Google → Enable)
   - For Google Sign-In, add your release SHA-1 fingerprint:
     ```bash
     keytool -list -v -keystore himraag-release.jks -alias himraag
     ```
   - Add the SHA-1 to: Firebase Console → Project Settings → Android app → Add fingerprint

## Seed Development Data

```bash
cd scripts
npm install
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
node seed_firestore.js
```

Seeds: 5 artists, 3 albums, 10 songs, 6 categories.

> Audio and artwork files are NOT included. Upload real MP3/JPG files to Firebase Storage under `audio/<songId>.mp3`, `artwork/<albumId>.jpg`, `artists/<artistId>.jpg`.

## Firebase Deploy (full)

```bash
firebase deploy
```

Deploys: Firestore rules, Firestore indexes, Storage rules (if Storage is initialized).

## Play Store Submission

1. Ensure `minSdk 24` in `android/app/build.gradle` (already set)
2. Build signed AAB: see Release Build above
3. Upload `app-release.aab` to Play Console → Internal Testing track
4. Complete store listing, privacy policy URL, and content rating questionnaire

## Environment Checklist

```
[ ] google-services.json placed at android/app/
[ ] lib/firebase_options.dart generated via flutterfire configure
[ ] Firebase Authentication initialized (Console → Get Started)
[ ] Anonymous auth provider enabled
[ ] Google auth provider enabled + SHA-1 fingerprint added
[ ] Firebase Storage initialized (Console → Get Started)
[ ] storage.rules deployed: firebase deploy --only storage
[ ] Release keystore created and local.properties configured
[ ] Algolia --dart-define keys set at build time
[ ] Firestore seeded: node scripts/seed_firestore.js
[ ] flutter analyze → 0 errors
[ ] flutter build appbundle --release → app-release.aab produced
```
