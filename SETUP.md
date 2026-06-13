# HimRaag — Setup, Deployment & Release Checklist

## Prerequisites
- Flutter 3.22+ (`flutter --version`)
- Dart 3.3+
- Android Studio (or VS Code with Flutter extension)
- Node.js 20+ (for Firebase Functions)
- Firebase CLI (`npm install -g firebase-tools`)
- FlutterFire CLI (`dart pub global activate flutterfire_cli`)

---

## 1. Firebase Project Setup

```bash
# 1. Create project at console.firebase.google.com
#    Project name: himraag-prod

# 2. Enable:
#    - Authentication → Google Sign-In provider
#    - Firestore Database → Start in production mode
#    - Storage
#    - Analytics
#    - Crashlytics

# 3. Add Android app:
#    Package: com.himraag.app
#    Download google-services.json → place in android/app/

# 4. Add iOS app (optional):
#    Bundle ID: com.himraag.app
#    Download GoogleService-Info.plist → place in ios/Runner/
```

---

## 2. FlutterFire Configuration

```bash
cd "D:\Personal Projects\HimRaag"
flutterfire configure --project=himraag-prod
# This overwrites lib/firebase_options.dart with real values
```

---

## 3. Algolia Setup

```bash
# 1. Create account at algolia.com (free tier: 10k ops/month)
# 2. Create app: "himraag"
# 3. Create indices: songs, artists, albums
# 4. Configure index settings for songs:
#    Searchable attributes: title, artistName, albumTitle, tags
#    Facets: region, language, genre, mood, isApproved
#    Ranking: playCount (descending), then default

# 5. Add credentials to android/local.properties:
algoliaAppId=YOUR_ALGOLIA_APP_ID
algoliaSearchKey=YOUR_SEARCH_ONLY_API_KEY
```

---

## 4. Flutter Dependencies

```bash
flutter pub get
```

---

## 5. Backend Functions Deployment

```bash
cd backend
firebase login
firebase use himraag-prod
firebase functions:config:set algolia.app_id="YOUR_ID" algolia.admin_key="YOUR_KEY"

cd functions
npm install
npm run build
cd ..
firebase deploy --only functions,firestore:rules,firestore:indexes,storage:rules
```

---

## 6. Seed Initial Content

```bash
cd backend/scripts
# Place your serviceAccountKey.json here (download from Firebase console → Project Settings → Service accounts)
node seed_content.js
```

---

## 7. Font Assets

Download these fonts and place in `assets/fonts/`:
- HindSiliguri-Regular.ttf
- HindSiliguri-Medium.ttf
- HindSiliguri-SemiBold.ttf
- HindSiliguri-Bold.ttf

Source: https://fonts.google.com/specimen/Hind+Siliguri

---

## 8. App Icon

Replace placeholder icons:
```bash
flutter pub add --dev flutter_launcher_icons
# Add icon config to pubspec.yaml, then:
flutter pub run flutter_launcher_icons
```

App icon spec:
- 1024x1024 PNG, no alpha for Play Store
- Design: Mountain silhouette with musical note, purple/gold palette (#6B3FA0 + #E8A020)
- App name: "HimRaag" in Devanagari-inspired lettering

---

## 9. Splash Screen

```bash
flutter pub add --dev flutter_native_splash
# Configure flutter_native_splash.yaml:
# background_color: "#0D0D14"
# image: assets/images/splash_logo.png
flutter pub run flutter_native_splash:create
```

---

## 10. Run Debug Build

```bash
flutter run --debug
```

---

## 11. Release Build (Android)

### Generate Keystore (one-time)
```bash
keytool -genkey -v \
  -keystore himraag-release.jks \
  -alias himraag \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000
```

Store `himraag-release.jks` securely. NEVER commit it to Git.

### Configure Signing
Add to `android/local.properties` (not committed to Git):
```
keystoreFile=/path/to/himraag-release.jks
keystoreAlias=himraag
keystorePassword=YOUR_KEYSTORE_PASSWORD
keystoreStorePassword=YOUR_STORE_PASSWORD
```

### Build Release AAB (for Play Store)
```bash
flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### Build Release APK (for direct distribution)
```bash
flutter build apk --release --split-per-abi
```

---

## 12. Play Store Submission Checklist

### Account
- [ ] Google Play Developer account ($25 one-time fee)
- [ ] Developer profile complete with contact info

### App Content
- [ ] App name: "HimRaag - Pahadi Music"
- [ ] Short description (80 chars): "Authentic Pahadi folk music from Uttarakhand & Himachal"
- [ ] Full description (4000 chars): Cultural context, features, regions covered
- [ ] App icon: 512x512 PNG
- [ ] Feature graphic: 1024x500 PNG
- [ ] Screenshots: Min 2 per form factor (phone required, tablet optional)
- [ ] Promo video (optional but recommended)

### Content Rating
- [ ] Complete IARC questionnaire
- [ ] Music app category → "Music & Audio"
- [ ] Content rating: Everyone (no explicit content filter active)

### Privacy & Legal
- [ ] Privacy Policy URL live at https://himraag.app/privacy
- [ ] Privacy Policy covers:
  - [ ] Data collected (Firebase Analytics, Crashlytics, Auth)
  - [ ] Third-party SDKs (Google, Algolia)
  - [ ] No sale of user data
  - [ ] Data deletion process
  - [ ] Children's privacy (COPPA compliance)
- [ ] Terms of Service URL
- [ ] Content licensing declaration (for music used)

### App Permissions Justification
Required in Play Console Data Safety section:
- Internet: Music streaming
- Foreground Service: Background audio playback
- Wake Lock: Uninterrupted audio
- POST_NOTIFICATIONS: Now Playing notification (Android 13+)
- READ_EXTERNAL_STORAGE (API 32-): Download access (legacy)

### Data Safety Form
- [ ] No data sold
- [ ] Audio playback (local) — no data shared
- [ ] Firebase Auth: Email/Name optional
- [ ] Analytics: Anonymized usage data
- [ ] Crashlytics: Crash reports

### Technical
- [ ] Target API level 34 (Android 14)
- [ ] Min SDK 21 (Android 5.0)
- [ ] 64-bit native libraries included
- [ ] App bundle size < 150MB (use deferred loading if needed)
- [ ] No unused permissions
- [ ] DeepLink handling (optional for sharing songs)

### Release
- [ ] Internal testing track → QA team
- [ ] Closed testing (alpha) → 20+ testers from Uttarakhand/HP
- [ ] Open testing (beta) → Broader feedback
- [ ] Production rollout → 10% → 50% → 100%

---

## 13. Post-Launch Operations

### Content Upload Workflow
1. Upload audio file to Firebase Storage: `audio/{songId}.mp3`
2. Upload artwork to: `artwork/{songId}.jpg` (500x500 min, 1:1 ratio)
3. Create Firestore document in `songs/` with `isApproved: false`
4. Admin reviews content in Firebase Console
5. Set `isApproved: true` → Cloud Function auto-indexes to Algolia
6. Song appears in app within ~30 seconds

### Analytics
- Firebase Analytics tracks: session duration, songs played, downloads, search queries
- Use Firebase Console → Analytics for insights
- Set up custom events for: `song_played`, `song_downloaded`, `search_query`

### Monitoring
- Firebase Crashlytics → Crash-free rate target: >99.5%
- Firebase Performance → App startup time target: <2s cold start
- Algolia Dashboard → Search performance

---

## 14. Environment Variables Summary

| Variable | Where | Purpose |
|---|---|---|
| `ALGOLIA_APP_ID` | android/local.properties | Search app ID |
| `ALGOLIA_SEARCH_KEY` | android/local.properties | Read-only search key |
| Firebase config | google-services.json | All Firebase services |
| Keystore path/passwords | android/local.properties | Release signing |
| Algolia admin key | Firebase Functions config | Indexing (server-side only) |

---

## 15. Risks & Assumptions

### Assumptions Made
1. **Audio source URLs**: Songs must be uploaded to Firebase Storage. Placeholder URLs in seed data must be replaced.
2. **Font files**: HindSiliguri fonts must be downloaded manually (Google Fonts license allows redistribution).
3. **Content licensing**: All Pahadi music content must be properly licensed by the content team. The app has zero tolerance for copyrighted content without rights.
4. **Algolia free tier**: Sufficient for early stage (~10K operations/month). Scale to paid plan at 500+ daily active users.
5. **Backend moderation**: Admin SDK used via Firebase Console + custom admin web panel (out of scope here but Cloud Functions are ready).
6. **iOS**: Code is cross-platform but Play Store only was the primary target. iOS AppStore requires separate review.

### Known Limitations
1. **Lyrics**: Not auto-fetched. Must be manually entered per song.
2. **HLS Streaming**: Current implementation uses direct MP3 URLs. For adaptive bitrate streaming on slow connections, switch to HLS (.m3u8) served via Firebase Hosting CDN with encoding pipeline.
3. **Background downloads queue**: Downloads are non-persistent across app kills. Workmanager integration would make them truly background.
4. **Guest user sync**: Guest users' favorites/playlists are device-local only. Firebase UID is not persisted across installs.
5. **Offline search**: Search requires internet (Algolia). Offline search over downloaded songs is not implemented.
6. **Social features**: No sharing within app, no social playlists, no user profiles.

### Security
- Algolia search-only key is safe to embed in APK (read-only, no indexing ability).
- Admin key is ONLY in Firebase Functions config (server-side), never in the app.
- Firestore rules enforce admin-only writes for all content.
- No user data is stored beyond Firebase Auth profile + device-local Hive.
