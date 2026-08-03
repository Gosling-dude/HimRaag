# Image Audit (Phase 10)

**Date:** 2026-08-03 · **Method:** live HTTP probe of every artwork URL in Firestore.

## Coverage — measured, not sampled

| Asset class | Reachable | Rate |
|---|---|---|
| Album artwork | 173/173 | **100.0%** |
| Song artwork | 954/956 | 99.8% |
| Artist images | 216/217 | 99.5% |
| **Total** | **1,343/1,346** | **99.8%** |

### The 3 gaps

| Item | Cause | User-visible result |
|---|---|---|
| Kui Ta Baat Holi(0) | Request exceeded 20 s | Transient — object exists; loads on retry |
| Mahima Ke Varnan | No `artworkUrl` in Firestore | Branded fallback cover |
| Pankaj Raaj (artist) | No `imageUrl` in Firestore | Branded fallback avatar |

## "No placeholder should remain forever" — satisfied

Verified in `lib/core/widgets/app_artwork.dart`:

1. **Shimmer while loading** (`placeholder:`) — never a blank box.
2. **Thumbnail-first**: attempt 0 requests the small thumbnail; any failure falls
   back to the full-size URL (`_attempt == 0 && thumb != null`).
3. **Retry with backoff**: a `_backoff` schedule with a bounded attempt count, and
   a `#retry$_attempt` URL fragment so a retry is never served from a negative
   cache. The fragment is never transmitted.
4. **Terminal branded fallback** (`errorWidget:`): a deterministic gradient derived
   from the label plus its initials — on-brand, stable per item, and never a grey
   broken-image icon.

So a missing image degrades to a designed cover, and a *transient* failure
self-heals. **No infinite shimmer path exists.**

## Caching — verified by construction

`ArtworkCacheManager` (see PERFORMANCE_REPORT.md): 30-day stale period, 3,000
objects, 4-way concurrency cap, 20 s timeout, and non-2xx responses throw rather
than cache — so a 429 never poisons the cache.

## Recommended repairs

```bash
node scripts/repair_artist_images.js   # Pankaj Raaj
node scripts/regenerate_art.js         # Mahima Ke Varnan
```

Both are cosmetic; neither blocks release.

## ❌ NOT VERIFIED without a device

Visual confirmation that the fallback renders correctly, that cached images
survive an app restart, and that scrolling the Home screen produces no 429 storm.
Check the last one with:

```bash
adb logcat -s flutter | grep -i "429\|Image fetch failed"
```

Seeing repeated `Image fetch failed` lines on Home means the origin is rate-limiting —
the fix is the `Cache-Control` change in R2_AUDIT.md, not a client change.
