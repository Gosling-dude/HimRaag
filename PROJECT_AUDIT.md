# HimRaag — Project Audit (Phase 1)

**Date:** 2026-08-03 · **Branch:** `feat/import-new-pahadi-songs` · **Flutter:** 3.44.4 / Dart 3.12.2

## Method

Everything below was checked against the running system, not inferred from
earlier reports. Where a claim could not be verified in this environment it is
marked **NOT VERIFIED** with the command needed to confirm it. No metric in this
document is estimated.

**Environment limit:** no Android device or emulator was attached
(`flutter devices` returned Windows/Chrome/Edge only; no AVD images exist). All
on-device behaviour is therefore user-verified or unverified — never asserted.

---

## Subsystem status

| Subsystem | Status | Evidence |
|---|---|---|
| Flutter app | ✅ | 93 Dart files, 15,402 LOC. `flutter analyze` → **0 issues** |
| Firebase Core / Auth | ✅ | Initialised in `main.dart:34`; Google Sign-In wired in `auth_providers.dart:36` |
| Firestore | ✅ | 1,375 documents live; rules and indexes reviewed (see FIRESTORE_AUDIT.md) |
| Cloudflare R2 | ✅ | 2,302 URLs probed, **2,299 reachable** (see R2_AUDIT.md) |
| Admin Dashboard | ✅ | Separate web entrypoint `lib/admin/main_admin.dart`; **not reachable from the consumer router** |
| Audio player | ✅ | `audio_player_service.dart` — play/pause/seek/next/prev/shuffle/repeat all present |
| Background playback | ⚠️ | `JustAudioBackground.init()` with 5 s timeout + platform restore fallback (`main.dart:61-77`) |
| Notification service | ⚠️ | Channel `com.himraag.app.audio`; **NOT VERIFIED** without a device |
| Search | ✅ **fixed** | Was issuing one Firestore query per keystroke; now debounced (4 tests) |
| Downloads | ✅ | App-private dir via `getApplicationDocumentsDirectory()` |
| Mini player | ✅ | `MiniPlayerOverlay` uses `SafeArea` — correct for API 36 edge-to-edge |
| Full player | ✅ | `full_player_screen.dart` + queue/lyrics views |
| Profile / Personalization | ✅ | Per-user doc under `users/{uid}`; guests stay local-only |
| Caching | ✅ | `ArtworkCacheManager`: 30-day disk cache, 4-way concurrency cap, 20 s timeout |
| Routing | ✅ | `go_router` 14.8.1, `app_router.dart` |
| Theme | ✅ | Light + dark themes wired via `themeModeProvider` |
| State management | ✅ | Riverpod 2.6.1 |
| Localization | ✅ **fixed** | `hi` was declared supported with **no delegates** — latent crash, now fixed |

---

## Issues found and resolved in this audit

| # | Severity | Issue | Resolution |
|---|---|---|---|
| 1 | **P0** | Release build **failed to compile** — stale `GeneratedPluginRegistrant.java` registered the `integration_test` dev-dependency plugin, which is absent from the release classpath | `flutter clean` before release builds; documented in RELEASE_REPORT.md |
| 2 | **P0** | `targetSdk 35` — Google Play requires **API 36** for new apps and updates from **2026-08-31** | Raised `compileSdk`/`targetSdk` to 36 |
| 3 | **P0** | A missing keystore **silently debug-signed** release builds instead of failing | Release now throws a `GradleException`; debug builds still work |
| 4 | **P1** | `supportedLocales` declared `hi` with `localizationsDelegates: []` — `MaterialLocalizations` missing on a Hindi-locale device, throwing on any dialog/tooltip/text-selection | Added the three `Global*Localizations` delegates |
| 5 | **P1** | Search issued a Firestore query **per keystroke** (typing "pahadi" = 6 round-trips) | 300 ms debounce + 4 regression tests |
| 6 | **P2** | Two unused Android permissions (`RECEIVE_BOOT_COMPLETED`, `READ_EXTERNAL_STORAGE`) | Removed — both confirmed unreferenced |
| 7 | **P2** | `assets/icons/app_icon.png` (1.6 MB) bundled but never loaded at runtime | Unbundled; still used by `flutter_launcher_icons` from disk |

## Open items not changed (require your decision)

| # | Severity | Issue |
|---|---|---|
| A | **P1** | **No `Cache-Control` header on any R2 object.** This is the root cause of the r2.dev 429 rate-limiting the app already defends against client-side. See R2_AUDIT.md — fixing it at the origin is the highest-value remaining win. |
| B | P2 | `lib/firebase_options.dart` and `android/app/google-services.json` are gitignored, so a clean clone cannot build. These files are not secret. |
| C | P3 | 48 pre-existing report files in the repo root. Left untouched. |

---

## Architecture notes

Layering is clean and consistently applied: `domain/models` → `data/{local,remote,services}`
→ `features/*/providers` → `features/*/presentation`. No layer inversions found.

Two entrypoints share one codebase: `lib/main.dart` (consumer Android app) and
`lib/admin/main_admin.dart` (web dashboard). Admin code is **not** reachable from
the consumer router, so it is tree-shaken out of the mobile binary — verified by
grepping `app_router.dart` for admin routes (no matches).
