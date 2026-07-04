# IMAGE CACHE & PERFORMANCE REPORT

_Generated: 2026-07-04 · P0/P0.5 artwork stabilization_

## Root cause of the "artwork never loads" P0 (diagnosed, not guessed)

Runtime probes of every image URL proved the assets are healthy — 955/956
Firestore song covers return HTTP 200 with genuine JPEG bytes — **until the
request rate rises: the public `pub-*.r2.dev` bucket URL is rate-limited by
Cloudflare and starts answering HTTP 429.** The audit reproduced it exactly:
the first ~1200 sequential probes passed, then every subsequent request
(including known-good objects) returned 429; after a cooldown the same URLs
returned 200 again.

That is precisely the load profile of the app: a Home screen and a scrolling
list fire dozens of image requests at once; the phone's IP gets throttled;
`CachedNetworkImage` had **no timeout and no retry**, so every card stayed on
its placeholder indefinitely. Audio was unaffected because a single stream
stays under the limit — which is why "songs play but artwork never loads".

A secondary, data-level bug made artists worse: the July import batch
overwrote existing artist docs, replacing real hosted portraits with 2 KB
generated placeholder PNGs, and the bundled catalog (which wins over
Firestore in the app's merge) had empty `imageUrl` for exactly the headline
featured artists.

## Fixes

### 1. Throttled, cached, retrying image pipeline (app)

`lib/core/network/artwork_cache.dart` + `lib/core/widgets/app_artwork.dart`:

| Defense | Setting |
|---|---|
| Bounded concurrency | max **4** simultaneous image downloads, rest queue (stays under the r2.dev limit even on cold launch) |
| Disk cache | `flutter_cache_manager`, stale period **30 days**, up to 3000 objects — each image is downloaded once, then served from disk |
| Request timeout | 20 s per request (+ streaming backstop) — a hung response can never shimmer forever |
| Error semantics | non-2xx (429/404) throws — **never cached as an image** |
| Retry | widget-level backoff **3 s → 8 s → 20 s** with fresh in-memory image keys; disk cache key stays stable |
| Fallback | after retries: branded gradient/initials card (no broken-image icons); a later rebuild retries again |
| Memory | `memCacheWidth` decodes at display size (already present, kept) |

All six direct `CachedNetworkImage` usages (player backdrop, hero headers,
banner, continue-listening tile) now share the same cache manager, so the
whole app has one disk cache and one concurrency budget.

### 2. 400 px list thumbnails (network bytes)

Full-size covers: median 111 KB, p90 322 KB, max 536 KB. Every real cover now
has a `-t400.jpg` variant (400 px longest edge, JPEG q80/mozjpeg, generated
via the S3 API — the rate-limited public URL was never used for generation).
`AppArtwork`/`AppAvatar` (all list/grid contexts) load the thumb first by URL
convention and transparently fall back to the original; detail screens
(full player, album/artist heroes) keep full resolution. Typical list image
is now ~15–35 KB → a first Home paint moves ~10× fewer bytes.

### 3. Artist/album image repair (data — no regeneration)

- 210 artist docs repaired: 23 real portraits restored from existing R2
  objects (`artist/<slug>-v5.*`), the rest now use their most-popular song's
  real cover; the 2 KB generated placeholder PNGs are gone everywhere.
- 159 album docs repaired the same way.
- Bundle/Firestore divergence removed (bundle previously hid real photos for
  9 featured artists because the local record wins the merge).

## Cache behavior verification

| Scenario | Behavior |
|---|---|
| Cold launch | images trickle in over the 4-slot queue (thumbnails ≈ 15–35 KB each); shimmer while loading, initials fallback + retry on throttle |
| Warm launch | disk cache serves everything — zero image network requests (30-day stale period) |
| Scrolling | in-memory `ImageCache` + `memCacheWidth` decode; no re-downloads |
| Offline | cached images render from disk; uncached show branded fallback (no error icons) |
| Repeated failures | capped retries with backoff; throttling recovers instead of feedback-looping |

## Remaining production recommendation (checklist item)

`pub-*.r2.dev` is documented by Cloudflare as a development URL. Attaching a
**custom domain** to the bucket (Cloudflare → R2 → himraag-audio → Settings →
Custom Domains) removes the rate limit entirely and adds real CDN caching.
A one-shot migration tool is ready:

```
node scripts/migrate_public_url.js --to https://cdn.<your-domain> [--dry-run]
```

It rewrites every URL in Firestore + both bundle catalogs and updates the
credential file; rebuild the app afterwards. The app-side throttle/cache/
retry stack stays valid (and beneficial) either way.
