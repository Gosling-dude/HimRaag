# Crash & Resilience Audit (Phase 14)

**Date:** 2026-08-03

## Crash reporting is wired correctly

`main.dart:37-45` installs **both** required handlers:

```dart
FlutterError.onError = ... recordFlutterFatalError(details);
PlatformDispatcher.instance.onError = ... recordError(error, stack, fatal: true);
```

The second matters and is often missed — `FlutterError.onError` alone does not
catch errors raised outside the widget-build zone (async gaps, platform channels).
With both, Crashlytics sees framework *and* Dart-runtime crashes.
`firebase_crashlytics_collection_enabled=true` is set in the manifest.

## Failure paths verified in code

| Scenario | Handling | Verdict |
|---|---|---|
| **Audio-service init hangs** | 5 s timeout **and** the default `JustAudioPlatform` is restored, avoiding the `LateInitializationError` that would otherwise kill all playback (`main.dart:61-77`) | ✅ Excellent — this is the subtlest failure mode in the app and it is handled |
| **Firestore unreachable** | `ensureUserDoc` try/catch → returns device-local profile (`user_profile_service.dart:85-88`) | ✅ Degrades |
| **R2 image 429 / 404 / timeout** | Non-2xx throws instead of caching; widget retries with backoff; terminal branded fallback | ✅ Degrades |
| **R2 image hangs** | 20 s request timeout, plus a `_timeout * 2` backstop timer so a stalled stream cannot leak a concurrency slot | ✅ Bounded |
| **Slow network** | Bounded concurrency (4) + timeouts throughout | ✅ |
| **Search datasource throws** | `searchSongs`/`searchArtists`/`searchAlbums` catch, log, and rethrow into the `FutureProvider`, surfaced as an `AsyncError` in the UI | ✅ |
| **No network at launch** | Bundled catalogue renders (697 songs) | ✅ |
| **Process death mid-download** | Download state persisted in Hive | ✅ |
| **Logout** | Auth stream drives the router; guest data stays local | ✅ |

### Fixed this pass: a latent crash on Hindi-locale devices

`supportedLocales` declared `Locale('hi')` while `localizationsDelegates` was
**empty**. On a device set to Hindi, Flutter resolves the locale to `hi`, then
`MaterialLocalizations.of(context)` finds no delegate supporting it — throwing the
moment any dialog, tooltip, date picker or text-selection menu appears.

This never fired for you because your test device is English-locale. Given the
app's Pahadi/Himachali audience, a meaningful share of real users run Hindi
system locales, so this was a live crash waiting for launch day.

Fixed by adding `GlobalMaterialLocalizations`, `GlobalWidgetsLocalizations` and
`GlobalCupertinoLocalizations` delegates (`flutter_localizations` was already a
declared dependency but had never been imported).

**To verify:** set the device to हिन्दी (Settings → System → Languages), open the
app, and long-press any text field or trigger a dialog. It should not crash.

## ❌ NOT VERIFIED — resilience checklist

| # | Scenario | How to induce |
|---|---|---|
| 1 | Network loss mid-playback | `adb shell svc wifi disable` while streaming |
| 2 | Firestore unavailable | Block `firestore.googleapis.com` |
| 3 | R2 unavailable | Block the `pub-*.r2.dev` host |
| 4 | Slow network | Emulator network profile, or a throttling proxy |
| 5 | Expired / invalid auth token | Revoke app access in the Google account, then reopen |
| 6 | **Background kill** | `adb shell am kill com.himraag.app` while playing, then reopen |
| 7 | **Low memory** | Developer options → "Don't keep activities", then background the app |
| 8 | **Hindi locale** (new) | Set system language to हिन्दी; open dialogs |
| 9 | Rapid navigation | Tab-switch and back-navigate quickly for ~60 s |

```bash
# Watch for crashes and the app's own diagnostic markers
adb logcat -s flutter AndroidRuntime | grep -E "\[APP\]|FATAL|Exception"
```

Items 6 and 7 are the classic Android killers and are the two I would prioritise.

## Post-launch

Crashlytics will surface real-world crashes automatically. Watch the console for
the first 48 hours after release; the handlers above ensure both fatal and non-fatal
Dart errors are reported with stack traces.
