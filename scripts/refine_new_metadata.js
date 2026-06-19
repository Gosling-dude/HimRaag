/**
 * Phase 2 refinement — region / language / year / genre inference for the new
 * import batch, using confident filename tokens. Runs AFTER enrich_metadata.js
 * and BEFORE generate_import_catalog.js.
 *
 * Policy:
 *   - Only OVERRIDE a field that enrichment left as the "Needs Review"/placeholder
 *     sentinel — never clobber a value enrichment was confident about.
 *   - Region is set ONLY from a confident token. Genuinely-ambiguous tracks fall
 *     back to the generic umbrella region "Pahadi" (a real, non-sentinel value;
 *     it simply isn't one of the six consumer region chips, so it is never
 *     mislabeled into a specific region it doesn't belong to).
 *   - Artist stays "Unknown Artist" → polish_catalog.js maps it to "Pahadi Folk"
 *     (the established curatorial collective), consistent with the original 19.
 *
 * Idempotent. Usage: node scripts/refine_new_metadata.js
 */
'use strict';
const fs = require('fs');
const path = require('path');
const ENRICHED = path.join(__dirname, 'seed_data', 'enriched.json');
const NEEDS = 'Needs Review';

// region -> ordered list of confident lowercase substrings found in filenames.
const REGION_TOKENS = [
  ['Kinnauri', ['kinnauri', 'kinnaur', 'kinnaura']],
  ['Sirmauri', ['sirmauri', 'sirmaur']],
  ['Jaunsari', ['jaunsari', 'jaunsar', 'harul']], // Harul is a Jaunsari folk form
  ['Kumaoni', ['kumaoni', 'kumauni', 'kumaon', 'nainital', 'almora', 'pithoragarh']],
  ['Garhwali', ['garhwali', 'garhwal', 'tehri', 'pauri', 'satpuli', 'srinagar',
    'dhol damau', 'dhol_damau', 'uttrakhandi', 'uttarakhandi']],
  ['Himachali', ['himachali', 'himachal', 'shimla', 'nati', 'rohru', 'mashakbeen',
    'mandi', 'kullu', 'shivratri', 'brahmkhada', 'bhramkhada', 'bhramakhada',
    'brahmkhda', 'pahari']],
];

const DEVOTIONAL = ['shivratri', 'bhajan', 'brahmkhada', 'bhramkhada', 'bhramakhada',
  'mahadev', 'shiv ', 'shiv_', 'devta', 'jai ', 'jai_', 'vivah', 'baraat', 'devi'];
const FESTIVAL = ['mela', 'jatre', 'jatra', 'jaat', 'mahotsav'];

function inferRegion(fnLower) {
  for (const [region, tokens] of REGION_TOKENS) {
    if (tokens.some((t) => fnLower.includes(t))) return region;
  }
  return null;
}

function inferGenre(fnLower) {
  if (DEVOTIONAL.some((t) => fnLower.includes(t))) return 'Devotional';
  if (FESTIVAL.some((t) => fnLower.includes(t))) return 'Festival';
  return null;
}

function inferYear(fn) {
  const m = fn.match(/\b(19[5-9]\d|20[0-2]\d)\b/);
  return m ? Number(m[1]) : null;
}

function main() {
  const data = JSON.parse(fs.readFileSync(ENRICHED, 'utf8'));
  let regionFixed = 0, generic = 0, yearFixed = 0, genreFixed = 0;
  const dist = {};

  for (const t of data.tracks) {
    const fnLower = (t.filename || '').toLowerCase();

    // Region / language — only override the sentinel WHEN a confident token
    // matches. Genuinely-ambiguous tracks keep "Needs Review" (accepted by the
    // canonical validator; polish_catalog.js maps it to a sensible consumer
    // region). We never fabricate a specific region we aren't sure about.
    if (t.region === NEEDS || !t.region) {
      const r = inferRegion(fnLower);
      if (r) {
        t.region = r;
        t.fields.region = { value: r, source: 'filename', conf: 0.7 };
        t.language = r;
        t.fields.language = { value: r, source: 'filename', conf: 0.6 };
        regionFixed++;
        if (Array.isArray(t.reviewReasons)) {
          t.reviewReasons = t.reviewReasons.filter(
            (x) => !/region uncertain|language uncertain/i.test(x));
        }
      } else {
        generic++; // stays "Needs Review"
      }
    }

    // Year.
    if (!Number.isFinite(t.releaseYear)) {
      const y = inferYear(t.filename || '');
      if (y) { t.releaseYear = y; t.fields.year = { value: y, source: 'filename', conf: 0.8 }; yearFixed++; }
    }

    // Genre (only upgrade the low-confidence default).
    const g = inferGenre(fnLower);
    if (g && (t.genre === 'Folk' || !t.genre)) {
      t.genre = g;
      t.fields.genre = { value: g, source: 'filename', conf: 0.75 };
      genreFixed++;
    }

    dist[t.region] = (dist[t.region] || 0) + 1;
  }

  fs.writeFileSync(ENRICHED, JSON.stringify(data, null, 2));
  console.log(`Refined ${data.tracks.length} tracks.`);
  console.log(`  region from token: ${regionFixed} | generic "Pahadi": ${generic} | year: ${yearFixed} | genre: ${genreFixed}`);
  console.log('  region distribution:', JSON.stringify(dist));
}
main();
