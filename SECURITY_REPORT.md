# Security Audit (Phase 6)

**Date:** 2026-08-03 · **Scope:** app, Firebase, R2, Android signing, secrets.
No secret value is reproduced in this document.

## Summary

**No credential is exposed, and none ever was.** The two real findings were a
silent release-signing fallback (fixed) and two over-broad permissions (removed).

---

## Secrets

| Check | Result |
|---|---|
| Secrets in working tree | ✅ `.env/` holds R2 creds, the Firebase service-account JSON and the upload keystore. All four are gitignored. |
| Secrets tracked by git | ✅ None — `git ls-files` shows no `.jks`, `.env`, service-account or credential file. |
| **Secrets in git history** | ✅ **None ever committed.** `git log --all --diff-filter=A --name-only` matched only `scripts/lib/credentials.js`. |
| `credentials.js` contents | ✅ A **loader**, not a store. Reads from the gitignored `.env/` at runtime, returns values in memory only, and exposes just bucket name + public URL via `publicSummary()`. Never logs or serialises secret values. |
| Hardcoded keys in Dart | ✅ None found. |

`lib/firebase_options.dart` and `android/app/google-services.json` are gitignored.
These contain the Firebase **client** API key, which is *not* a secret — it is
shipped in every app binary and is designed to be public; access is controlled by
Firestore rules, not by key secrecy. Gitignoring them is harmless for security but
**does mean a clean clone cannot build** (see RELEASE_REPORT.md).

## Authentication

- Google Sign-In via `google_sign_in` 6.3.0 → Firebase Auth. Default scopes only
  (basic profile + email). The app never sees a password.
- Role is derived from **Firebase custom claims** (`getIdTokenResult(true)`,
  `admin_auth.dart:36`), set server-side by `scripts/set_claims.js`. Roles are
  never read from a client-writable location — so no client can grant itself admin.
- Guests (`guest_*` uids) never touch Firestore; their data stays on-device.

## Firestore rules

Reviewed in full — see FIRESTORE_AUDIT.md. Correctly written: public catalogue is
read-only to clients, all catalogue mutation is admin-gated, users are scoped to
their own document, `auditLogs` is genuinely append-only (`update, delete: if false`),
and submitters cannot self-approve. One P3 hardening suggestion (pin `ownerId` on
playlist update) is recorded there.

## Cloudflare R2

| Check | Result |
|---|---|
| Bucket root listable | ✅ No — returns 404 |
| Credentials in client app | ✅ None. The Flutter app only ever performs unauthenticated GETs of public object URLs; R2 API keys exist solely in Node scripts reading from `.env/`. |
| Transport | ✅ HTTPS only |

Content is public by design (a music catalogue). Note that public object URLs are
therefore guessable-if-known and not access-controlled — appropriate here, but it
does mean a shared URL streams without the app.

## Android

| Check | Result |
|---|---|
| `usesCleartextTraffic` | ✅ `false` |
| `network_security_config.xml` | ✅ `cleartextTrafficPermitted="false"`, system trust anchors. User CAs only under `debug-overrides` — **not** applied to release. No exception undermines the base config. |
| `allowBackup` | ✅ `false` — auth tokens and Hive boxes are excluded from Android auto-backup |
| `exported` activities | ✅ Only `MainActivity` (launcher) plus the audio service and media-button receiver, which must be exported to work |
| ProGuard/R8 | ✅ `minifyEnabled true`, `shrinkResources true` |
| Debug logging in release | ⚠️ `debugPrint` is used throughout. Flutter compiles `debugPrint` out in release, so this is not a leak. |

### Fixed: release builds could be silently debug-signed

`android/app/build.gradle` previously read:

```groovy
signingConfig keystoreProperties["keystoreFile"] ? signingConfigs.release : signingConfigs.debug
```

If `keystoreFile` were absent — a fresh clone, a CI runner, a teammate's machine —
the release build **succeeded and was signed with the debug key**. That produces an
artifact Play rejects, and worse, one that installs fine locally so the mistake
surfaces only at upload.

Now the release build throws a `GradleException` naming the missing property.
Debug builds still work without the keystore, because the check is deferred to
`gradle.taskGraph.whenReady` and only fires for release tasks.

### Fixed: two over-broad permissions removed

| Permission | Why it was wrong |
|---|---|
| `READ_EXTERNAL_STORAGE` (maxSdk 32) | Downloads go to `getApplicationDocumentsDirectory()` — app-private. No external read is ever performed. Verified: no reference in Dart or Kotlin. |
| `RECEIVE_BOOT_COMPLETED` | No boot receiver exists. `just_audio_background` does not need it. Verified: the only occurrence was the manifest line itself. |

Both drew Data Safety scrutiny for capability the app never used.

## Remaining permissions — all justified

`INTERNET`, `ACCESS_NETWORK_STATE` (streaming), `FOREGROUND_SERVICE` +
`FOREGROUND_SERVICE_MEDIA_PLAYBACK` (background audio), `WAKE_LOCK`,
`POST_NOTIFICATIONS` (playback notification). No location, contacts, camera,
microphone, SMS or storage permission is requested.

## Not verified in this environment

- Runtime certificate pinning: not implemented (acceptable — no sensitive API surface beyond Firebase SDKs, which pin internally).
- Penetration testing of the deployed rules: run `firebase emulators:exec` with rules unit tests for full coverage.
