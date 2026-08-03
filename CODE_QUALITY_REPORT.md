# Code Quality Report (Phase 2)

**Date:** 2026-08-03

## Static analysis

```
flutter analyze  →  No issues found!  (ran in 254.0s)
```

Zero warnings, zero lints, zero infos across 93 Dart files / 15,402 LOC, under
`flutter_lints` 4.0.0. This was already true before this audit and remains true after.

## Tests

```
flutter test  →  All tests passed!
```

| File | Tests | Covers |
|---|---:|---|
| `test/imported_catalog_test.dart` | 6 | R2-only audio URLs, non-zero durations, approval/licence flags, validator, unique IDs |
| `test/local_catalog_test.dart` | 5 | Bundle loads (697 songs / 102 albums / 148 artists), searchable, visibility filter, no "Unknown" sentinels, album+artist resolution |
| `test/widget_test.dart` | 1 | Placeholder |
| **`test/search_debounce_test.dart`** | **4** | **New this pass** — debounce correctness |
| **Total** | **16** | |

### New tests added

`test/search_debounce_test.dart` covers the one behavioural change made to a hot
path. It asserts:

1. a six-keystroke burst issues **exactly one** backend search;
2. no search fires before the debounce window elapses;
3. the settled query still returns its results;
4. typing then clearing leaves **no** pending search reaching the backend;
5. two settled queries issue two searches (the debounce does not swallow real input).

Without these, the debounce would have been an untested change to the app's
most-used screen.

## Dead code — investigated, mostly false alarms

| Candidate | Verdict |
|---|---|
| `lib/data/remote/algolia_search_datasource.dart` | **KEEP.** Algolia is not a dependency and the name misleads, but the file defines `SearchResult` and `SearchFilters`, both imported by `firestore_search_datasource.dart` and `search_providers.dart`. Deleting it breaks search. *Suggest renaming to `search_types.dart` later — deliberately not done now to avoid churn during a release.* |
| `lib/admin/**`, `lib/artist/artist_dashboard.dart` | **KEEP.** A separate web dashboard entrypoint. Verified **not reachable from `app_router.dart`**, so it is tree-shaken out of the mobile binary and costs nothing. |
| `assets/animations/`, `assets/fonts/` | **Declarations removed.** Both contained only `.gitkeep`; declaring them bundled the placeholder and nothing else. |
| `assets/icons/` | **Unbundled.** `app_icon.png` (1.6 MB) is read from disk by `flutter_launcher_icons` at build time and never loaded through the asset bundle at runtime — verified with a repo-wide grep, including `web/`. |
| `firebase_analytics` | **KEEP.** Zero `logEvent` calls, but the SDK auto-collects, so it is a *working* feature, not dead weight. It does carry a Data Safety obligation — see PLAYSTORE_COMPLIANCE_REPORT.md. |
| `just_audio_platform_interface` | **KEEP.** Used deliberately in `main.dart:61` to restore the default audio platform when background init fails. |

**Nothing was removed without first proving it unreferenced.** No duplicate widget,
utility, or repository was found — the layering is consistent.

## Dependencies

`flutter pub outdated` reports 85 packages with newer major versions available
(Riverpod 2→3, go_router 14→17, firebase_core 3→4, just_audio 0.9→0.10, …).

**Deliberately not upgraded.** Major-version bumps across Riverpod, go_router and
the Firebase suite are breaking changes; doing them during a release audit would
invalidate the device testing already done and risks far more than it fixes. This
is a post-launch task.

## Build warnings worth noting

1. **KGP deprecation** — `firebase_analytics` applies the Kotlin Gradle Plugin;
   future Flutter versions will fail on this. Upstream issue, no action available now.
2. **cupertino_icons font missing** — harmless: `CupertinoIcons` is referenced
   somewhere but the font is not bundled. Icons render blank *if any Cupertino icon
   is actually used*; no visual defect has been reported. Low priority.
3. **Java 8 source/target obsolete** — `sourceCompatibility VERSION_1_8`. Works
   today, will warn louder over time. Bumping to 11/17 is safe but was left alone
   to avoid changing build behaviour mid-release.
