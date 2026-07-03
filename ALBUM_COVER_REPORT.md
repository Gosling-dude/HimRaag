# ALBUM COVER REPORT

_Generated: 2026-06-24 — branch `feat/import-new-pahadi-songs`_

## Policy (enforced)
- Real album covers when available (official cover art via the public JioSaavn API, strict matcher).
- Otherwise a **genuine relevant photograph** (license-clean regional imagery via Wikimedia Commons).
- **No AI-generated covers, no text/poster overlays.**

## Current catalog state (verified)
Firestore: **14 album docs**. Production scan found every album with a real `imageUrl` —
**0** `picsum`/placeholder-domain URLs, **0** AI/poster-text covers. Albums reuse their lead
single's real cover where a standalone album cover does not exist, which keeps imagery genuine
(natural photography or official single art) rather than fabricated.

| Album imagery | Treatment |
|---|---|
| Official cover found (JioSaavn strict match) | real cover (`-150x150` → `-500x500`) |
| No official cover | real regional photograph (Wikimedia, PD/CC) — landscape ≥800px, filtered for maps/diagrams/AI |

## New import (237 songs) — staged
New songs map to a small number of new albums (largely the **Pahadi Folk Collection** umbrella).
The staged real-art pipeline assigns covers under the same policy (real cover → real photo
fallback), versioned on R2 to cache-bust clients. No AI covers, no text overlays.

## Verification
14/14 production album docs have a real image URL; 0 placeholder-domain, 0 AI. New-album covers
are produced by the staged pipeline (NEW_IMPORT_REPORT.md), not in this session.
