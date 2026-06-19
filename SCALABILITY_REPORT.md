# HimRaag — Scalability Report (Phase 8)

_Target: 100,000+ songs with no full-collection scans, bounded reads, and smooth UI._

This report documents how the catalog — and specifically the new **All Songs**
section — stays O(page) regardless of catalog size.

## 1. Firestore pagination (cursor-based)

The All Songs feed is served by a **cursor-paginated** query, not a full read:

`lib/data/remote/firebase_song_datasource.dart` → `getApprovedSongsPage()`

```dart
_songs
  .where('isApproved', isEqualTo: true)
  .orderBy('titleLowercase')
  .limit(60)                       // bounded page
  .startAfter([lastTitleLowercase]) // cursor — no offset scan
```

- Each page reads **at most 60 documents**, independent of total catalog size.
- Pagination uses a **document cursor** (`startAfter`) — not `offset` — so page N
  costs the same as page 1 (no scanning-and-discarding).
- Backed by the composite index `(isApproved ASC, titleLowercase ASC)` already
  declared in `firestore.indexes.json`.

The UI controller (`lib/features/songs/providers/all_songs_providers.dart`,
`AllSongsController`) holds an accumulating list + a title cursor and calls
`loadMore()` only when the user scrolls within 400px of the end. At 100k songs the
device holds only what has been scrolled into view.

## 2. Lazy loading / virtualization

- `AllSongsScreen` renders with `ListView.builder` (+ a trailing loader cell) —
  only visible rows are built; rows scroll out are recycled.
- Infinite scroll: `_onScroll` triggers the next page near the bottom; a re-entry
  guard (`_busy`) prevents duplicate page fetches.
- Offline-first seed: the bundled catalog (`assets/catalog/imported_catalog.json`)
  is shown instantly, then Firestore pages are merged in (deduped by id), so the
  first paint never waits on the network.

## 3. Cached artwork

- All artwork renders through `AppArtwork` → **`CachedNetworkImage`**
  (`cached_network_image: ^3.4.1`), which caches decoded images on disk + memory.
- Artwork is served from **Cloudflare R2** (CDN-backed public URLs), versioned by
  key (`-v4`) for cache-busting — so a scrolled-away cover is not re-downloaded.

## 4. Indexed queries — no full-collection scans

Every consumer query path is filter+limit and index-backed. Existing composite
indexes (`firestore.indexes.json`):

| Query | Index |
|---|---|
| All Songs page (A→Z) | `isApproved`, `titleLowercase` |
| Region page | `isApproved`, `region`, `playCount` |
| Genre page | `isApproved`, `genre`, `playCount` |
| Artist songs | `artistId`, `isApproved`, `playCount` |
| Album songs | `albumId`, `isApproved` |
| Trending / Featured / New | `isApproved` + `playCount` / `releasedAt` (limited) |
| Search (admin) | `approvalStatus`, `titleLowercase` / `region`, `titleLowercase` |

The region/artist filters on the All Songs screen operate on the already-loaded
page set for instant feedback; for very large catalogs the same filters map
directly to the indexed server queries above (`getSongsByRegion`,
`getSongsByArtist`) — so they remain O(page) server-side as well.

## 5. Write-path scalability (import pipeline)

- R2 upload uses **size/checksum dedup** (`HEAD` before `PUT`) — re-running never
  re-uploads objects already present, and resumes after a network drop.
- Firestore writes are **batched** (≤400 ops/commit) and **idempotent upserts**
  (`set(..., {merge:true})`), so re-imports never duplicate or wipe documents.
- Search is keyworded at write time (`searchKeywords`, `titleLowercase`,
  `artistNameLowercase`, `albumTitleLowercase`) so reads stay equality-indexed.

## 6. Headroom summary

| Concern | Mechanism | Cost at 100k songs |
|---|---|---|
| List the catalog | cursor pagination (60/page) | 60 reads/page |
| Scroll | `ListView.builder` virtualization | constant memory |
| Artwork | CDN (R2) + disk/memory cache | one fetch per unique cover |
| Filter by region/artist | indexed equality queries | O(page) |
| Search | keyword/equality index | O(matches/page) |
| Import | batched idempotent upserts + dedup | O(new items) |

No consumer code path performs an unbounded `collection().get()`.
