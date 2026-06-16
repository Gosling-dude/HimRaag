# HimRaag — Playback Verification Report

_Generated for the local-audio import (15 tracks, ~72:57 total)._

## Scope

Verifies that every imported track is **playable through the existing audio
player** (`AudioPlayerService`, just_audio 0.9.46) and loads a **real, non-zero
duration**. The player consumes `audioUrl` directly via `Uri.parse`; just_audio
natively resolves the `asset:///` scheme (`just_audio.dart`, the `uri.scheme ==
'asset'` branch), so the bundled assets play through the unchanged player code
path — no player changes were required.

## What was executed in this environment

| Check | Method | Result |
|---|---|---|
| Audio decodes & has real duration | `music-metadata` full-stream decode of all 15 MP3s during scan | ✅ 15/15 decoded, durations 02:18–09:40 (none 00:00) |
| Asset files bundled & resolvable | `flutter test test/imported_catalog_test.dart` | ✅ 6/6 tests pass |
| `asset:///` URLs well-formed | catalog test asserts prefix + on-disk file exists | ✅ 15/15 |
| Records valid for import | `MetadataValidator.validateTrack` over every song | ✅ 15/15 ok |
| Static analysis | `flutter analyze lib test integration_test` | ✅ No issues found |

`flutter test` output: **`+6: All tests passed!`**

## Live audio-engine checks (play / pause / seek / next / previous)

just_audio drives playback through a **platform** audio engine. This environment
has **no Android emulator/device** and the project targets **Android + Web only**
(no Windows desktop runner), so the live-engine assertions are delivered as a
ready-to-run integration test rather than executed here:

```
flutter test integration_test/playback_test.dart   # on a connected Android device/emulator
```

`integration_test/playback_test.dart` asserts, against the bundled assets:

- **load + duration** — each track loads and reports a duration `> 0` (not 00:00)
- **play()** — `player.playing == true` and position advances
- **pause()** — `player.playing == false`
- **seek()** — position jumps to the requested offset
- **next / previous** — `currentIndex` moves 0→1→2 then back to 1 across a playlist

The same code path (`AudioSource.asset` / `asset:///` URI → just_audio) is what
the app's `AudioPlayerService._buildAudioSource` uses at runtime, so a pass on
device confirms in-app playback end-to-end.

## Per-track duration (decoded, authoritative)

| # | Duration | Asset (assets/audio/) | Title |
|---|----------|------------------------|-------|
| 1 | 06:15 | aankhi-micholi-256k.mp3 | AANKHI MICHOLI |
| 2 | 03:17 | aaja-aaja-256k.mp3 | Aaja Aaja |
| 3 | 02:50 | ang-songi-kinnauri-cover-song-reprise-2026-256k.mp3 | Ang Songi (Kinnauri Cover 2026) |
| 4 | 09:40 | baadri-…-256k.mp3 | Baadri (Jaunsari DJ, Sardar Singh Sharma) |
| 5 | 05:01 | bamniye-256k.mp3 | Bamniye |
| 6 | 07:20 | dhire-dhire-o-chanda-…-256k.mp3 | Dhire Dhire O Chanda (Kumauni, Lalit Mohan Joshi) |
| 7 | 05:14 | fukla-chane-bindiya-256k.mp3 | Fukla Chane Bindiya |
| 8 | 04:15 | jai-bolya-devta-256k.mp3 | Jai Bolya Devta |
| 9 | 03:00 | jhauliye-256k.mp3 | Jhauliye |
| 10 | 05:02 | jhuriye-256k.mp3 | Jhuriye |
| 11 | 05:12 | jumi-jimi-o-rohru-ri-jatre-256k.mp3 | Jumi Jimi O Rohru Ri Jatre |
| 12 | 02:18 | kolang-…-256k.mp3 | Kolang (Himachali, Palak/Hardik 2026) |
| 13 | 05:36 | main-pahadan-…-256k.mp3 | Main Pahadan (Kumaoni, Diksha/Pooja Dhaundiyal) |
| 14 | 04:52 | meri-salma-256k.mp3 | Meri Salma |
| 15 | 03:07 | driver-horon-bajade-ho-…-256k.mp3 | driver horon bajade ho (Pahadi Nati, Seema Raniye) |

**Total:** 15 tracks · 72:57 · 0 zero-duration tracks.

## Conclusion

Every imported track is playable-by-construction (valid MP3, real duration,
bundled asset, valid `asset:///` URL through the unchanged player) and is proven
so by the headless suite. The live play/pause/seek/next-previous behaviour is
covered by `integration_test/playback_test.dart`, runnable on any Android
device/emulator.
