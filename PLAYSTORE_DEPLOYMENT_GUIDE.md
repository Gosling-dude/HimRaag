# HimRaag — Play Store Deployment Guide

_Pahadi Music, Heart of the Hills — Android production release._

This guide covers shipping HimRaag to Google Play after the Cloudflare R2 +
Firestore migration. The app now streams audio from R2 (no bundled MP3s), so the
release artifact is small and the catalog scales server-side.

---

## 0. Prerequisites

| Item | Value |
|---|---|
| Application ID | `com.himraag.app` (confirm in `android/app/build.gradle`) |
| Firebase project | `himraag-prod` |
| Audio/artwork host | Cloudflare R2 bucket `himraag-audio`, public base `https://pub-…r2.dev` |
| Flutter | stable channel, Dart SDK ≥ 3.3 |
| Min / target SDK | confirm `minSdkVersion` (21+) and `targetSdkVersion`/`compileSdk` 35 |

---

## 1. Release signing

Google Play requires a signed AAB. **Never commit the keystore or its passwords**
(the repo `.gitignore` already excludes `**/*.jks`, `**/*.keystore`,
`key.properties`).

1. Generate an upload keystore (one time):
   ```bash
   keytool -genkey -v -keystore himraag-upload.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias himraag
   ```
2. Create `android/key.properties` (gitignored):
   ```properties
   storePassword=<store-password>
   keyPassword=<key-password>
   keyAlias=himraag
   storeFile=../himraag-upload.jks
   ```
3. Wire it into `android/app/build.gradle`:
   ```gradle
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }
   android {
     signingConfigs {
       release {
         keyAlias keystoreProperties['keyAlias']
         keyPassword keystoreProperties['keyPassword']
         storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
         storePassword keystoreProperties['storePassword']
       }
     }
     buildTypes {
       release { signingConfig signingConfigs.release }
     }
   }
   ```
4. Enrol in **Play App Signing** (recommended): upload your AAB; Google manages
   the app signing key, you keep the upload key.

---

## 2. Build the release artifacts

```bash
flutter pub get
flutter analyze
flutter test
flutter build apk --release        # for sideload/QA   → build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle --release  # for Play upload   → build/app/outputs/bundle/release/app-release.aab
```
Upload the **.aab** to Play Console (APK is for direct QA installs only).

---

## 3. Play Console setup

1. **Create app** → name "HimRaag", default language, app (not game), free.
2. **Store listing:** short + full description, app icon (512×512), feature
   graphic (1024×500), ≥2 phone screenshots, category *Music & Audio*, contact
   email, tags.
3. **App access:** if any content sits behind sign-in, provide test credentials.
4. **Ads:** declare whether the app shows ads (currently: no).
5. **Content rating:** complete the IARC questionnaire (music app → typically
   *Everyone*; declare UGC if users submit songs).
6. **Target audience:** select age groups; if not targeting children, say so.
7. **Data safety:** declare data collected (account email via Google Sign-In,
   analytics/crash via Firebase Analytics + Crashlytics, playback/usage). State
   encryption in transit and deletion path.
8. **Government apps / financial / health:** N/A.

---

## 4. Privacy policy requirements

Google requires a publicly-hosted privacy policy URL. It must disclose:
- **Identity / account:** email + profile via Google Sign-In (Firebase Auth).
- **Usage & diagnostics:** Firebase Analytics + Crashlytics (device, events,
  crash logs).
- **Content delivery:** audio/artwork served from Cloudflare R2 (CDN logs).
- **Storage:** favourites/recently-played cached locally (Hive); downloads
  stored on-device.
- Data retention, third parties (Google/Firebase, Cloudflare), and a contact for
  deletion requests.

Host it (e.g. Firebase Hosting / GitHub Pages) and paste the URL into Play
Console → *App content → Privacy policy*.

---

## 5. Content declarations (important for HimRaag)

- **Music rights:** every track must be owner-supplied or licensed. The import
  pipeline tags imported tracks `license=LICENSED`, `rightsCleared=true`, and
  `reviewRequired=true`. **Approve tracks in the Admin Dashboard → Metadata
  Review only after confirming you hold distribution rights.** Do not publish
  `DEMO_ONLY` content.
- **UGC (if artist submissions are enabled):** provide a moderation policy and an
  in-app report/block mechanism.
- **Copyright contact:** supply a takedown/DMCA contact in the listing.

---

## 6. Testing track setup

1. **Internal testing** (fastest, up to 100 testers): upload the AAB, add tester
   emails or a Google Group, share the opt-in link. Validate streaming from R2,
   sign-in, playback, downloads on real devices.
2. **Closed testing** (alpha/beta): broader audience; required before production
   if you want Play's pre-launch report and tester feedback.
3. Review the **pre-launch report** (Play runs the app on real devices) for
   crashes, accessibility, and policy issues.

---

## 7. Production rollout

1. Promote the tested build to **Production**.
2. Write release notes.
3. Use a **staged rollout** (e.g. 10% → 50% → 100%) and watch Crashlytics +
   Play vitals (ANR/crash rate) between stages.
4. Confirm Firestore security rules (`firestore.rules`) and Storage rules are
   deployed for prod, and that only `isApproved`/`isPublished` content is
   queryable by consumers.
5. Verify the R2 bucket has public read on `audio/` + `artwork/` and that the
   public base URL in the shipped catalog matches production.

---

## 8. Post-launch checklist

- [ ] Crashlytics shows no release-blocking crashes.
- [ ] R2 egress/bandwidth monitored (Cloudflare dashboard).
- [ ] Firestore read budget within free-tier/billing expectations.
- [ ] New imports go through Metadata Review before `isApproved=true`.
- [ ] Privacy policy URL live and accurate.

---

_Security note: keystores, `key.properties`, Firebase service-account JSON, and
Cloudflare R2 keys must never be committed. They live in the gitignored `.env/`
folder and your local signing setup only._
