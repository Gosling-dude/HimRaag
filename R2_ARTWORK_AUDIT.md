# R2 ARTWORK AUDIT

_Generated: 2026-07-03T23:48:36.335Z_

Probed every Firestore song artworkUrl + artist imageUrl on the public R2 host.

| Check | Result |
|---|---|
| Objects reachable (2xx) | 1125 |
| Correct image MIME type | 1125 |
| Real image magic bytes | 1125 |
| ETag present (client revalidation) | 1125 |
| Cache-Control present | 0 |
| Broken/missing objects | 0 (listed in song/artist audits) |
| Range requests honored | yes (probes used byte ranges → 206) |

Host: public R2 dev URL. Note: `*.r2.dev` sends no long-lived Cache-Control by default; client-side disk caching (flutter_cache_manager) is therefore the primary cache layer.
