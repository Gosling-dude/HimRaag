# HimRaag — Known Limitations

_Last updated: 2026-06-15_

---

## Content Limitations (Dev/Demo Build)

### L-01 — Placeholder audio (SoundHelix)
**Severity:** Critical for production, acceptable for dev  
**Description:** All 10 seeded songs play SoundHelix royalty-free demo samples, not real Pahadi music.  
**Impact:** App is functionally complete but has no culturally authentic content.  
**Fix:** Upload licensed Pahadi MP3s to a self-hosted CDN or Firebase Storage (Blaze plan), update `audioUrl` fields in Firestore.

### L-02 — Placeholder artwork (picsum.photos)
**Severity:** High for production, acceptable for dev  
**Description:** Album and artist images are random placeholder photos from picsum.photos seeded by ID. Images are stable (same seed = same image) but have no artistic relevance.  
**Impact:** The app looks populated but artwork conveys no cultural identity.  
**Fix:** Commission or license real album/artist artwork, host on CDN, update `artworkUrl` fields.

### L-03 — 10 songs total
**Severity:** High for production  
**Description:** Only 10 songs are seeded across 5 artists and 3 albums. Playlists collection is empty.  
**Impact:** Very limited browsing experience. Search returns few results.  
**Fix:** Curate and upload a real content library before production launch.

---

## Authentication Limitations

### L-04 — Google Sign-In requires device-level Google account
**Severity:** Medium  
**Description:** The Google Sign-In flow (`google_sign_in` + Firebase Auth) requires the user's device to have a Google account signed in at the OS level.  
**Impact:** Users without a Google account can only use guest (anonymous) mode.  
**Mitigation:** Anonymous mode provides full playback access. Guest sessions persist across app restarts.

### L-05 — Anonymous session is not recoverable
**Severity:** Low-Medium  
**Description:** Guest sessions are tied to the Firebase anonymous UID. If the app is uninstalled or Firebase data is cleared, the guest session cannot be recovered. Favorites and download history stored in Hive survive reinstall if device storage is intact.  
**Fix:** Prompt users to link a Google account to preserve their session.

---

## Content Delivery Limitations

### L-06 — SoundHelix is a third-party service with no SLA
**Severity:** Medium (for demo build)  
**Description:** Audio URLs point to `www.soundhelix.com`, a publicly accessible demo MP3 server with no uptime guarantee. If SoundHelix goes down, all audio stops working.  
**Impact:** App goes silent without warning.  
**Fix:** Move to self-hosted CDN or Firebase Storage before production.

### L-07 — picsum.photos has no SLA
**Severity:** Low-Medium  
**Description:** Artwork URLs point to `picsum.photos`. Outage would break artwork display. `cached_network_image` shows placeholder icons on failure, so UI degrades gracefully.  
**Mitigation:** Error widgets already handle missing images. Low risk for demo.

### L-08 — No CDN caching layer
**Severity:** Low  
**Description:** Audio requests go directly to SoundHelix origin with no CDN between the app and the host. High concurrent users could cause rate limiting or slow loads.  
**Fix:** Production content should use a CDN (Cloudflare, BunnyCDN, or Firebase Storage with CDN).

---

## Offline Limitations

### L-09 — Firestore requires internet for first load
**Severity:** Medium  
**Description:** All song metadata (titles, artists, albums) comes from Firestore. The app shows loading states and errors if Firestore is unreachable. There is no local Firestore snapshot cache that survives app restarts beyond Firestore SDK's built-in disk persistence (which requires at least one successful sync).  
**Impact:** First-time users with no internet see a blank home screen.  
**Fix:** Bundle a minimal static content snapshot in the app assets as a fallback.

### L-10 — Downloaded songs lose their audioUrl after download
**Severity:** Low  
**Description:** `getAllDownloadedSongs()` reconstructs `Song` objects from Hive with `audioUrl: ''`. If a downloaded song's local file is deleted externally, the offline pin icon may still show.  
**Impact:** Minor — re-download is required if the local file is gone.

---

## UX Limitations

### L-11 — Download progress not visible in album detail
**Severity:** Low  
**Description:** "Download All" in the album screen starts downloads in the background. The Snackbar confirms the count, but there's no per-song progress bar or completion notification.  
**Fix:** Wire up `activeDownloadsProvider` to show progress indicators in the song list.

### L-12 — Favorites tab shows count only, not song list
**Severity:** Medium  
**Description:** The Favorites tab in Library displays "N favorites saved" instead of the actual song list. Favorite song IDs are stored but there's no UI to re-fetch and display those songs from Firestore.  
**Fix:** Add a provider that fetches `getSongsByIds(favorites)` and renders them as a SongListTile list.

### L-13 — No album-less songs in browse view
**Severity:** Low  
**Description:** Songs without an `albumId` (Raniban, Basant Aayo Re, Kumaoni Holi Geet, Jaunsari Naati) only appear in trending/featured/search, not in any album browse view.  
**Impact:** Some songs are harder to discover by browsing.

### L-14 — No playlist creation UI
**Severity:** Medium  
**Description:** The `playlists` Firestore collection exists and `PlaylistDetailScreen` exists, but there is no UI to create or manage playlists.

---

## Infrastructure Limitations

### L-15 — Firestore free tier daily limits
**Severity:** Low at launch scale  
**Description:** The Spark plan allows 50,000 reads / 20,000 writes / 20,000 deletes per day. `incrementPlayCount()` writes on every song play. At scale this will exceed free limits.  
**Threshold:** ~20,000 song plays/day hits the write limit. With 10 songs and early-stage traffic, this won't be an issue.  
**Fix:** Batch play count increments or switch to a counter service at scale.

### L-16 — Firebase Storage not integrated
**Severity:** Info  
**Description:** Firebase Storage is configured but not used. The `firebase_storage` SDK is not a dependency. Storage path constants are commented out in `firebase_constants.dart`. Audio and artwork are served from external URLs.  
**This is by design** for the free-tier architecture. See `DEPLOYMENT.md` for the migration path.
