# Playback Audit (Phase 9)

**Date:** 2026-08-03

> ## ⚠️ Verification status
> **No Android device or emulator was available in this environment**
> (`flutter devices` → Windows/Chrome/Edge only; no AVD images installed).
> Playback behaviour **cannot be measured here.** Everything below is either a
> **static code fact**, a **network fact**, or explicitly marked **NOT VERIFIED**
> with the steps for you to confirm it. No playback metric in this document is
> estimated or assumed.
>
> You reported the previous APK played correctly on your device. That was an
> **API 35** build; this release targets **API 36** — see the re-test list below.

## What is verified

### Every track can stream — network-verified

All **956/956** audio URLs returned HTTP 200/206 (`scripts/verify_all_urls.js`).
No track is unplayable due to a missing object.

### Seeking is supported — protocol-verified

R2 objects return **`Accept-Ranges: bytes`**, confirmed by direct `HEAD` probes.
Range requests are the mechanism `just_audio` uses to seek, so seek works at the
transport level. `Content-Type: audio/mpeg` is correct on every sampled object.

### Controls exist in code

| Control | Implementation |
|---|---|
| play / pause / stop | `audio_player_service.dart:87-89` |
| seek | `:91` → `_player.seek()` |
| next / previous | `:93`, `:98` → `seekToNext` / `seekToPrevious` |
| repeat (off/one/all) | `:105-109` → `LoopMode.off/one/all` |
| shuffle | `:113-115` → `setShuffleModeEnabled` + `shuffle()` |
| queue | `playSong(..., queue:, queueIndex:)`, `playFromQueue(index)` |

### Background playback — resilient by design

`main.dart:61-77` wraps `JustAudioBackground.init()` in a 5-second timeout **and**
captures the default `JustAudioPlatform` first, restoring it if init fails.

This matters: `JustAudioBackground.init()` swaps the global platform
*synchronously* and then awaits the service binding. If that await hangs, a naive
timeout would leave a half-installed plugin whose `_audioHandler` is never
assigned — every subsequent `setAudioSource()` throws `LateInitializationError`
and playback dies silently at 00:00. The restore path degrades to
foreground-only audio instead. This is correct and unusually careful.

Manifest declarations are right: `FOREGROUND_SERVICE_MEDIA_PLAYBACK`,
`foregroundServiceType="mediaPlayback"`, `MediaBrowserService` intent filter, and
an exported `MediaButtonReceiver` (which is what makes Bluetooth/headset buttons work).

## ❌ NOT VERIFIED — please confirm on the new APK

Because the target API changed, please re-check these:

| # | Check | How |
|---|---|---|
| 1 | Play, pause, seek, next, previous | Play any track; scrub the bar |
| 2 | Shuffle and repeat (off → one → all) | Toggle both in the full player |
| 3 | **Background playback** | Start a track, press Home, confirm audio continues |
| 4 | **Notification controls** | Pull down the shade; play/pause/skip from the notification |
| 5 | **Lock-screen controls** | Lock the phone; confirm artwork and transport controls appear |
| 6 | **Bluetooth / headset** | Pair a device; test play-pause and next via its buttons |
| 7 | Queue behaviour | Play an album; confirm auto-advance and queue order |
| 8 | **Edge-to-edge layout (new)** | Confirm the mini player and bottom nav are not hidden behind the system nav bar |
| 9 | **Tablet orientation (new)** | On a ≥600dp screen, API 36 ignores `portrait` lock — check landscape is usable if you support tablets |

Items 8 and 9 are new consequences of the API 36 upgrade and were not exercised
by your earlier testing.

### If background playback fails on a specific device

`main.dart` logs `[APP] AUDIO_BG_INIT_FAILED — restored default platform: …`.
Capture it with:

```bash
adb logcat -s flutter | grep AUDIO_BG
```

Seeing that line means the app fell back to foreground-only audio: music still
plays, but lock-screen and notification controls are absent. That is the designed
degradation, not a crash.
