# Splash Screen Report

Date: 2026-07-04 · Branch: `feat/import-new-pahadi-songs`

## What was built

The app now opens with the branded HimRaag artwork (`assets/images/opening_page.png`,
941×1672, full-bleed `BoxFit.cover`) instead of dropping the user straight onto Home
after a long native launch screen.

### Architecture change (`lib/main.dart` + `lib/core/splash/bootstrap_app.dart`)

**Before:** `main()` awaited Firebase init, Crashlytics wiring, the audio background
service (up to 5 s timeout), and Hive **before** calling `runApp()`. The user stared at
the bare Android launch screen for the entire initialization.

**After:** `runApp()` fires immediately with `BootstrapApp`, which:

1. Shows the splash artwork on the very first Flutter frame while the exact same
   initialization sequence (unchanged, moved verbatim into `_initialize()`) runs
   behind it.
2. Holds the splash for a **minimum of 1600 ms** so fast startups don't flicker.
3. Keeps the splash up **as long as initialization needs** on slow devices — the app is
   never revealed before init completes.
4. Builds the real app *underneath* the splash, then fades the splash out over
   **650 ms** (`Curves.easeOut`) — the app is already rendering during the fade, so
   there is no blank frame between splash and Home.
5. Initialization failures are caught and logged (`[APP] BOOTSTRAP_INIT_ERROR`) so a
   failed init can never leave the splash on screen forever.

### No white flash / no blank screen

- Native `LaunchTheme` windowBackground is `#0D0D14` (dark) with dark status/navigation
  bars — unchanged, verified in `android/app/src/main/res/values/styles.xml`.
- `BootstrapApp` paints an opaque `#0D0D14` backstop under everything, matching the
  native launch background, so the native→Flutter handoff is dark→dark.
- The splash PNG fades in over 220 ms on the frames where it is still decoding
  (`frameBuilder`), so even the decode gap reads as an intentional fade, never a flash.
- `gaplessPlayback: true` prevents any re-decode blink.

### Timing summary

| Phase | Duration |
|---|---|
| Native launch screen (dark, unavoidable pre-Flutter) | device-dependent, typically < 1 s in release |
| Branded splash minimum hold | 1600 ms |
| Branded splash maximum hold | until initialization completes |
| Fade into app | 650 ms |

Perceived total: ~1.6–2.3 s on a healthy startup — in the requested 1.5–2.5 s window.

## Debug vs release

The mechanism is pure Dart + native theme resources; it behaves identically in debug
and release (release is faster because init and first-frame are faster).

## Side benefit

Time-to-first-pixel improved: previously the first Flutter frame waited for
Firebase + audio service + Hive; now the splash frame renders as soon as the engine is
up, and initialization overlaps with the splash's minimum hold instead of adding to it.

## Verification

- `flutter analyze` — no issues.
- `flutter test` — 12/12 passed.
- Release APK + AAB build from this code (see final deliverables).
- Device smoke test (cold start on physical hardware) — to be confirmed in your final
  manual review; no Android device/emulator was attached to this build machine.
