# GOOGLE SIGN-IN AUDIT — HimRaag

_Generated: 2026-07-03 · branch `feat/import-new-pahadi-songs`_

## Symptom

```
PlatformException(sign_in_failed,
com.google.android.gms.common.api.ApiException: 10, null, null)
```

`ApiException: 10` = `DEVELOPER_ERROR` from Google Play Services: the calling
app's **signing certificate + package name combination is not registered with
any OAuth client** in the Firebase/Google Cloud project.

## Root cause (confirmed)

The Firebase Android app `com.himraag.app` (`1:39471021909:android:1fb8…`) had
**zero SHA certificate fingerprints registered** (verified via the Firebase
Management API: `GET …/androidApps/{app}/sha` → empty list). Consequently:

1. Google never provisioned an **Android OAuth client** for the app, and
2. the shipped `android/app/google-services.json` contained an **empty
   `oauth_client: []`** — nothing for the `google_sign_in` plugin to match
   against at runtime → error code 10 on every attempt.

The Google provider itself was already enabled in Firebase Authentication (the
web-type OAuth client existed) — the missing piece was purely the SHA
registration.

## Full audit checklist

| Item | State found | Action |
|---|---|---|
| `google-services.json` | `oauth_client: []` (empty) — stale | Re-downloaded after fix; now has 2 Android clients + 1 web client |
| Firebase Android app | exists, `com.himraag.app`, correct project `himraag-prod` | none needed |
| SHA-1 (debug) | **not registered** | registered `10:02:F8:83:…:A2:B3` |
| SHA-256 (debug) | **not registered** | registered `BF:E3:4F:…:EF:ED` |
| SHA-1 (release) | **no release keystore existed** | created upload keystore, registered `C0:EB:64:…:34:05` |
| SHA-256 (release) | — | registered `68:67:C2:…:91:78` |
| OAuth client IDs | none for Android | auto-provisioned by Google after SHA registration (verified type-1 ×2 + type-3 ×1 in refreshed config) |
| package name / applicationId | `com.himraag.app` in manifest-namespace, `build.gradle`, `google-services.json`, `firebase_options.dart` — all consistent | none needed |
| debug keystore | `%USERPROFILE%\.android\debug.keystore`, alias `androiddebugkey` | fingerprints extracted + registered |
| release keystore | **missing** — release builds silently fell back to debug signing (`build.gradle` fallback) | generated `.env/himraag-upload-keystore.jks` (RSA-2048, 30y validity); credentials in `.env/upload-keystore-credentials.txt` (gitignored); signing props wired via `android/local.properties` (gitignored) |
| Firebase Auth providers | Google **enabled**; anonymous used for guest mode | none needed |
| Google Cloud OAuth credentials | web client existed; Android clients absent | auto-created (see above) |
| Play Integrity | not used by google_sign_in v6 flow | n/a |
| `google_sign_in` plugin | `^6.2.2`, code uses v6 `GoogleSignIn().signIn()` + Firebase credential exchange — correct pairing | none needed |
| `firebase_options.dart` | Android `apiKey`/`appId`/`projectId` match `google-services.json` | none needed |
| `AndroidManifest.xml` | INTERNET permission present; no sign-in-specific entries required | none needed |
| `build.gradle` | `com.google.gms.google-services` plugin applied; `minSdk 24`, `targetSdk 34` | none needed |
| Error handling in app | `sign_in_screen.dart` surfaces failures in a SnackBar (no suppression) | none needed |

## Fixes applied

1. **Registered 4 SHA fingerprints** (debug + release × SHA-1/SHA-256) on the
   Firebase Android app via the Firebase Management API
   (`scripts/fix_signin_config.js` — idempotent, re-runnable).
2. **Refreshed `android/app/google-services.json`** from the live project;
   it now contains:
   - 2 × `client_type: 1` (Android OAuth clients — one per certificate)
   - 1 × `client_type: 3` (web client, used by the plugin for the Firebase
     ID-token exchange)
3. **Created a real release upload keystore** and wired it into the existing
   `signingConfigs.release` (which previously always fell back to debug
   signing because no keystore properties existed). Play-Store AABs are now
   signed with a dedicated upload key whose fingerprints are registered.

## Why this fixes error 10

With the SHA-1 of the signing certificate registered, Play Services can match
the APK's certificate+package to the provisioned Android OAuth client, and the
plugin obtains tokens against the web client ID present in the refreshed
config. All three legs (package, certificate, OAuth client) now agree for both
debug and release signatures.

## Runtime verification

- `flutter build apk --release` + `flutter build appbundle --release` —
  **succeed** (APK 59.8 MB, AAB 60.7 MB, 2026-07-04).
- `apksigner verify --print-certs` on the release APK confirms the signer is
  the new upload key: SHA-1 `c0eb64dd8acd32488cb03a47cfeceaa0eae93405` —
  byte-identical to the release fingerprint registered in Firebase. The
  package + certificate + OAuth-client triple is therefore consistent for
  both debug installs and this release artifact.
- **On-device login test:** this workstation has no attached Android device
  and no hypervisor for the emulator (AEHD/Hyper-V not installed — the
  emulator aborts with "x86_64 emulation currently requires hardware
  acceleration"), so the interactive Google account-picker flow could not be
  exercised in this session. Everything machine-verifiable has been verified.
  To confirm on hardware: install the fresh APK, tap **Continue with Google**
  — the account picker should appear and `authStateChanges` fires with the
  Google user (the app then routes to Preferences on first run).
  If it still fails on a Play-Store-installed build later, the only remaining
  variable is **Play App Signing**: after uploading the AAB, copy the
  app-signing SHA-1/SHA-256 from Play Console → App integrity into Firebase
  (Project settings → Android app → Add fingerprint) — the upload-key
  fingerprints registered here cover internal/side-loaded installs.
