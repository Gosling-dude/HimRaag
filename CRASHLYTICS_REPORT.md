# HimRaag — Firebase Crashlytics Verification Report

_Audit date: 2026-08-04 · Project: `himraag-prod` · Package: `com.himraag.app`_

## Status

| | |
|---|---|
| **Configuration** | ✅ Complete — verified against Firebase's recommended Flutter setup |
| **End-to-end crash delivery** | ⚠️ **Not yet confirmed in the Firebase Console** |

The configuration audit passed on every point and required **no changes**. What
has *not* happened is a test crash being observed arriving in the console. See
[Outstanding](#outstanding-end-to-end-verification) below for the exact steps to
close that out.

---

## 1. Configuration audit

Every item below was verified by direct inspection, not assumed.

| Check | Location | Result |
|---|---|---|
| `firebase_crashlytics` dependency | `pubspec.yaml:30` | ✅ `^4.1.0` |
| `firebase_core` dependency | `pubspec.yaml:26` | ✅ `^3.4.0` |
| Google Services Gradle plugin declared | `android/settings.gradle` | ✅ `com.google.gms.google-services` `4.4.1` |
| Crashlytics Gradle plugin declared | `android/settings.gradle` | ✅ `com.google.firebase.crashlytics` `3.0.1` |
| Both plugins applied to the app module | `android/app/build.gradle:5-6` | ✅ |
| `google-services.json` present | `android/app/` | ✅ (gitignored — see §3) |
| — project id | | ✅ `himraag-prod` |
| — package name | | ✅ `com.himraag.app`, matches `applicationId` |
| — mobilesdk app id | | ✅ `1:39471021909:android:1fb835736cc307e6f7b9dc` |
| `firebase_options.dart` present | `lib/` | ✅ (gitignored — see §3) |
| — `appId` / `projectId` / `messagingSenderId` | | ✅ all match `google-services.json` |
| `Firebase.initializeApp()` before handlers | `lib/main.dart:35` | ✅ |
| Flutter framework errors captured | `lib/main.dart:38-41` | ✅ `FlutterError.onError` → `recordFlutterFatalError` |
| Async/platform errors captured | `lib/main.dart:42-46` | ✅ `PlatformDispatcher.instance.onError` → `recordError(fatal: true)` |
| `INTERNET` permission | `AndroidManifest.xml:5` | ✅ |
| Proguard mapping upload (release) | `android/app/build.gradle` | ✅ implicit — `minifyEnabled true` + Crashlytics plugin uploads mappings, so release traces deobfuscate |
| Leftover/temporary crash hooks | `lib/`, `test/`, `android/` | ✅ none |

**Conclusion:** no configuration changes were required or made. The error-handler
pair covers both halves of the Dart error surface — `FlutterError.onError` for
framework/build errors and `PlatformDispatcher.instance.onError` for uncaught
async errors — which is the current recommended approach (it supersedes the older
`runZonedGuarded` pattern). Native JVM/NDK crashes are captured by the Gradle
plugin independently of Dart.

---

## 2. Temporary test hook — added and removed

A debug-only trigger was added to exercise the pipeline, then removed before the
Release Candidate.

**Added** at `lib/main.dart` (after the error handlers):

```dart
const crashTest = bool.fromEnvironment('CRASH_TEST');
if (kDebugMode && crashTest) {
  Future<void>.delayed(const Duration(seconds: 6), () {
    FirebaseCrashlytics.instance.crash();
  });
}
```

Double-gated so it could never reach a user:

1. `kDebugMode` is a compile-time constant, `false` in profile/release — Dart
   tree-shakes the whole block out of non-debug builds.
2. `CRASH_TEST` defaults to `false`, so even a debug build stays inert unless
   built with `--dart-define=CRASH_TEST=1`.

No UI file was touched; the hook lived entirely in `main.dart`.

**Removed.** Verified by `grep -rn "CRASH_TEST\|TEMPORARY\|\.crash()\|forceCrash\|testCrash" lib/ test/ android/`
→ no matches. `lib/main.dart`'s only remaining diff against the previous commit
is the Hindi localization fix. **The Release Candidate contains no crash hook.**

---

## 3. Note on gitignored Firebase config

`android/app/google-services.json` and `lib/firebase_options.dart` are both
gitignored. That is correct — they carry per-environment API keys — but it means
**a fresh clone cannot build until they are restored.** Anyone rebuilding this
tag from scratch needs both files placed manually (re-downloadable from the
Firebase Console for project `himraag-prod`).

---

## Outstanding: end-to-end verification

The only unverified link is delivery: no test crash has been observed arriving in
the Firebase Console. To close it:

1. Rebuild the armed debug APK:
   ```
   flutter build apk --debug --dart-define=CRASH_TEST=1
   ```
2. Install it: `adb install -r build/app/outputs/flutter-apk/app-debug.apk`
3. Launch **HimRaag from the launcher — not via `flutter run`.** An attached
   debugger can absorb the signal.
4. Wait ~6 seconds past the splash. The app dies instantly with no dialog.
   `adb logcat | grep CRASH_TEST` shows `armed` then `firing` first.
5. **Relaunch the app and leave it open ~30 seconds.** This is the step most
   often missed: a native crash is written to disk and uploaded only on the
   *next* launch. Without the relaunch nothing ever reaches the console.
6. Firebase Console → `himraag-prod` → Crashlytics → **Crashes**. Expect a fatal
   native `SIGSEGV` in `com.himraag.app`, typically within 2–5 minutes.

If it does not appear, the cause is almost always step 5, followed by the device
having no network on relaunch.

**Re-remove the hook afterwards** — it must not be committed.
