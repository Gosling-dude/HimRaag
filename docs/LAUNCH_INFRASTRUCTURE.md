# Launch Infrastructure Runbook

How the production pieces fit together, and the order to switch them on.
Everything here is safe to roll out step by step: each step works on its own,
and the app falls back gracefully if a later step isn't done yet.

```
 App ──1 read──▶ Firestore feeds/home  ◀── aggregatePlays (every 30 min)
  │                                            ▲
  │ batched plays (≈1–2 calls/user/day)        │ playShards → playBatches
  └──▶ recordPlays (auth + daily quota) ───────┘   → songs.playCount, dailyPlays
  │
  └──▶ cdn.himraag.in (Cloudflare Worker) ──▶ R2 bucket himraag-audio
         audio/*   → Firebase ID token required (when REQUIRE_AUTH=true)
         artwork/* → public, edge-cached
```

| Piece | Where | Replaces |
|---|---|---|
| Media CDN Worker | `backend/cdn-worker/` | public `pub-….r2.dev` URL (rate-limited, not for production) |
| Play counting | `recordPlays` + `aggregatePlays` in `backend/functions/` | client `playCount` write that rules always rejected |
| Home feed | `feeds/home`, built by `aggregatePlays` | ~150–200 Firestore reads per Home open → 1 |
| R2 cleanup | `cleanupDeletedSongMedia` | old function that deleted from Firebase Storage (unused) |

---

## 1. Firebase: rules, indexes, functions

All Firebase config now lives in the root `firebase.json` (the old duplicate
`backend/firebase.json` + rules were stale and have been removed).

```bash
firebase use himraag-prod

# Rules + the new (isApproved, releaseYear) index. Wait for indexes to finish
# building (Console → Firestore → Indexes) before step 1c.
firebase deploy --only firestore

# R2 credentials for the cleanup function (same values as scripts/.env).
firebase functions:secrets:set R2_ACCESS_KEY_ID
firebase functions:secrets:set R2_SECRET_ACCESS_KEY

# Functions. First deploy prompts for R2_ACCOUNT_ID, R2_BUCKET and
# MEDIA_HOSTS (e.g. "cdn.himraag.in,pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev").
cd backend/functions && npm install && npm test && cd ../..
firebase deploy --only functions
```

Functions require the **Blaze** plan. At 50k daily users they stay in or near
the free tier (≈100k `recordPlays` calls/day, 48 aggregation runs/day).

**Console checks**
- Authentication → Sign-in method → **Anonymous: enabled** (guests now get a
  real anonymous account so their plays count and audio can be authorized).
- If you previously deployed the old functions, delete the leftovers:
  `firebase functions:delete onSongCreatedOrUpdated onArtistWrite onAlbumWrite incrementPlayCount recordUserActivity reindexAllSongs cleanupDeletedSongFiles --region us-central1`

## 2. Backfill sort fields (one-off)

The feed's indexed queries skip songs that lack `playCount` / `releaseYear`.

```bash
cd scripts
node migrate_launch_readiness.js            # dry run — review the list
node migrate_launch_readiness.js --apply
```

Then build the first feed without waiting 30 min: `firebase functions:shell`
→ `refreshHomeFeed({})` (admin-only callable; also handy after publishing).
Until the feed exists, the app falls back to its old per-row queries.

## 3. Media CDN (Cloudflare Worker)

```bash
cd backend/cdn-worker
npm install && npm test
npx wrangler login
npx wrangler deploy          # binds himraag-audio, serves cdn.himraag.in
```

Prerequisite: `himraag.in` (or whichever domain) is on Cloudflare DNS. Edit
`routes` in `wrangler.toml` if you use a different hostname.

Verify:
```bash
curl -I https://cdn.himraag.in/artwork/<some-key>.png      # 200, public cache
curl -I -H 'Range: bytes=0-1' https://cdn.himraag.in/audio/<some-key>.mp3   # 206
```

Ship with `REQUIRE_AUTH = "false"` first (step 5 flips it).

**Rate limiting:** add a Cloudflare WAF rate-limiting rule on
`cdn.himraag.in/audio/*` (e.g. 300 requests / 10 s per IP) as a second layer.

## 4. App release build

```bash
flutter build appbundle --release \
  --dart-define=MEDIA_CDN_BASE=https://cdn.himraag.in
```

With `MEDIA_CDN_BASE` set the app rewrites any `*.r2.dev` URL to the CDN at
read time, so it works before or after the Firestore URL migration below.
Without it, URLs are used exactly as stored (handy for local dev).

Optionally rewrite stored URLs too (keeps admin/web tools consistent):
```bash
node scripts/migrate_launch_readiness.js \
  --media-from https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev \
  --media-to https://cdn.himraag.in --apply
```

## 5. Lock down audio (after most users have the new build)

1. `backend/cdn-worker/wrangler.toml` → `REQUIRE_AUTH = "true"` → `npx wrangler deploy`.
2. Cloudflare dashboard → R2 → `himraag-audio` → Settings → **disable the
   r2.dev public URL**. From now on the bucket is reachable only via the Worker.

What this protects against, honestly: casual hotlinking, scraping the bucket
by URL, and other apps embedding your streams. A determined scraper can still
create an anonymous account and stream; the next layer is **App Check**
(Play Integrity) — enable it in the console, add `firebase_app_check` to the
app, then set `enforceAppCheck: true` on `recordPlays`.

---

## How play counting works

- The app counts a play after **30 s of real listening** (half the track for
  tracks under a minute). Seeking doesn't count; repeat-one counts again.
- Plays are buffered on device (Hive) and flushed every 10 plays, every 15 min,
  and when the app goes to the background. They survive restarts/offline.
- `recordPlays` requires sign-in (anonymous is fine), validates the payload,
  and enforces **500 plays per user per day**; one random shard doc is written
  per call, so no document gets hot.
- `aggregatePlays` (every 30 min) moves shard contents into `playBatches`,
  applies them to `songs.playCount` and `dailyPlays/{IST day}`, then rebuilds
  `feeds/home`. **Trending** = last 7 days of plays with daily decay (0.7×/day),
  topped up with all-time popular songs while history is thin.
- Firebase Analytics also receives a `song_play` event for dashboards.

## Expected cost at 50k daily users

| Item | Estimate / month |
|---|---|
| R2 storage + reads (audio egress is free) | ~$15 |
| Workers Paid — ~45–90M requests (players fetch audio in several range requests) | ~$15–30 |
| Firestore reads (feed + detail pages, ~30–50 per user/day) | ~$10–25 |
| Firestore writes + Functions (plays, aggregation) | ~$5–10 |
| Firebase Auth (standard, not Identity Platform) | $0 |
| **Total** | **≈ $45–100** |

Compared with ~$450–600/month for the previous read pattern. If Worker
requests ever dominate, serving artwork straight from an R2 custom domain
(no Worker) cuts them further — only audio needs the token check.
