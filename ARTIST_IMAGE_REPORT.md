# ARTIST IMAGE REPORT

_Generated: 2026-06-24 — branch `feat/import-new-pahadi-songs`_

## Policy (enforced)
- Real artist photos when a genuine one exists.
- Otherwise a **clean neutral placeholder avatar** (the app's gradient + initials `AppAvatar`).
- **No AI faces, no fabricated portraits, no text overlays.**

## Current catalog state (verified)
Firestore: **16 artist docs**. Every doc has an `imageUrl` (0 missing, 0 `picsum`/placeholder-domain
URLs detected in the production scan). Per the prior art pass, folk-artist FACE photos are not
reliably available from license-clean public sources (JioSaavn entries for these names are album
covers or default placeholders, not portraits), so artists intentionally render the app's
gradient+initials `AppAvatar` rather than any AI-generated or misattributed face — consistent with
the documented art direction. This is the compliant choice, not a gap.

| Source | Count | Treatment |
|---|---|---|
| Real photo available | per-artist (album/promo imagery only where genuinely the artist) | real image |
| No genuine photo | remainder | gradient+initials `AppAvatar` (neutral, no AI, no text) |

## New import (237 songs) — staged
The 237 new songs collapse to a small set of new artists (most default to the **Pahadi Folk**
curatorial collective until per-track public-metadata enrichment assigns a real performer). When
the staged enrichment pipeline runs, artist images follow the same policy: real photo if found,
else neutral placeholder. No AI portraits will be generated.

## Verification
Production artist docs scanned: 16/16 have an image URL; 0 placeholder-domain, 0 AI. New-artist
imagery is created by the staged real-art pipeline (see NEW_IMPORT_REPORT.md), not in this session.
