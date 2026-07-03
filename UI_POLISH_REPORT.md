# UI POLISH REPORT

_Generated: 2026-06-24 — branch `feat/import-new-pahadi-songs`_

## Consumer-facing polish (verified)
- **Moderation labels hidden from consumers.** Consumer render sites use the
  `consumer_labels.dart` extension getters (`displayArtist` / `displayRegion` / `displayTitle` /
  `displayName`) which sanitize sentinels (`Unknown Artist` → Pahadi Folk, `Needs Review` → real
  region). Applied across `song_card`, `album_card`, `artist_card`, `featured_banner`,
  `song_list_tile`, `mini_player`, `queue_view`, `full_player`, and search.
- **No pending/review labels in consumer screens.** Grep of `lib/features/{home,songs,library,search}`
  for `reviewRequired`/`pending`/`Needs Review` finds only the Home `populatedRegionsProvider`,
  which *excludes* `Needs Review` regions from the region rows — i.e. it hides the sentinel, never
  shows it. Admin/artist dashboards keep RAW fields (so the metadata-review queue still works).
- **No duplicate / stale test tracks in visible lists.** Verified: bundled catalog 87/87 LICENSED,
  Firestore 97/97 clean (0 demo/instrumental/placeholder) — see DUPLICATE_CLEANUP_REPORT.md.
- **Thumbnails / photos / covers.** `AppArtwork` (square) + `AppAvatar` (circle) wrap
  `CachedNetworkImage` with shimmer placeholder + branded gradient/initials fallback (no bare grey
  music-note icons). Production scan: 0 missing/placeholder artwork across songs/albums/artists.
- **Curated, professional home feed** + new personalized rails (Continue Listening, Made for You,
  Recently Played) that self-hide when empty — see PERSONALIZATION_REPORT.md.

## Consumer app shows
Approved songs · curated collections (region/festival rows) · personalized recommendations
("Made for You") · favorites · recent plays · region-based lists · the new "Continue Listening" rail.

## Admin dashboard shows (unchanged, separate from consumer)
Review status · metadata status · duplicate detection · import status — backed by RAW model fields
(`region == 'Needs Review'`, `reviewRequired`, `approvalStatus`), which the consumer layer never
surfaces.

## Verification
`flutter analyze` clean (0 issues). Visual polish confirmed by code audit; on-device appearance to
be confirmed during device QA on the release APK.
