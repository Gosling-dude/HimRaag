# Offline Audit (Phase 13)

**Date:** 2026-08-03

> **Verification status:** offline behaviour requires a device with a toggleable
> network. **NOT VERIFIED here.** Code-level guarantees below are real; the
> end-to-end checklist is for you.

## What works offline — by construction

### 1. Downloads are genuinely local

`download_service.dart:154-156`:
```dart
final appDir = await getApplicationDocumentsDirectory();
final downloadsDir = Directory('${appDir.path}/downloads');
```
App-private storage. No permission needed, not visible to other apps, survives
reboot, removed on uninstall. Download state is tracked in Hive
(`hive_download_task.dart`), which is on-disk and survives process death.

### 2. The catalogue itself is bundled

`assets/catalog/imported_catalog.json` ships **697 songs, 102 albums, 148 artists**
inside the APK. `LocalCatalogDatasource` parses it with an internal cache.

This means a **cold launch with no network still renders a browsable catalogue** —
Home, search, album and artist pages all resolve from the bundle. Verified by
`test/local_catalog_test.dart`, which asserts the bundle loads, is searchable, and
resolves album+artist for detail pages.

*This is the reason to keep the 1.1 MB JSON despite it being a strict subset of
Firestore (see FIRESTORE_AUDIT.md) — it is the entire offline-first-launch story.*

### 3. Artwork is disk-cached for 30 days

`ArtworkCacheManager` — previously viewed covers render offline without a network hit.

### 4. Firestore has its own offline cache

`cloud_firestore` enables local persistence by default on mobile, so previously
fetched documents are served from disk when offline.

### 5. Personalization degrades, not fails

`ensureUserDoc` is try/catch-wrapped and returns device-local profile data when
Firestore is unreachable — offline sign-in state does not block the app.

## Honest limitation

**Streaming a not-yet-downloaded track offline will fail** — it must fetch from R2.
The app should show an error rather than hang; `AppArtwork` has an explicit error
path, but I could not confirm the *player's* offline error message without a device.
**Please check item 6 below specifically** — a silent failure or infinite spinner
there would be the worst offline outcome.

## ❌ NOT VERIFIED — offline checklist

1. Download 3 songs; wait for completion.
2. Enable aeroplane mode.
3. Confirm:
   - [ ] App launches and Home renders (bundled catalogue)
   - [ ] Library → Downloads lists the 3 songs
   - [ ] A downloaded song **plays** from local storage
   - [ ] Seek works on a downloaded song
   - [ ] Queue and next/previous work across downloaded tracks
   - [ ] Playback notification appears and its controls work offline
   - [ ] **A non-downloaded song shows a clear error — not an infinite spinner** ← most important
   - [ ] Cached artwork still renders; uncached shows the branded fallback
   - [ ] Search returns bundled results
4. Re-enable network; confirm the app recovers without a restart.

```bash
# Toggle connectivity from the host instead of touching the phone
adb shell svc wifi disable && adb shell svc data disable
adb shell svc wifi enable  && adb shell svc data enable
```
