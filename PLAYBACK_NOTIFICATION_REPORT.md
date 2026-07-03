# PLAYBACK & NOTIFICATION REPORT

_Generated: 2026-06-24 — branch `feat/import-new-pahadi-songs`_

HimRaag already implements real-music-app background playback through `just_audio` +
`just_audio_background`. This phase audited the full chain and confirmed each requirement is
satisfied; no architectural rework was required.

## Architecture
| Concern | Implementation | File |
|---|---|---|
| Background service init | `JustAudioBackground.init(channelId=com.himraag.app.audio, ongoing=true, stopForegroundOnPause=true, color=#6B3FA0)` with a 5s timeout + graceful fallback to plain platform | `lib/main.dart:50-66` |
| Media metadata (notification/lock screen) | Each queue item is an `AudioSource.uri` tagged with a `MediaItem` carrying `title`, `artist`, `album`, `artUri`, `duration` | `lib/data/services/audio_player_service.dart:156-179` |
| Queue + auto-advance | `ConcatenatingAudioSource` — advances to the next item automatically on completion | `audio_player_service.dart:62-72` |
| Next / Previous / Seek | `seekToNext` / `seekToPrevious` (prev restarts current if >3s in) / `seek` — all proxied to the OS media session | `audio_player_service.dart:91-100` |
| Repeat / Shuffle | `LoopMode.off/one/all`, `setShuffleModeEnabled` | `audio_player_service.dart:102-116` |
| Recently-played hook | `PlayerController.playSong` records into `recentlyPlayedProvider` | `lib/features/player/providers/player_providers.dart:50-53` |

## Android integration (verified in `AndroidManifest.xml`)
- `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (Android 14 requirement)
- `WAKE_LOCK` (playback survives screen-off)
- `POST_NOTIFICATIONS` (Android 13+ runtime prompt)
- `RECEIVE_BOOT_COMPLETED` (media-session restore)
- `<service com.ryanheise.audioservice.AudioService foregroundServiceType="mediaPlayback">` with `MediaBrowserService` intent filter
- `<receiver com.ryanheise.audioservice.MediaButtonReceiver>` for hardware/Bluetooth media keys

## Requirement checklist
| Requirement | Status | Mechanism |
|---|---|---|
| Song shown in notification while playing | ✅ | `MediaItem` tag + ongoing notification |
| Media controls in notification | ✅ | `just_audio_background` renders play/pause/next/prev/seek |
| Lock-screen controls | ✅ | Android media session via foreground service |
| Auto-play next when current ends | ✅ | `ConcatenatingAudioSource` |
| Background playback when minimized | ✅ | foreground service + wake lock |
| Play/pause/next/prev/seek in background | ✅ | proxied to media session |
| Continues after screen lock | ✅ | wake lock + ongoing foreground service |
| Correct audio session / foreground service / notification | ✅ | manifest + `JustAudioBackground.init` |

## Resilience note
If the foreground-service binding hangs on a problem device, `main.dart` restores the plain
`just_audio` platform after a 5s timeout: the app keeps playing audio (it only loses
lock-screen controls) instead of freezing on the launch screen. This is an intentional
safety net, logged as `[APP] AUDIO_BG_INIT_FAILED`.

## Runtime verification
Code-path and configuration verification complete. Full on-device confirmation of the live
notification, lock-screen controls, and Bluetooth media keys requires a physical Android
device/emulator, which is **not attached in this build environment** — to be confirmed on the
release APK during device QA. The release APK build itself is covered in Phase 8.
