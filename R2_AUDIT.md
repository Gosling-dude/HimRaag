# Cloudflare R2 Audit (Phase 5)

**Date:** 2026-08-03 · **Method:** `scripts/verify_all_urls.js` (read-only) over live
Firestore, plus a read-only `HEAD` header probe. No object was written or deleted.

## Reachability — every consumer-facing URL

```
Checked 2302 URLs; reachable 2299; failures 3
  song-audio:  956/956   (100.0%)
  song-art:    954/956   ( 99.8%)
  artist-img:  216/217   ( 99.5%)
  album-art:   173/173   (100.0%)
```

**Every one of the 956 audio files is reachable.** No track in the catalogue is
unplayable due to a missing or broken object.

### The 3 failures

| Type | Item | Status | Impact |
|---|---|---|---|
| song-art | Kui Ta Baat Holi(0) | timeout | Transient — object exists; the request exceeded 20 s |
| song-art | Mahima Ke Varnan | no-url | No `artworkUrl` set in Firestore |
| artist-img | Pankaj Raaj | no-url | No `imageUrl` set in Firestore |

**Severity: LOW (cosmetic).** `AppArtwork` renders a branded gradient-and-initials
fallback and retries with backoff, so these show an on-brand cover rather than a
broken image. No placeholder shimmers forever.

To repair the two missing URLs:
```bash
node scripts/repair_artist_images.js     # Pankaj Raaj
node scripts/regenerate_art.js           # Mahima Ke Varnan
```

## Object headers

Sampled via `HEAD` across audio and artwork objects:

| Property | Audio | Artwork | Verdict |
|---|---|---|---|
| `Content-Type` | `audio/mpeg` | `image/jpeg` | ✅ correct |
| `Accept-Ranges` | `bytes` | `bytes` | ✅ **seeking works** — range requests supported |
| `Cache-Control` | *(none)* | *(none)* | ❌ **see below** |
| Sizes | 2.7–10.3 MB | 62–361 KB | ✅ reasonable |

## ❗ Finding: no `Cache-Control` on any R2 object

**This is the highest-value remaining fix in the project.**

Not one sampled object returns a `Cache-Control` header. Consequences:

1. Cloudflare's edge cannot cache confidently, so a much larger share of requests
   reach the origin bucket.
2. `pub-*.r2.dev` is rate-limited. A Home screen full of covers produces exactly
   the burst that starts returning **HTTP 429** — the problem the app already
   fights client-side in `ArtworkCacheManager` (4-way concurrency cap, 30-day
   disk cache, retry/backoff).

The client-side defences work, but they treat the symptom. Audio and artwork
objects here are immutable — a new track gets a new key — so they can be cached
for a year safely.

**Recommended remedy** (not applied; it rewrites metadata on ~2,300 objects and
is your call):

```js
// For every object, re-PUT with:
CacheControl: 'public, max-age=31536000, immutable'
```

`scripts/r2_upload.js` already holds a working S3 client and credential loader,
so this is a `copyObject`-with-new-metadata pass, not new infrastructure.

Expect: markedly fewer origin hits, fewer 429s under launch-day load, and faster
warm artwork loads. **Do this before any marketing push.**

> A stronger long-term option is to serve R2 through a custom domain behind the
> Cloudflare CDN instead of the rate-limited `pub-*.r2.dev` hostname.

## Security posture

| Check | Result |
|---|---|
| Bucket root directory listing | ✅ **404** — not listable |
| Credentials in source | ✅ None. `scripts/lib/credentials.js` reads from gitignored `.env/` and never logs values |
| Credentials in git history | ✅ None ever committed (`git log --all --diff-filter=A` scan) |
| Transport | ✅ HTTPS only; app sets `usesCleartextTraffic="false"` |

## Duplicates

In a 400-song sample: **0 duplicate audio URLs**, 2 repeated artwork URLs — these
are tracks from the same album correctly sharing one cover, not waste.
