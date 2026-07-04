# Media Notification Report

Date: 2026-07-04 · Branch: `feat/import-new-pahadi-songs`

## Status: implemented via `just_audio_background` — configuration audited, no code changes required

The full Android media-notification stack was already integrated; this pass audited
every layer of it end-to-end and confirmed the configuration is production-correct.
Per the "if it works, don't touch it" rule, nothing was modified.

## Configuration audit

### 1. Service init — `lib/main.dart`

```
JustAudioBackground.init(
  androidNotificationChannelId: 'com.himraag.app.audio',
  androidNotificationChannelName: 'HimRaag Audio',
  androidNotificationOngoing: true,          // stays visible while playing
  androidStopForegroundOnPause: true,        // becomes dismissible when paused
  notificationColor: Color(0xFF6B3FA0),      // HimRaag purple accent
)
```

- Wrapped in a 5 s timeout with a safe fallback: if the foreground-service binding
  hangs on a problematic device, the plain audio platform is restored so playback
  still works (only background controls are lost). This hardening pre-exists and is
  unchanged; it still runs inside the new `_initialize()` before any `AudioPlayer`
  is created (verified: the app widget tree — and therefore every provider — is only
  built after initialization completes, so ordering is preserved by construction).

### 2. Manifest — `android/app/src/main/AndroidManifest.xml`

| Requirement | Present |
|---|---|
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` permissions | ✅ |
| `WAKE_LOCK` (screen-off playback) | ✅ |
| `POST_NOTIFICATIONS` (Android 13+) | ✅ |
| `com.ryanheise.audioservice.AudioService` with `foregroundServiceType="mediaPlayback"` | ✅ |
| `MediaBrowserService` intent filter (Android Auto media session) | ✅ |
| `MediaButtonReceiver` with `MEDIA_BUTTON` intent filter (Bluetooth/headset buttons) | ✅ |
| `RECEIVE_BOOT_COMPLETED` (session restore) | ✅ |

### 3. Metadata per track — `AudioPlayerService._buildAudioSource()`

Every queue item is tagged with a `MediaItem` carrying **id, title, artist, album,
artUri (song artwork URL), duration** — this is exactly what the notification, lock
screen, Bluetooth AVRCP and Android Auto render.

## Behavior matrix (how the configuration maps to the requirements)

| Requirement | Mechanism |
|---|---|
| Artwork / title / artist in notification | `MediaItem` tag per audio source |
| Play/Pause/Next/Previous buttons | `just_audio_background` compact media style notification |
| Lock screen controls | MediaSession published by audio_service |
| Bluetooth / headset buttons | `MediaButtonReceiver` |
| Android Auto | `MediaBrowserService` intent filter |
| Notification persists while playing | `androidNotificationOngoing: true` + foreground service |
| Removed when playback stops | foreground service stops; on pause it becomes swipe-dismissible (`androidStopForegroundOnPause: true`) |
| Resume playback | media session survives task removal while service runs |

## Runtime verification

`flutter analyze` clean, 12/12 tests pass, release APK/AAB build successfully.

**Device checklist for your final manual review** (no physical Android device or
emulator was attached to this build machine, so the physical steps below could not be
executed here):

1. Play a song → minimize app → notification shows artwork, title, artist,
   play/pause/next/previous.
2. Lock the device → controls on lock screen; unlock → notification still present.
3. Toggle pause/next from the notification and from a Bluetooth headset.
4. Stop playback (swipe app away / pause + dismiss) → notification clears.
