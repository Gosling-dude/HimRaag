# DATA CLEANUP REPORT

_Generated: 2026-07-03 · pre-production stabilization_

## Firestore catalog hygiene (live scan)

A full scan of the `songs` collection (328 docs at session start) found:

| Check | Count | Action |
|---|---|---|
| `license = DEMO_ONLY` / `approvalStatus = demo` | **0** | none needed — demo seed was purged in a previous session (`scripts/purge_demo.js`) |
| Instrumental / test / placeholder titles | **0** | none needed |
| `picsum.photos` or placeholder artwork URLs | **0** | none needed |
| Duplicate title+artist groups | **0** | none needed |

The catalog contains only real imported songs; the curated demo tracks that
remain are intentionally retained and `LICENSED`.

## Source-folder dedup (fresh import batch)

`music/pahadi songs/` re-scan (June batch 314 → now **1009 MP3s**):

| Stage | Count | Action |
|---|---|---|
| Files scanned (recursive) | 1009 | — |
| Exact byte duplicates (size + SHA-1 of first 512 KB) | 0 | drop, keep first |
| Quality/format variants (same normalized title, duration ±6 s) | 10 | keep highest bitrate, drop rest |
| Mashups / non-stop / medleys / jukeboxes | 63 | excluded — not real songs |
| Already imported (exact `sourceFile` match in Firestore + title/duration match in bundle) | 301 | skipped — never re-imported |
| **New unique songs to import** | **635** | imported |

The exact-source-file guard was added this session: the previous title-only
cross-dedup would have re-imported ~157 songs under differently-derived titles.

## Bad-data policy going forward

- Ambiguous-region songs stay in the Firestore **admin review queue**
  (`region = "Needs Review"`, `reviewRequired = true`, unpublished) — they are
  never dumped into a generic category or auto-published.
- The dedup planner (`scripts/plan_import.js`) is idempotent and re-runnable
  for any future folder drops.

Full per-file listings: `DUPLICATE_CLEANUP_REPORT.md`, `NEW_IMPORT_REPORT.md`.
