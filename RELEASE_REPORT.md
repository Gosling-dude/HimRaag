# Release Audit (Phase 15)

**Date:** 2026-08-03 · **Branch:** `feat/import-new-pahadi-songs`

## ✅ Signing — verified by certificate comparison

This was the P0 of the whole audit. Reading the gradle file is not proof; the
artifact's actual certificate is.

**AAB certificate** (`keytool -printcert -jarfile app-release.aab`):
```
Owner:  CN=HimRaag, OU=HimRaag, O=HimRaag, L=Shimla, ST=Himachal Pradesh, C=IN
SHA256: 68:67:C2:7A:1C:FB:46:11:D3:F9:BB:98:DE:25:5E:42:A8:47:99:79:5B:A2:39:75:09:94:B0:2A:34:F4:91:78
Valid:  2026-07-03 → 2056-06-25
Algorithm: SHA256withRSA
```

**Upload keystore** (`keytool -list -v -keystore .env/himraag-upload-keystore.jks`):
```
Alias:  himraag-upload
SHA256: 68:67:C2:7A:1C:FB:46:11:D3:F9:BB:98:DE:25:5E:42:A8:47:99:79:5B:A2:39:75:09:94:B0:2A:34:F4:91:78
```

**IDENTICAL.** The release artifact is signed with the real upload key, not the
debug key. Validity to 2056 comfortably exceeds Play's 2033 minimum.

### Fixed: releases could be silently debug-signed

Previously:
```groovy
signingConfig keystoreProperties["keystoreFile"] ? signingConfigs.release : signingConfigs.debug
```
A missing `keystoreFile` — fresh clone, CI runner, teammate's machine — produced a
**successful, debug-signed release build**. Play rejects those, but only after
upload; locally it installs fine, so the mistake hides until the worst moment.

Now the release build throws a `GradleException` naming the missing property.
The check is deferred via `gradle.taskGraph.whenReady` and only fires for release
tasks, so debug builds still work without the keystore.

> ⚠️ **NOT VERIFIED:** exercising this failure path requires temporarily pointing
> `keystoreFile` at a bogus path, which was blocked in this environment (it mutates
> signing config). The guard is written but has never fired. **To verify yourself:**
> ```
> # in android/local.properties, temporarily set:
> keystoreFile=D:\\nonexistent\\bogus.jks
> flutter build appbundle --release    # must FAIL with "Refusing to debug-sign"
> flutter build apk --debug            # must still SUCCEED
> # then restore the real path
> ```
> The second command matters: it confirms the guard did not break debug builds.

## ❗ Fixed: the release build was broken

The first release build of this audit **failed to compile**:

```
GeneratedPluginRegistrant.java:59: error:
  package dev.flutter.plugins.integration_test does not exist
```

**Cause.** `GeneratedPluginRegistrant.java` is regenerated per build mode. Running
`flutter test` first regenerates it **including dev-dependency plugins**; the
subsequent release build reused that stale file, and `integration_test` is not on
the release classpath.

**Fix.** `flutter clean` before a release build. The file is gitignored, so this is
a local-environment hazard rather than a repo defect — but it will recur for anyone
who runs tests then builds.

> **Recommended standing rule — always `flutter clean` before a release build.**
> `scripts/build_release.ps1` should start with it if it does not already.

## Version

| Field | Value |
|---|---|
| `pubspec.yaml` version | `1.0.0+1` |
| versionName | **1.0.0** |
| versionCode | **1** |

Correct for a first release. **Every subsequent upload must increment
versionCode** — Play rejects duplicates.

## Build configuration

| Setting | Value | Verdict |
|---|---|---|
| `compileSdk` | **36** | ✅ raised from 35 |
| `targetSdk` | **36** | ✅ meets the 2026-08-31 Play floor |
| `minSdk` | 24 (Android 7.0) | ✅ ~98 % device coverage |
| `applicationId` | `com.himraag.app` | ✅ |
| `minifyEnabled` | true | ✅ R8 |
| `shrinkResources` | true | ✅ |
| ProGuard rules | present | ✅ keeps Flutter, Firebase, Hive, audio-service, OkHttp; `-dontwarn` for unused Play Core |
| AGP / Gradle / Kotlin | 8.7.3 / 8.12 / 2.1.0 | ✅ builds cleanly against compileSdk 36 |
| Java source/target | 8 | ⚠️ obsolete-option warnings; works |

### Mapping file — upload it

R8 is enabled, so production stack traces are obfuscated. The deobfuscation
mapping is at:

```
build/app/outputs/mapping/release/mapping.txt
```

`flutter build appbundle` embeds this in the AAB automatically, so Play and
Crashlytics get readable traces. **Keep a copy per release** — you cannot
deobfuscate old crashes without the matching file.

## Artifacts

| Artifact | Path | Size |
|---|---|---|
| **AAB** (upload this) | `build/app/outputs/bundle/release/app-release.aab` | 65,031,873 B (62.0 MB) |
| **APK** (sideload/test) | `build/app/outputs/flutter-apk/app-release.apk` | see FINAL_DELIVERABLES.md |

**Upload the AAB, not the APK** — Play has required App Bundles for new apps since
August 2021. The AAB's 62 MB is a multi-ABI publishing format; per-device downloads
are roughly 20–25 MB (see SIZE_OPTIMIZATION_REPORT.md).

## Reproducibility gap (P2)

`lib/firebase_options.dart` and `android/app/google-services.json` are gitignored,
so **a clean clone of this repo cannot build.** Neither file is secret — the
Firebase client API key ships in every binary and is protected by Firestore rules,
not obscurity.

Recommend committing both, or documenting a `flutterfire configure` bootstrap step
in SETUP.md. **Not changed here** — committing config files without asking is not
my call.

## Pre-upload checklist

- [x] Release AAB builds
- [x] Signed with the real upload keystore (fingerprints compared)
- [x] `targetSdk` meets the Play floor
- [x] Minification and resource shrinking enabled
- [x] Mapping file generated
- [ ] Keystore backed up somewhere safe — **losing it means you can never update the app**
- [ ] Play App Signing enrolment confirmed
- [ ] versionCode incremented for the *next* release
