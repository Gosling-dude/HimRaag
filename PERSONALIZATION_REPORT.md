# PERSONALIZATION REPORT

_Generated: 2026-06-24 — branch `feat/import-new-pahadi-songs`_

The home feed is now per-user. Two users with different onboarding choices, favorites, follows
or play history see a **different home ordering** — the core personalization requirement.

## Features delivered
| Feature | Where | How it works |
|---|---|---|
| Onboarding preferences | `preferences_screen.dart` | New users pick regions / languages / genres; stored in profile (`onboardingCompleted=true`). |
| Preferred region / language | `UserProfile.preferred*` | Drive Made-for-You scoring + region ordering. |
| Favorites | `library_providers.dart` | Hive source-of-truth, mirrored per-user to Firestore on toggle. |
| Recently played | `recentlyPlayedProvider` + Home `_RecentlyPlayedSection` | Local play history rail. |
| Continue listening | `playbackPersistenceProvider` + Home `_ContinueListeningSection` | Saves mid-track position (throttled ≥15s); resumes at saved position via `PlayerController.playSongAt`. |
| Followed artists | `followedArtistsProvider` + artist-detail `_FollowButton` | Follow/Following toggle; boosts Made-for-You. |
| Personalized feed | `personalizedSongsProvider` ("Made for You") | Ranked mix. |
| Region ordering | `personalizedRegionsProvider` | Curated "<Region> Hits" rows lead with the user's chosen regions. |

## "Made for You" ranking
Catalog (local imported ∪ trending, de-duped, consumer-visible) scored per song:

| Signal | Weight |
|---|---|
| song is a favorite | +6 |
| artist is followed | +5 |
| region ∈ preferred regions | +4 |
| genre ∈ preferred genres | +3 |
| language ∈ preferred languages | +2 |
| tie-break | `playCount` |

Songs with zero signal are dropped; top 15 returned. **No signal yet → the section hides**
(so it never duplicates "Trending" for a brand-new user). As soon as a user sets preferences,
favorites a track, or follows an artist, the rail appears and reorders.

## Home layout (consumer)
```
Greeting / search
Featured banner
Continue Listening      ← hidden if nothing to resume
All Songs entry
Region picker
Made for You            ← hidden until personalization signal
Recently Played         ← hidden if no history
Trending Now
New Releases
<Preferred Region> Hits … (preferred regions first)
Popular Albums / Featured Artists / Festival Collections
```

## Personalization rules — coverage
- ✅ New users get a default onboarding preference screen.
- ✅ Feed adapts to region/language/genre choices (region ordering + Made-for-You weights).
- ✅ Favorites and recent plays influence recommendations (favorites +6; trending blends play history).
- ✅ Different users do **not** all see the same ordering — Made-for-You + region order are derived from each user's profile/favorites/follows/continue-listening.

## Verification
`flutter analyze` clean. Cross-user ordering divergence is deterministic from the scoring above;
live multi-account behavior to be confirmed during device QA.
