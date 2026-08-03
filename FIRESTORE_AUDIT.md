# Firestore Audit (Phase 4)

**Date:** 2026-08-03 · **Project:** `himraag-prod` · **Method:** live `count()`
aggregations and rules review. **No document was written or deleted.**

## Collection inventory (live counts)

| Collection | Documents | Notes |
|---|---:|---|
| `songs` | **956** | Full catalogue |
| `artists` | **217** | |
| `albums` | **173** | |
| `users` | **19** | Real accounts |
| `categories` | **6** | |
| `auditLogs` | **4** | Append-only moderation trail |
| `playlists` | 0 | Feature present, none created yet |
| `regions` | 0 | Regions are resolved from song fields, not this collection |
| `submissions` | 0 | Artist upload workflow, unused so far |
| `featured` | 0 | |
| `banners` | 0 | |
| **Total** | **1,375** | |

## Bundled catalogue vs Firestore

The app ships `assets/catalog/imported_catalog.json` (697 songs, 1.1 MB).

**Verified: all 697 bundled song IDs exist in Firestore (0 missing).** The bundle
is a strict subset and functions purely as an offline/first-launch fallback — it
holds no unique content and can never show a song that Firestore lacks.

*Implication for size:* the 1.1 MB is redundant **only** if you are willing to give
up offline first-launch browsing. It is currently the sole reason a cold start
with no network still renders a catalogue. **Recommend keeping it.**

## Security rules

`firestore.rules` reviewed in full. Structure is sound:

| Collection | Read | Write | Verdict |
|---|---|---|---|
| `songs`, `albums`, `categories`, `regions`, `featured`, `banners` | public | admin only | ✅ correct for a public catalogue |
| `artists` | public | admin, or owning artist with moderation fields pinned | ✅ well-constructed |
| `users` | owner + admin | owner | ✅ see note below |
| `playlists` | public-if-public, else owner/admin | owner/admin | ⚠️ minor, see below |
| `submissions` | admin or submitter | artist creates as `pending`; only admin changes status | ✅ no self-approval |
| `auditLogs` | admin | create-only; **update/delete `false`** | ✅ genuinely append-only |

### Privilege escalation — checked, not exploitable

`users/{userId}` allows the owner to write **any** field in their own document,
including `admin: true`. This is **not** an escalation path: `isAdmin()` reads
`request.auth.token.admin`, a Firebase **custom claim** set server-side by
`scripts/set_claims.js`, and `lib/admin/admin_auth.dart:36` likewise derives role
from `getIdTokenResult()` claims — never from Firestore. A user writing
`admin: true` into their own document grants them nothing.

### Minor finding (P3)

`playlists` update does not pin `ownerId`:
```
allow update, delete: if isOwner(resource.data.ownerId);
```
An owner could reassign `ownerId` to another user, handing over a playlist
unilaterally. No collection currently holds playlists (0 documents), so impact is
nil today. Suggested hardening:
```
allow update: if isOwner(resource.data.ownerId)
  && request.resource.data.ownerId == resource.data.ownerId;
```

Unlisted paths are denied by Firestore's default, so no catch-all rule is needed.

## Indexes

15 composite indexes defined in `firestore.indexes.json`. They line up with the
query shapes in the datasources:

- `isApproved + playCount|releasedAt` — Home rows ✅
- `isApproved + region|genre + playCount` — region and category screens ✅
- `albumId|artistId + isApproved` — detail screens ✅
- `isApproved + titleLowercase` — prefix search ✅ (matches the `` sentinel range query in `firestore_search_datasource.dart`)
- `submissions`, `auditLogs` — admin dashboard ✅

**No missing index was found for any query in the codebase.** No unused index was
identified either; each maps to a live query path.

## Read-cost — one real problem, now fixed

Search previously ran **one Firestore query set per keystroke**. `searchResultsProvider`
watched `searchQueryProvider`, which the text field updated on every `onChanged`,
and each run issued three parallel queries (songs + artists + albums).

Typing "pahadi" therefore cost **18 Firestore reads per user per search**.

Fixed with a 300 ms debounce; a settled query now costs 3 queries regardless of
length. Covered by `test/search_debounce_test.dart` (4 tests), which asserts the
datasource is called exactly once for a six-keystroke burst.

At 19 users this was invisible. At launch scale it was the app's dominant read cost.

## Document hygiene

- Duplicate documents: none found — song IDs are unique (asserted by `test/imported_catalog_test.dart`).
- Orphan artists/albums: not separately re-derived this pass; `scripts/reconcile_counts.js`
  performs this check but **writes** to Firestore, so it was deliberately not run.
  Run it yourself if you want counts re-reconciled.
- Missing thumbnails / profile images: 3 total across 2,302 assets — see R2_AUDIT.md.
