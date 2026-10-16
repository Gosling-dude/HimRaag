# Play Store Listing

**App:** HimRaag · **Package:** `com.sumitchauhan.himraag` · **Default language:** English (United Kingdom) – en-GB

The text that goes into Play Console lives in `store/play/listings/en-GB/`. Edit it there
first, then copy it into the Console field it is named after. The previous Console
description is kept in `store/play/listings/en-GB/previous/`.

Last checked against Play Console: 2026-10-17 (see `PLAY_STORE_SETUP_STATUS.md`).

## Main store listing (Grow users → Store presence → Store listings → Default)

| Console field | Limit | Source / value | Console state |
|---|---|---|---|
| App name | 30 | `title.txt` — `HimRaag` | set |
| Short description | 80 | `short_description.txt` (66 chars) | set, unchanged |
| Full description | 4000 | `full_description.txt` (1,043 chars) | **saved as draft 2026-10-17** |
| App icon | 512×512 PNG | `app_icon_512_transparent.png` | uploaded |
| Feature graphic | 1024×500 | `feature_graphic.png` | uploaded |
| Phone screenshots | 2–8 | `01_home` … `08_categories` (8) | uploaded |
| 7" / 10" tablet screenshots | 4–8 each | the same 8 phone screenshots | uploaded |
| Video | optional | — | none |

The graphics exist only in Play Console; there are no source files in this repo.
Download them from the listing page into `store/play/graphics/` if you want them versioned.

### Why the description was replaced

The previous text claimed things the app does not do or have:

| Previous claim | Reality (from the code and catalogue) |
|---|---|
| "Thousands of regional songs" | 956 songs in Firestore (697 bundled), per `FINAL_DELIVERABLES.md` |
| "High-quality audio streaming" | MP3 files of mixed origin with no quality setting; the same text promised "Higher audio quality" as *coming soon* |
| "Personalized recommendations" | the home feed is ordered by the regions the user picks; there is no recommender |
| "Coming soon: Premium, AI recommendations, lyrics, playlist sharing, community" | none exist; Play's metadata policy discourages promising unreleased features |

The new text keeps to features that exist: streaming, browsing by region, category,
album and artist, search, in-app downloads, background playback with notification and
lock-screen controls, favourites, recently played, region preferences, Google sign-in
or guest mode, free with no ads or in-app purchases. It states no song count, because
the count depends on the rights review (see `PLAY_STORE_SETUP_STATUS.md`).

Do **not** claim: user-created playlists (not implemented), lyrics (no song has
lyrics), "thousands" of songs, or that guest data stays on the device (guest
accounts are anonymous Firebase users whose library syncs to Firestore).

## Store settings (Grow users → Store presence → Store settings)

| Setting | Value |
|---|---|
| App or game | App |
| Category | Music & audio |
| Tags | Music & audio, Entertainment (was also *Audio recorder* and *Musical instrument* — removed 2026-10-17; the app does neither) |
| Email address | himraag.review@gmail.com |
| Website | https://gosling-dude.github.io/himraag-legal/ |
| Phone | — |
| External marketing | on |

Play's tag list has no "music streaming" tag; *Radio*, *Audiobook* and *Video* tags do not apply.

## Release notes

One file per version code: `store/play/release-notes/<versionCode>/en-GB.txt` (max 500 characters).
`scripts/release/release_android.sh` refuses to build without it.

## Ideas, not yet done

- A Hindi (`hi-IN`) listing: the app declares `hi`, and much of the audience searches in Hindi.
- Tablet-specific screenshots. The app is portrait-locked, so the phone shots are acceptable, but
  Play shows them stretched on tablets.
- Screenshot 5's caption "High Quality Music" — consider "Background playback" instead, to match what
  the screenshot shows (the player with lock-screen-style controls).
