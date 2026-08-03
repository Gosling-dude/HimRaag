# Search Audit (Phase 11)

**Date:** 2026-08-03

## Architecture

Search is a **union of two sources**, de-duplicated by ID with local results first
(`search_providers.dart::_mergeById`):

1. **Firestore** — `titleLowercase`/`nameLowercase` prefix range queries using a
   `` sentinel, backed by dedicated composite indexes, `limit`-bounded at 30.
2. **Bundled local catalogue** — case-insensitive `contains` over title, artist
   name and album title across all 697 bundled songs.

Both are filtered through `visibleToConsumers()` so unapproved or demo content can
never surface.

The two strategies are complementary in a useful way: Firestore gives **prefix**
matching over all 956 songs; the local scan gives **substring** matching over 697.
So "hadi" finds "Pahadi" via the local path even though a Firestore prefix query
would not match it.

## Capability by query type

| Query type | Supported | Mechanism |
|---|---|---|
| Song title | ✅ | Both paths |
| Artist name | ✅ | Both paths |
| Album title | ✅ | Both paths |
| Prefix ("paha…") | ✅ | Firestore range query over all 956 |
| **Partial / mid-word** ("hadi") | ⚠️ **Local only** | `contains` over the 697 bundled songs; a Firestore-only song will not match mid-word |
| Case-insensitive | ✅ | Lowercased on both sides |
| Mixed language / Devanagari | ⚠️ | Works only where the stored metadata itself is Devanagari — no transliteration layer exists |
| Region / keyword | ⚠️ | Via `SearchFilters`, not free-text |

### Honest limitation

There is **no fuzzy matching, no transliteration and no typo tolerance.** A user
typing "pahari" will not find "Pahadi", and one typing "पहाड़ी" will not find a
Latin-script title. For a folk-music app with a bilingual audience this is a real
usability gap — but closing it means a search service (Algolia/Typesense) or a
transliteration index, which is **new functionality and explicitly out of scope**
for this release. Recording it as the top post-launch search improvement.

*(Note: `algolia_search_datasource.dart` is a filename left over from an earlier
design — it contains only `SearchResult`/`SearchFilters` types. There is no Algolia
integration and Algolia is not a dependency.)*

## Fixed this pass: search was issuing a query per keystroke

`searchResultsProvider` re-ran on every `onChanged`, issuing 3 Firestore queries
plus a full local scan each time. Typing "pahadi" = **18 reads and 6 local scans**.

Now debounced at 300 ms. Verified by `test/search_debounce_test.dart`:

- six-keystroke burst → **exactly 1** backend search ✅
- nothing fires before the window elapses ✅
- abandoned query (typed then cleared) → **0** backend calls ✅
- two settled queries → 2 searches (real input is not swallowed) ✅

## "Search should feel instant"

- Debounce is 300 ms — below the ~400 ms threshold at which typing feels laggy,
  and it *removes* the mid-typing result flicker that made search feel unstable.
- The local path is in-memory and returns without a round-trip, so bundled songs
  appear essentially immediately after the window.
- Firestore queries are indexed and capped at 30 results.

**NOT MEASURED:** true end-to-end latency requires a device on a real network.
Measure with DevTools Network view in profile mode.
