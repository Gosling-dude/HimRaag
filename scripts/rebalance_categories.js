/**
 * Category rebalance + artist reattribution for the EXISTING catalog
 * (Firestore + bundled assets/catalog/imported_catalog.json).
 *
 * For every song whose region is the "Pahadi" umbrella / "Needs Review" / empty,
 * or whose artist is the "Unknown Artist" placeholder:
 *   1. region  ← explicit filename/title token (Latin or Devanagari)
 *              ← else the known-artist dictionary (lib/pahadi_artists.js)
 *              ← else an optional public-metadata lookup file (--lookups)
 *              ← else UNCHANGED (Firestore keeps "Needs Review" for the admin
 *                queue; the bundled catalog keeps the honest "Pahadi" umbrella —
 *                never a fabricated specific region).
 *   2. artist  ← known-artist dictionary → surname-pattern extraction → lookup
 *                file. Songs keep their album; new artist docs are upserted.
 *   3. language follows the resolved region; searchKeywords are rebuilt.
 *
 * Usage:
 *   node scripts/rebalance_categories.js            # dry-run (prints plan)
 *   node scripts/rebalance_categories.js --commit   # write Firestore + bundle
 *   node scripts/rebalance_categories.js --commit --lookups seed_data/firestore_lookup.json
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { firebaseServiceAccountPath } = require('./lib/credentials');
const {
  matchKnownArtist, extractArtistName, regionFromKeywords,
  KNOWN_ARTISTS, LANGUAGE_FOR_REGION,
} = require('./lib/pahadi_artists');
const { slugify } = require('./lib/validator');

const PROJECT_ID = 'himraag-prod';
const repoRoot = path.dirname(__dirname);
const BUNDLE = path.join(repoRoot, 'assets', 'catalog', 'imported_catalog.json');
const BUNDLE_SEED = path.join(__dirname, 'seed_data', 'imported_catalog.json');

const COMMIT = process.argv.includes('--commit');
const lkIdx = process.argv.indexOf('--lookups');
const LOOKUPS = lkIdx > -1
  ? JSON.parse(fs.readFileSync(path.resolve(__dirname, process.argv[lkIdx + 1]), 'utf8')).results
  : {};

const UNRESOLVED_REGIONS = new Set(['Pahadi', 'Needs Review', '', null, undefined]);
const PLACEHOLDER_ARTISTS = new Set(['Unknown Artist', 'Pahadi Folk']);

function normalize(value) {
  return String(value || '').normalize('NFKD').replace(/[̀-ͯ]/g, '')
    .toLowerCase().replace(/[^a-z0-9ऀ-ॿ\s]/g, ' ').replace(/\s+/g, ' ').trim();
}
function searchTerms(...parts) {
  const set = new Set();
  for (const p of parts) {
    const n = normalize(p);
    if (!n) continue;
    set.add(n);
    for (const tok of n.split(' ')) if (tok.length > 1) set.add(tok);
  }
  return [...set];
}
const artistIdOf = (name) => `artist_${slugify(name).replace(/-/g, '_')}`;

// Per-artist region votes from lookup album/title texts ("New Garhwali Song
// 2022" etc.) — resolves keyword-less tracks by the same credited artist.
const artistVotes = new Map();
for (const lk of Object.values(LOOKUPS)) {
  if (!lk || !lk.artist) continue;
  const r = regionFromKeywords(`${lk.album || ''} ${lk.matchedTitle || ''}`);
  if (!r) continue;
  const k = lk.artist.toLowerCase();
  const v = artistVotes.get(k) || {};
  v[r] = (v[r] || 0) + 1;
  artistVotes.set(k, v);
}
const artistVotedRegion = new Map();
for (const [k, v] of artistVotes) {
  const sorted = Object.entries(v).sort((a, b) => b[1] - a[1]);
  if (sorted.length === 1 || sorted[0][1] > sorted[1][1]) artistVotedRegion.set(k, sorted[0][0]);
}

/** Region for a (possibly multi-credit) looked-up artist string. */
function lookupArtistRegion(artistStr) {
  const parts = String(artistStr || '').split(/\s*[,&]\s*|\s+and\s+/i);
  for (const p of parts) {
    const r = KNOWN_ARTISTS[p.trim().toLowerCase()];
    if (r) return r;
  }
  return artistVotedRegion.get(String(artistStr || '').toLowerCase()) || null;
}

/** Decide new {region, artist} for one song record. */
function decide(song) {
  const fn = song.sourceFile ? path.basename(song.sourceFile) : '';
  const out = {};

  // artist
  if (PLACEHOLDER_ARTISTS.has(song.artistName)) {
    const known = matchKnownArtist(fn);
    const extracted = known ? null : extractArtistName(fn);
    const lookup = LOOKUPS[song.id];
    const name = (known && known.name) || extracted || (lookup && lookup.artist) || null;
    if (name && name.length >= 3) out.artist = name;
  }

  // region
  if (UNRESOLVED_REGIONS.has(song.region)) {
    const kw = regionFromKeywords(fn) || regionFromKeywords(song.title);
    const known = matchKnownArtist(fn) ||
      (out.artist && KNOWN_ARTISTS[out.artist.toLowerCase()]
        ? { region: KNOWN_ARTISTS[out.artist.toLowerCase()] } : null) ||
      matchKnownArtist(song.artistName);
    const lookup = LOOKUPS[song.id];
    const lookupRegion = lookup &&
      (regionFromKeywords(`${lookup.album || ''} ${lookup.matchedTitle || ''}`) ||
        lookupArtistRegion(lookup.artist));
    const region = kw || (known && known.region) || lookupRegion || null;
    if (region) out.region = region;
  }
  return out;
}

async function main() {
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(firebaseServiceAccountPath(), 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();
  const snap = await db.collection('songs').get();
  const songs = [];
  snap.forEach((d) => songs.push({ id: d.id, ...d.data() }));

  const before = {};
  songs.forEach((s) => (before[s.region || '(none)'] = (before[s.region || '(none)'] || 0) + 1));

  const changes = [];
  const newArtists = new Map(); // artistId -> {name, region}
  for (const s of songs) {
    const d = decide(s);
    if (!d.region && !d.artist) continue;
    changes.push({ id: s.id, title: s.title, from: s.region, ...d });
    if (d.artist) {
      const aid = artistIdOf(d.artist);
      if (!newArtists.has(aid)) newArtists.set(aid, { name: d.artist, region: d.region || s.region });
    }
  }

  const after = {};
  const byId = new Map(changes.map((c) => [c.id, c]));
  songs.forEach((s) => {
    const c = byId.get(s.id);
    const r = (c && c.region) || s.region || '(none)';
    after[r] = (after[r] || 0) + 1;
  });

  console.log('BEFORE:', JSON.stringify(before));
  console.log('AFTER :', JSON.stringify(after));
  console.log(`changes: ${changes.length} (region: ${changes.filter((c) => c.region).length}, artist: ${changes.filter((c) => c.artist).length})`);
  console.log(`new artist docs: ${newArtists.size}`);
  changes.slice(0, 25).forEach((c) =>
    console.log(`  ${c.id}: region ${c.from}→${c.region || '='} artist→${c.artist || '='}`));

  if (!COMMIT) { console.log('\nDRY RUN — re-run with --commit to write.'); return; }

  // ── Firestore writes ───────────────────────────────────────────────────────
  let batch = db.batch(); let n = 0; let committed = 0;
  const flush = async () => { if (n > 0) { await batch.commit(); committed += n; batch = db.batch(); n = 0; } };

  const songById = new Map(songs.map((s) => [s.id, s]));
  for (const c of changes) {
    const s = songById.get(c.id);
    const upd = { updatedAt: FieldValue.serverTimestamp() };
    const region = c.region || s.region;
    if (c.region) {
      upd.region = c.region;
      if (UNRESOLVED_REGIONS.has(s.language) || !s.language) {
        upd.language = LANGUAGE_FOR_REGION[c.region] || s.language;
      }
      // resolved region clears the region review reason
    }
    if (c.artist) {
      upd.artistName = c.artist;
      upd.artistId = artistIdOf(c.artist);
    }
    upd.searchKeywords = searchTerms(
      s.title, c.artist || s.artistName, s.albumTitle, region,
      upd.language || s.language, s.genre);
    batch.update(db.collection('songs').doc(c.id), upd);
    if (++n >= 400) await flush();
  }
  await flush();

  // artist docs
  for (const [aid, a] of newArtists) {
    const ref = db.collection('artists').doc(aid);
    const cur = await ref.get();
    const count = changes.filter((c) => c.artist && artistIdOf(c.artist) === aid).length;
    if (!cur.exists) {
      await ref.set({
        id: aid, name: a.name, imageUrl: '',
        region: a.region && !UNRESOLVED_REGIONS.has(a.region) ? a.region : 'Pahadi',
        bio: `${a.name} — Pahadi folk artist.`,
        songCount: count, albumCount: 0, genres: ['Folk'],
        monthlyListeners: 0, isVerified: false, socialLinks: {},
        slug: slugify(a.name), approvalStatus: 'approved', isPublished: true,
        rightsNote: '',
      });
    } else {
      await ref.update({ songCount: FieldValue.increment(count) });
    }
  }
  console.log(`Firestore: ${committed} song updates, ${newArtists.size} artist upserts.`);

  // ── Bundled catalog mirrors ───────────────────────────────────────────────
  for (const file of [BUNDLE, BUNDLE_SEED]) {
    if (!fs.existsSync(file)) continue;
    const cat = JSON.parse(fs.readFileSync(file, 'utf8'));
    let touched = 0;
    const artistsById = new Map((cat.artists || []).map((a) => [a.id, a]));
    for (const s of cat.songs || []) {
      const c = byId.get(s.id);
      if (!c) continue;
      if (c.region) {
        s.region = c.region;
        if (UNRESOLVED_REGIONS.has(s.language) || !s.language) {
          s.language = LANGUAGE_FOR_REGION[c.region] || s.language;
        }
      }
      if (c.artist) {
        s.artistName = c.artist;
        s.artistId = artistIdOf(c.artist);
        if (!artistsById.has(s.artistId)) {
          const a = {
            id: s.artistId, name: c.artist, imageUrl: '',
            region: c.region || s.region, bio: `${c.artist} — Pahadi folk artist.`,
            songCount: 0, albumCount: 0, genres: ['Folk'], monthlyListeners: 0,
            isVerified: false, socialLinks: {}, slug: slugify(c.artist),
            approvalStatus: 'approved', isPublished: true, rightsNote: '',
          };
          (cat.artists = cat.artists || []).push(a);
          artistsById.set(s.artistId, a);
        }
      }
      touched++;
    }
    // recount artist songCounts from scratch (bundle is self-contained)
    const counts = {};
    (cat.songs || []).forEach((s) => (counts[s.artistId] = (counts[s.artistId] || 0) + 1));
    (cat.artists || []).forEach((a) => (a.songCount = counts[a.id] || 0));
    fs.writeFileSync(file, JSON.stringify(cat, null, 2));
    console.log(`${path.relative(repoRoot, file)}: ${touched} songs updated.`);
  }
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
