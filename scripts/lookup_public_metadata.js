/**
 * Public-metadata lookup for tracks whose filenames carry no artist/region
 * signal. For each track we query the iTunes Search API (public, no key) and
 * fall back to MusicBrainz. A match is accepted ONLY when the normalized title
 * matches AND the track duration agrees within ±20s — a strong two-factor
 * match that avoids false positives on generic titles.
 *
 * No audio is downloaded — public metadata only (artist, album, year,
 * genuine cover-art URL).
 *
 * Incremental + resumable: results append to seed_data/public_lookup.json.
 * Rate-limited to respect both services (~3s between calls).
 *
 * Usage:
 *   node scripts/lookup_public_metadata.js [--limit N]
 *   node scripts/lookup_public_metadata.js --file <tracks.json> --out <results.json>
 *     where tracks.json = { tracks: [{id, title, durationMs, region?, artistName?}] }
 */
'use strict';
const fs = require('fs');
const path = require('path');
const https = require('https');

const ENRICHED = path.join(__dirname, 'seed_data', 'enriched.json');
const OUT = path.join(__dirname, 'seed_data', 'public_lookup.json');

const norm = (s) => String(s || '').toLowerCase().normalize('NFKD')
  .replace(/[̀-ͯ]/g, '').replace(/[^\p{L}\p{N} ]+/gu, ' ').replace(/\s+/g, ' ').trim();

function tokenSim(a, b) {
  const A = new Set(norm(a).split(' ')), B = new Set(norm(b).split(' '));
  if (!A.size || !B.size) return 0;
  let inter = 0;
  for (const t of A) if (B.has(t)) inter++;
  return inter / Math.max(A.size, B.size);
}

function getJson(url, headers = {}) {
  return new Promise((resolve) => {
    https.get(url, { headers: { 'User-Agent': 'HimRaag-metadata/1.0 (catalog enrichment)', ...headers } }, (res) => {
      let body = '';
      res.on('data', (c) => (body += c));
      res.on('end', () => {
        try { resolve(JSON.parse(body)); } catch { resolve(null); }
      });
    }).on('error', () => resolve(null));
  });
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function lookupItunes(title, durationMs) {
  const url = `https://itunes.apple.com/search?term=${encodeURIComponent(title)}&entity=song&limit=8&country=IN`;
  const data = await getJson(url);
  if (!data || !Array.isArray(data.results)) return null;
  for (const r of data.results) {
    const sim = tokenSim(title, r.trackName);
    const durOk = durationMs > 0 && r.trackTimeMillis > 0 &&
      Math.abs(r.trackTimeMillis - durationMs) <= 20000;
    if (sim >= 0.75 && durOk) {
      return {
        source: 'itunes',
        matchedTitle: r.trackName,
        artist: r.artistName || null,
        album: r.collectionName || null,
        year: r.releaseDate ? Number(r.releaseDate.slice(0, 4)) : null,
        genre: r.primaryGenreName || null,
        artworkUrl: r.artworkUrl100
          ? r.artworkUrl100.replace('100x100', '600x600')
          : null,
        similarity: Number(sim.toFixed(2)),
      };
    }
  }
  return null;
}

async function lookupMusicBrainz(title, durationMs) {
  const q = encodeURIComponent(`recording:"${title.replace(/"/g, '')}"`);
  const url = `https://musicbrainz.org/ws/2/recording?query=${q}&fmt=json&limit=8`;
  const data = await getJson(url);
  if (!data || !Array.isArray(data.recordings)) return null;
  for (const r of data.recordings) {
    const sim = tokenSim(title, r.title);
    const durOk = durationMs > 0 && r.length > 0 && Math.abs(r.length - durationMs) <= 20000;
    if (sim >= 0.8 && durOk && r['artist-credit'] && r['artist-credit'][0]) {
      return {
        source: 'musicbrainz',
        matchedTitle: r.title,
        artist: r['artist-credit'].map((a) => a.name).join(', '),
        album: (r.releases && r.releases[0] && r.releases[0].title) || null,
        year: (r['first-release-date'] || '').slice(0, 4) ? Number((r['first-release-date'] || '').slice(0, 4)) : null,
        genre: null,
        artworkUrl: null,
        similarity: Number(sim.toFixed(2)),
      };
    }
  }
  return null;
}

async function main() {
  const limitArg = process.argv.indexOf('--limit');
  const limit = limitArg > -1 ? Number(process.argv[limitArg + 1]) : Infinity;
  const fileArg = process.argv.indexOf('--file');
  const outArg = process.argv.indexOf('--out');
  const inPath = fileArg > -1 ? path.resolve(__dirname, process.argv[fileArg + 1]) : ENRICHED;
  const outPath = outArg > -1 ? path.resolve(__dirname, process.argv[outArg + 1]) : OUT;

  const enriched = JSON.parse(fs.readFileSync(inPath, 'utf8'));
  const done = fs.existsSync(outPath) ? JSON.parse(fs.readFileSync(outPath, 'utf8')) : { results: {} };

  // Targets: unresolved region OR placeholder artist (both benefit).
  const targets = enriched.tracks.filter(
    (t) => (!t.region || t.region === 'Needs Review' || t.region === 'Pahadi' ||
      !t.artistName || t.artistName === 'Unknown Artist' || t.artistName === 'Pahadi Folk') &&
      !(t.id in done.results)
  );
  console.log(`lookup targets: ${targets.length} (already done: ${Object.keys(done.results).length})`);

  let hits = 0, processed = 0;
  for (const t of targets) {
    if (processed >= limit) break;
    processed++;
    let res = await lookupItunes(t.title, t.durationMs);
    await sleep(3100);
    if (!res) {
      res = await lookupMusicBrainz(t.title, t.durationMs);
      await sleep(1200);
    }
    done.results[t.id] = res; // null = looked up, no confident match
    if (res) {
      hits++;
      console.log(`  ✓ ${t.title} → ${res.artist} [${res.source} sim=${res.similarity}]`);
    }
    if (processed % 20 === 0) {
      fs.writeFileSync(outPath, JSON.stringify(done, null, 1));
      console.log(`  … ${processed}/${targets.length} (hits ${hits})`);
    }
  }
  fs.writeFileSync(outPath, JSON.stringify(done, null, 1));
  console.log(`DONE processed=${processed} hits=${hits} total-cached=${Object.keys(done.results).length}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
