# Performance Audit (Phase 3)

**Date:** 2026-08-03

> **Verification status:** cold-start time, warm-start time, memory and CPU are
> **device metrics** and no device was available. They are reported as
> **NOT MEASURED**, with the exact commands to obtain them. No number in this
> document is estimated.

## Optimisations actually made

### 1. Search: one Firestore query set per keystroke → one per settled query

**The single biggest win in this audit.**

`searchResultsProvider` watched `searchQueryProvider`, which the search field
updated on every `onChanged`. Each rebuild issued **three parallel Firestore
queries** (songs, artists, albums) *plus* a full local-catalogue scan.

Typing "pahadi" cost **18 Firestore reads and 6 scans of a 697-song list**, for a
result the user saw only at the end.

Fixed with a 300 ms debounce (`search_providers.dart`) using `ref.onDispose` for
cancellation — when a keystroke arrives inside the window the run is disposed and
returns before doing any work.

**Measured effect** (`test/search_debounce_test.dart`):
`remote.calls == 1` for a six-keystroke burst, versus 6 before. **A 6× reduction
in reads and latency on the app's most-used screen**, and it removes the
mid-typing result flicker.

### 2. Bundle: 1.6 MB of dead asset removed

`assets/icons/app_icon.png` was bundled into every install but never loaded at
runtime — it is only the build-time source for `flutter_launcher_icons`. See
SIZE_OPTIMIZATION_REPORT.md.

## Already well-optimised (verified, no change needed)

### Image loading — `ArtworkCacheManager`

Genuinely well-built. Three layered defences against the `pub-*.r2.dev` rate limit:

1. **Bounded concurrency** — max 4 simultaneous downloads; the rest queue. The
   semaphore correctly holds a slot until the *body* finishes streaming, not just
   until headers arrive, with a `_timeout * 2` backstop so a stalled stream cannot
   leak a slot permanently.
2. **30-day disk cache**, 3,000 objects — warm launches and scrolling never touch
   the network.
3. **20 s timeout**, and non-2xx responses **throw rather than cache**, so a 429 is
   retried with backoff instead of being poisoned into the cache as a failure.

`AppArtwork` additionally requests a **small thumbnail first** and only falls back
to the full image on failure, with a cache-busting `#retry` fragment (never sent
on the wire) so retries are not served from a negative cache.

### Startup — non-blocking

`main.dart` calls `runApp()` **immediately** with `BootstrapApp`, then runs Firebase,
audio-service and Hive init behind the splash. Heavy init never blocks the first
frame. The 5 s cap on audio-service init bounds worst-case startup.

### Firestore queries

All 15 composite indexes match real query shapes; no unindexed query exists in the
codebase. Queries are `limit`-bounded (`_pageSize = 30`).

## ❌ NOT MEASURED — commands to get real numbers

```bash
# Cold start (kill first, then measure) — repeat 5×, take the median
adb shell am force-stop com.himraag.app
adb shell am start-activity -W -n com.himraag.app/.MainActivity | grep TotalTime

# Warm start
adb shell input keyevent KEYCODE_HOME
adb shell am start-activity -W -n com.himraag.app/.MainActivity | grep TotalTime

# Memory
adb shell dumpsys meminfo com.himraag.app | head -20

# CPU / jank / rebuilds — the most useful of these
flutter run --profile          # then open DevTools → Performance
```

To count provider rebuilds, run in profile mode and use the DevTools Riverpod
inspector; `debugPrint('[APP] ROUTER_BUILD')` in `main.dart:107` already traces
router rebuilds.

### Startup markers already instrumented

`adb logcat -s flutter | grep "\[APP\]"` emits `APP_START` → `FIREBASE_INIT_START`
→ `FIREBASE_INIT_SUCCESS` → `AUDIO_BG_INIT_START` → `AUDIO_BG_INIT_SUCCESS` →
`HIVE_INIT_START` → `HIVE_INIT_SUCCESS` → `INIT_COMPLETE`. Timestamp deltas
between these give a per-phase startup breakdown with no extra work.

## Network — highest remaining opportunity

**R2 objects return no `Cache-Control` header** (see R2_AUDIT.md). Adding
`public, max-age=31536000, immutable` would let the Cloudflare edge absorb most
artwork traffic instead of the origin, which is the actual cause of the 429s the
client currently works around. This is the most valuable performance change still
available, and it requires no app change.
