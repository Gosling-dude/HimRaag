# ARTIST IMAGE AUDIT

_Generated: 2026-07-03T23:48:36.330Z · read-only probe_

## Firestore artists (217)

| Metric | Value |
|---|---|
| Real reachable image | **170 (78.3%)** |
| Empty imageUrl (app renders initials avatar) | 47 |
| Broken | 0 |

## Bundled catalog artists (148)

| Real reachable image | **0 (0%)** | Empty: 56 · Broken: 92 |

## Bundle/Firestore divergence (bundle empty, Firestore has real photo)

**9 artists** — the app merges local-first, so these render initials avatars even though a real photo exists:

- Pahadi Folk (artist_unknown_artist) → https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/ai-meena-tor-bina-0.png
- Inder Arya (artist_inder_arya) → https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/char-ghuriya-gaadi-0.png
- Meena Rana (artist_meena_rana) → https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/aankhiyoon-ki-bhou-garhwali-song-feat-meena-rana-0.png
- Narendra Singh Negi (artist_narendra_singh_negi) → https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/aejadi-bhagyani-0.png
- Ankit Rawat (artist_ankit_rawat) → https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/handsome-feat-ankit-rawat-deepika-upreti-0.png
- Mamta Arya (artist_mamta_arya) → https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/maathi-maathi-najra-feat-mamta-arya-0.png
- Mohan Singh Chauhan (artist_mohan_singh_chauhan) → https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/farmaish-latestphadi-song-mohan-singh-chauhan-swar-samrat-music-0.png
- Hema Negi Karasi (artist_hema_negi_karasi) → https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artist/hema-negi-karasi-v5.jpg
- Manju Nautiyal (artist_manju_nautiyal) → https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev/artwork/danda-ki-jatra-0.png

## Post-repair verification (2026-07-04)

The July import had overwritten existing artist docs with 2 KB generated
placeholder PNGs, and the bundled catalog hid real Firestore photos for the
headline featured artists (local record wins the app's merge). Repairs
(`scripts/repair_artist_images.js` — restores existing assets only, no
regeneration):

| Check | Result |
|---|---|
| Artist docs repaired (Firestore) | 210 (23 real portraits restored, rest use their top song's real cover) |
| Generated placeholder PNGs remaining | 0 |
| Bundle artists with a real image URL | **147/148** (was effectively 0 rendering correctly) |
| Sampled artist image URLs | 15/15 HTTP 200 |
| Real portraits (Wikipedia/JioSaavn, hosted on R2) | 23 — incl. Narendra Singh Negi, Meena Rana, Pritam Bharatwan, Mohan Upreti, Hema Negi Karasi |
