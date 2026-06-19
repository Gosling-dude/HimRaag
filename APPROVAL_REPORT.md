# HimRaag — Approval Report (Phase 6)

_Generated: 2026-06-19 · Project: `himraag-prod`_

Every newly-imported song is **approved, published and live immediately**, with
runtime evidence from the exact consumer queries. Imported via
`scripts/import.js` (approved + published), artwork resolved
(`scripts/fetch_real_art.js`), sentinels cleaned (`scripts/polish_catalog.js`),
counts reconciled (`scripts/reconcile_counts.js`) and verified
(`scripts/approve_imported.js`).

## 1. Live totals (Firestore, consumer-visible)

| Collection | Count |
|---|---|
| songs | 97 |
| albums | 14 |
| artists | 16 |

> 97 = 29 pre-existing (19 original imports + 10 seed) + 68 newly imported.
> All 68 new songs are `approvalStatus=approved`, `isApproved=true`,
> `isPublished=true`, `reviewRequired=false`.

## 2. Consumer query results (after approval)

| Query | Result |
|---|---|
| Home — Featured songs | 10 |
| Home — Trending | 20 |
| Home — New Releases | 20 |
| Featured Albums | 14 |
| Featured Artists (verified) | 16 |

### Region pages

| Region | Songs |
|---|---|
| Himachali | 74 |
| Garhwali | 10 |
| Kumaoni | 9 |
| Jaunsari | 3 |
| Kinnauri | 1 |

## 3. Per-song trace (Firestore → query → playback)

Each sampled song was traced from its Firestore document, through the consumer
approval query and search index, to its R2 playback URL:

| Song | Approved | Published | reviewRequired | In consumer query | In search | Playback URL |
|---|---|---|---|---|---|---|
| AANKHI MICHOLI | ✅ | ✅ | false | ✅ | ✅ | R2 ✅ |
| Main Pahadan | ✅ | ✅ | false | ✅ | ✅ | R2 ✅ |
| Baadri | ✅ | ✅ | false | ✅ | ✅ | R2 ✅ |
| Meri Salma | ✅ | ✅ | false | ✅ | ✅ | R2 ✅ |
| Jai Bolya Devta | ✅ | ✅ | false | ✅ | ✅ | R2 ✅ |

## 4. Search

| Term | Hits |
|---|---|
| `aankhi` | 1 — AANKHI MICHOLI |
| `baadri` | 1 — Baadri |

> Search matches on the `searchKeywords` array index (generated at import for
> every song from title + artist + album + region + language + genre), plus
> `titleLowercase`. The 68 new songs each carry generated `searchKeywords`,
> `titleLowercase`, `slug` and normalized fields.

## 5. Derived fields written per imported song

`title`, `titleLowercase`, `titleNormalized`, `slug`, `artistId`, `artistName`,
`albumId`, `albumTitle`, `searchKeywords`, `region`, `language`, `genre`,
`audioUrl` (R2), `artworkUrl` (R2), `durationMs`, `license=LICENSED`,
`rightsCleared=true`, `approvalStatus=approved`, `isApproved=true`,
`isPublished=true`, `reviewRequired=false`.

## 6. Verdict

All 68 newly-imported songs are **APPROVED and LIVE**. Home, Search, Region and
Featured queries return the catalog. No song is left pending, unpublished or
review-flagged.
