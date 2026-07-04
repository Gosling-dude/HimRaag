# Player Navigation Report

Date: 2026-07-04 · Branch: `feat/import-new-pahadi-songs`

## Behavior change

Tapping a song anywhere in the app now does what Spotify does: playback starts **and**
the Full Player slides up immediately (existing 350 ms bottom-up `SlideTransition` on
the `/player` route — unchanged). The queue is already loaded because the same tap
sets the queue before navigating. Back (or the ∨ button) returns to the exact screen
the user came from (`context.push`, so the stack is preserved).

## Implementation

One shared helper — `lib/features/player/presentation/player_navigation.dart`:

- `playSongAndOpenPlayer(context, ref, song, {queue, queueIndex})` — starts playback
  through the existing `PlayerController.playSong()` (untouched) and pushes `/player`.
- `resumeSongAndOpenPlayer(...)` — same for the Home "Continue Listening" rail
  (resumes at the saved position via the existing `playSongAt`).

## Call sites converted (every song tap in the app)

| Screen | Location |
|---|---|
| Home — all horizontal song rails (Made for You, Trending, New Releases, region rows, Recently Played) | `home_screen.dart` `_HorizontalSongList` |
| Home — Continue Listening card | `home_screen.dart` |
| Home — featured banner carousel | `featured_banner.dart` |
| Search — song results | `search_screen.dart` |
| All Songs — list tiles | `all_songs_screen.dart` |
| Album detail — track list | `album_detail_screen.dart` |
| Artist detail — popular songs | `artist_detail_screen.dart` |
| Category screen — list | `category_screen.dart` |
| Region screen — list | `region_screen.dart` |
| Playlist detail — list | `playlist_detail_screen.dart` |
| Library — Downloads / Favorites / Recent tabs | `library_screen.dart` |

**Deliberately unchanged:** "Play All" / "Shuffle" buttons (All Songs, album header)
still start queue playback without hijacking the screen — matching Spotify, where
context-play buttons don't force the full player open; the mini player appears
instead. Queue-sheet taps and mini-player controls are also unchanged.

## Full Player readiness

The Full Player already displays everything required: artwork, title, artist,
progress bar with seek, queue sheet, shuffle, repeat, favorite, download (in the ⋮
options sheet), and a lyrics view (placeholder text when a song has no lyrics).

One robustness fix in `full_player_screen.dart`: in the brief moment between tap and
the queue being registered, the screen used to say **"No song playing"**. It now shows
a quiet dark loading state with the dismiss button, which resolves to the track as
soon as the queue lands (typically < 100 ms).

## Verification

- `flutter analyze` — no issues.
- `flutter test` — 12/12 passed.
- Grep-verified: zero remaining direct `playSong` tap call sites outside the helper,
  the play-all buttons, and the player's own internals.
