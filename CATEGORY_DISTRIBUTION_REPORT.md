# CATEGORY DISTRIBUTION REPORT

_Generated: 2026-07-03T19:18:33.843Z_

Classification sources: explicit region tokens in source filenames (Latin + Devanagari), a curated known-artist→region dictionary, and public-metadata lookups (iTunes/MusicBrainz title+duration matches, with per-artist region voting from album titles). Songs that stay genuinely ambiguous remain in the **admin review queue** (Firestore `Needs Review`, unpublished) — never dumped into a specific region. The bundled catalog's legacy `Pahadi` umbrella persists only for previously-live ambiguous songs.

## Firestore (all songs)

| Region | Before | After |
|---|---|---|
| Garhwali | 47 | 215 |
| Kumaoni | 28 | 77 |
| Himachali | 78 | 194 |
| Jaunsari | 5 | 76 |
| Kinnauri | 1 | 51 |
| Sirmauri | 0 | 0 |
| Pahadi | 0 | 0 |
| Needs Review | 169 | 343 |

## Consumer-visible (approved, non-demo)

| Region | Before | After |
|---|---|---|
| Garhwali | 3 | 215 |
| Kumaoni | 5 | 77 |
| Himachali | 70 | 194 |
| Jaunsari | 2 | 76 |
| Kinnauri | 1 | 51 |
| Sirmauri | 0 | 0 |
| Pahadi | 0 | 0 |
| Needs Review | 0 | 0 |

## Bundled catalog (offline/local)

| Region | Before | After |
|---|---|---|
| Garhwali | 39 | 207 |
| Kumaoni | 25 | 74 |
| Himachali | 80 | 197 |
| Jaunsari | 4 | 75 |
| Kinnauri | 1 | 51 |
| Sirmauri | 0 | 0 |
| Pahadi | 169 | 93 |
| Needs Review | 0 | 0 |

Totals — Firestore: 956 songs; bundled: 697 songs.
