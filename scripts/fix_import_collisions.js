/**
 * Post-enrichment cleanup before catalog generation:
 *   1. drop non-songs: teasers/shorts under 60 s
 *   2. collapse duplicate title+artist pairs (keep the longest recording)
 *   3. give Devanagari-only titles (empty ASCII slug) a stable hash-suffixed
 *      id/slug so they can't collide
 * Usage: node scripts/fix_import_collisions.js
 */
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { slugify, songId } = require('./lib/validator');

const ENRICHED = path.join(__dirname, 'seed_data', 'enriched.json');
const data = JSON.parse(fs.readFileSync(ENRICHED, 'utf8'));

const before = data.tracks.length;

// 1. teasers / shorts
const dropped = [];
data.tracks = data.tracks.filter((t) => {
  if ((t.durationMs || 0) < 60000) { dropped.push(`${t.title} (${Math.round(t.durationMs / 1000)}s — teaser/short)`); return false; }
  return true;
});

// 2. duplicate title+artist → keep longest
// Mirror import.js/validator normalization exactly so anything the importer
// would flag as a duplicate collapses here first.
const normalize = (v) => String(v || '').normalize('NFKD')
  .replace(/[̀-ͯ]/g, '').toLowerCase()
  .replace(/[^a-z0-9ऀ-ॿ\s]/g, ' ').replace(/\s+/g, ' ').trim();
const key = (t) => `${normalize(t.title)}|${normalize(t.artistName)}`;
const best = new Map();
for (const t of data.tracks) {
  const k = key(t);
  const cur = best.get(k);
  if (!cur || (t.durationMs || 0) > (cur.durationMs || 0)) best.set(k, t);
}
data.tracks = data.tracks.filter((t) => {
  if (best.get(key(t)) === t) return true;
  dropped.push(`${t.title} — ${t.artistName} (shorter duplicate)`);
  return false;
});

// 3. empty-slug (Devanagari) ids → hash suffix; also final id-uniqueness guard
const seen = new Set();
for (const t of data.tracks) {
  let slug = slugify(t.title);
  if (!slug) {
    const h = crypto.createHash('sha1').update(t.title).digest('hex').slice(0, 8);
    slug = `dv-${h}`;
    t.slug = slug;
    t.id = `${songId(t.artistName, '')}${slug.replace(/-/g, '_')}`;
  }
  let id = t.id || songId(t.artistName, t.title);
  let i = 2;
  while (seen.has(id)) id = `${t.id}_${i++}`;
  t.id = id;
  seen.add(id);
}

data.count = data.tracks.length;
fs.writeFileSync(ENRICHED, JSON.stringify(data, null, 2));
console.log(`tracks: ${before} → ${data.tracks.length}`);
dropped.forEach((d) => console.log(`  - dropped: ${d}`));
