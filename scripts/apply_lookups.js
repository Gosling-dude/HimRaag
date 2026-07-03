/**
 * Merge public-metadata lookup results (seed_data/public_lookup.json) into
 * enriched.json before the R2/catalog/Firestore stages.
 *
 * Per track with a confident lookup match (title similarity + duration match):
 *   - artist   ← looked-up credit (placeholder tracks only)
 *   - region   ← 1) explicit region keyword in the looked-up ALBUM/TITLE text
 *                2) known-artist dictionary (any credited name)
 *                3) per-artist region VOTE: if the same credited artist has
 *                   other tracks whose album text carries a region keyword,
 *                   the majority region applies to their keyword-less tracks.
 *   - year     ← release year when missing
 *   - publicArtworkUrl ← genuine cover-art URL (consumed by the artwork stage)
 * ids/slugs are recomputed after artist changes; id collisions get -2 suffixes.
 *
 * Usage: node scripts/apply_lookups.js
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { slugify, songId, artistId, albumId } = require('./lib/validator');
const {
  KNOWN_ARTISTS, regionFromKeywords, LANGUAGE_FOR_REGION,
} = require('./lib/pahadi_artists');

const ENRICHED = path.join(__dirname, 'seed_data', 'enriched.json');
const LOOKUP = path.join(__dirname, 'seed_data', 'public_lookup.json');
const NEEDS = 'Needs Review';

/** Region for a (possibly multi-credit) artist string via the dictionary. */
function regionFromArtists(artistStr) {
  const parts = String(artistStr || '').split(/\s*[,&]\s*|\s+and\s+/i);
  for (const p of parts) {
    const r = KNOWN_ARTISTS[p.trim().toLowerCase()];
    if (r) return r;
  }
  return null;
}

function main() {
  const data = JSON.parse(fs.readFileSync(ENRICHED, 'utf8'));
  const lookups = JSON.parse(fs.readFileSync(LOOKUP, 'utf8')).results;

  // Pass 1 — apply direct fields + collect per-artist region votes.
  const votes = new Map(); // artistKey -> {region: count}
  let matched = 0;
  for (const t of data.tracks) {
    const lk = lookups[t.id];
    if (!lk) continue;
    matched++;
    t._lookup = lk;
    const albumText = `${lk.album || ''} ${lk.matchedTitle || ''}`;
    const kwRegion = regionFromKeywords(albumText);
    const artistKey = (lk.artist || '').toLowerCase();
    if (kwRegion && artistKey) {
      const v = votes.get(artistKey) || {};
      v[kwRegion] = (v[kwRegion] || 0) + 1;
      votes.set(artistKey, v);
    }
  }

  // Majority region per artist (≥1 vote and unambiguous majority).
  const artistRegion = new Map();
  for (const [k, v] of votes) {
    const sorted = Object.entries(v).sort((a, b) => b[1] - a[1]);
    if (sorted.length === 1 || sorted[0][1] > sorted[1][1]) {
      artistRegion.set(k, sorted[0][0]);
    }
  }

  // Pass 2 — resolve fields.
  let artistSet = 0, regionSet = 0, yearSet = 0, artSet = 0;
  const seenIds = new Set(data.tracks.filter((t) => !t._lookup).map((t) => t.id));
  for (const t of data.tracks) {
    const lk = t._lookup;
    if (!lk) continue;
    delete t._lookup;

    if (t.artistName === 'Unknown Artist' && lk.artist) {
      t.artistName = lk.artist.replace(/\s+/g, ' ').trim();
      t.fields.artist = { value: t.artistName, source: 'web', conf: 0.8 };
      artistSet++;
    }
    if (t.region === NEEDS) {
      const albumText = `${lk.album || ''} ${lk.matchedTitle || ''}`;
      const region = regionFromKeywords(albumText) ||
        regionFromArtists(t.artistName) ||
        artistRegion.get((lk.artist || '').toLowerCase()) || null;
      if (region) {
        t.region = region;
        t.fields.region = { value: region, source: 'web', conf: 0.75 };
        t.language = LANGUAGE_FOR_REGION[region] || t.language;
        t.fields.language = { value: t.language, source: 'web', conf: 0.75 };
        regionSet++;
        if (Array.isArray(t.reviewReasons)) {
          t.reviewReasons = t.reviewReasons.filter((x) => !/region|language/i.test(x));
        }
      }
    }
    if (!Number.isFinite(t.releaseYear) && lk.year) {
      t.releaseYear = lk.year;
      t.fields.year = { value: lk.year, source: 'web', conf: 0.8 };
      yearSet++;
    }
    if (lk.artworkUrl) { t.publicArtworkUrl = lk.artworkUrl; artSet++; }

    // Recompute identity after artist changes; keep ids unique.
    t.slug = slugify(t.title);
    t.artistId = artistId(t.artistName);
    t.albumId = albumId(t.artistName, t.albumTitle);
    let id = songId(t.artistName, t.title);
    let i = 2;
    while (seenIds.has(id)) id = `${songId(t.artistName, t.title)}_${i++}`;
    t.id = id;
    seenIds.add(id);
  }

  fs.writeFileSync(ENRICHED, JSON.stringify(data, null, 2));
  const dist = {};
  data.tracks.forEach((t) => (dist[t.region] = (dist[t.region] || 0) + 1));
  console.log(`lookup matches applied: ${matched}`);
  console.log(`  artist set: ${artistSet} | region set: ${regionSet} | year set: ${yearSet} | real covers: ${artSet}`);
  console.log(`  artist-region votes resolved: ${artistRegion.size} artists`);
  console.log('  region distribution:', JSON.stringify(dist));
}

main();
