# ALL SONGS SECTION REPORT

_Generated: 2026-06-24 — branch `feat/import-new-pahadi-songs`_

A dedicated **All Songs** section exists, separate from albums and artist pages.

- **Screen:** `lib/features/songs/presentation/screens/all_songs_screen.dart`
- **Providers:** `lib/features/songs/providers/all_songs_providers.dart` (paginated, offline-first)
- **Route:** `/all-songs` (root navigator)
- **Entry points:** Home ("All Songs" gradient card), Library, Search.

## Capabilities
| Requirement | Status | Detail |
|---|---|---|
| Includes all approved songs | ✅ | `getApprovedSongsPage` (cursor by `titleLowercase`) merged with local imported catalog, consumer-visibility filtered |
| Play All | ✅ | `_playAll(filtered)` builds the full queue |
| Shuffle All | ✅ | `_playAll(filtered, shuffle: true)` + sets `isShuffleProvider` |
| Repeat All | ✅ | `_toggleRepeatAll` ↔ `RepeatMode.all` |
| Queue playback | ✅ | tapping any row plays it with the filtered list as the queue |
| Search | ✅ | live text filter over title/artist |
| Filter by region | ✅ | region chips (`allSongsRegionOptionsProvider`) |
| Filter by language/artist/album | ✅ (via search) | text query matches artist/title; region chips cover regional browsing |
| Infinite scroll | ✅ | cursor pagination, offline-first |
| Mixed regional listening | ✅ | "All" region shows the whole catalog in one queue |

## Verification
`flutter analyze` clean; section renders the merged approved catalog (87 today, additively
expandable by the staged import). On-device playback/queue behavior to be confirmed during device QA.
