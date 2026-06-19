# HimRaag — Pre-Import Backup Report (Phase 0)

_Generated: 2026-06-19 · Branch: `feat/import-new-pahadi-songs`_

This is the safety checkpoint captured **before** importing the new songs from
`D:\Personal Projects\HimRaag\music\pahadi songs`. It records the exact state of
the catalog, backing services, build artifacts and source tree so the import can
be verified as strictly additive.

## 1. Git state

| Field | Value |
|---|---|
| Import branch | `feat/import-new-pahadi-songs` |
| Forked from commit | `0e8dd8e` (feat: replace generated artwork with real covers and photographs) |
| Working tree at fork | clean |

A full backup of the pre-import catalog, intermediate pipeline artifacts and
generated reports was taken to `.import_backup/` (gitignored):
`imported_catalog.ORIGINAL.json`, `seed_data_ORIGINAL/`, and `*.md.orig` report copies.

## 2. Catalog counts (BEFORE import)

### Live Firestore (`himraag-prod`)

| Collection | Count |
|---|---|
| songs | 29 |
| albums | 14 |
| artists | 16 |
| categories | 6 |

Song approval breakdown: **29 approved**, 19 published, 0 reviewRequired.

### Bundled runtime catalog (`assets/catalog/imported_catalog.json`)

| Entity | Count |
|---|---|
| songs | 19 |
| albums | 11 |
| artists | 11 |

> The bundled catalog is the offline-first runtime source for imported audio; the
> app merges it with Firestore by id. (Firestore additionally carries demo/seed
> records that are gated out of consumer builds by `visibleToConsumers()`.)

## 3. Backing services

| Service | Status | Evidence |
|---|---|---|
| Cloudflare R2 (`himraag-audio`) | ✅ healthy | sample audio `aankhi-micholi-256k.mp3` → HTTP 206; artwork `aankhi-micholi-256k.png` → HTTP 200 |
| Public base URL | `https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev` | reachable |
| Firestore (`himraag-prod`) | ✅ healthy | count queries succeeded via admin SDK |
| Credentials | ✅ present | `.env/` (Cloudflare `.txt` + Firebase admin SDK JSON), gitignored |

## 4. Build artifacts (BEFORE import)

| Artifact | Path | Size |
|---|---|---|
| APK (release) | `build/app/outputs/flutter-apk/app-release.apk` | 55 MB (57,352,929 bytes) |
| AAB (release) | `build/app/outputs/bundle/release/app-release.aab` | 28 MB (29,269,276 bytes) |

## 5. Quality gates (BEFORE import)

| Gate | Result |
|---|---|
| `flutter analyze` | ✅ No issues found (70.6s) |
| `flutter test` | ✅ All 12 tests passed |
| Flutter / Dart | 3.27.1 stable · Dart 3.6.0 |

## 6. New songs to import

| Field | Value |
|---|---|
| Source folder | `D:\Personal Projects\HimRaag\music\pahadi songs` |
| Audio files found | 68 (`.mp3`) |
| Strategy | Additive: process the 68 new files in isolation, then **merge** into the existing catalog. Existing 19 songs / R2 objects / Firestore docs are never overwritten or re-uploaded (checksum dedup + `{merge:true}` upserts). |

---

_Baseline is green. Proceeding to Phase 1 (scan)._
