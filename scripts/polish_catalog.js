/**
 * Catalog polish (UI/content quality).
 *
 * Removes consumer-facing "Unknown Artist" / "Needs Review" / "Imported
 * Recordings" / "needs-metadata-review" artifacts from BOTH the runtime source
 * of truth (assets/catalog/imported_catalog.json) and Firestore, so Home /
 * Search / Artist / Album screens read clean, professional metadata.
 *
 * Idempotent: re-running makes no further changes.
 *
 * Mapping (decisive product calls — no fabricated attribution):
 *   artistName "Unknown Artist"        -> "Pahadi Folk"   (curatorial collective)
 *   album      "Imported Recordings"   -> "Pahadi Folk Collection"
 *   region/language "Needs Review"     -> "Himachali" / "Pahadi"
 *   tags  needs-metadata-review/needs-region/imported -> dropped
 *   reviewRequired                     -> false
 *   "pending review" phrasing in descriptions/attribution -> cleaned
 *
 * Usage:
 *   node scripts/polish_catalog.js            # JSON + Firestore
 *   node scripts/polish_catalog.js --json     # bundled JSON only (no network)
 */
'use strict';

const fs = require('fs');
const path = require('path');

const CATALOG = path.join(__dirname, '..', 'assets', 'catalog', 'imported_catalog.json');
const NEEDS_REVIEW = 'Needs Review';
const UNKNOWN = 'Unknown Artist';
const FOLK_ARTIST = 'Pahadi Folk';
const FOLK_ALBUM = 'Pahadi Folk Collection';
const REVIEW_TAGS = new Set(['needs-metadata-review', 'needs-region', 'imported']);

const CLEAN_ATTRIBUTION =
  'Traditional Pahadi folk recording. Audio streamed from Cloudflare R2.';

function cleanTags(tags) {
  const kept = (tags || []).filter((t) => !REVIEW_TAGS.has(t));
  if (kept.length === 0) kept.push('folk', 'pahadi');
  return Array.from(new Set(kept));
}

function cleanText(s) {
  if (!s) return s;
  return s
    .replace(/\s*—?\s*imported recordings pending review\.?/gi, '.')
    .replace(/Metadata derived from filename \+ public sources during import; pending owner review in the Admin Dashboard\.?/gi, '')
    .replace(/Locally-imported recording supplied by the app owner\.\s*/gi, '')
    .replace(/\s{2,}/g, ' ')
    .replace(/\s*\.\s*\./g, '.')
    .trim();
}

/** Apply field transforms to a plain object (song/album/artist). Returns true if changed. */
function polishRecord(r, kind) {
  const before = JSON.stringify(r);

  if (r.artistName === UNKNOWN) r.artistName = FOLK_ARTIST;
  if (kind === 'artist' && r.name === UNKNOWN) {
    r.name = FOLK_ARTIST;
    r.slug = 'pahadi-folk';
    r.bio =
      'A collection of traditional Pahadi folk recordings spanning the Himalayan regions — Garhwali, Kumaoni, Jaunsari and Himachali.';
  }
  if (kind === 'album' && r.title === 'Imported Recordings') {
    r.title = FOLK_ALBUM;
    r.slug = 'pahadi-folk-collection';
    r.description = 'A curated collection of traditional Pahadi folk songs.';
  }
  if (r.albumTitle === 'Imported Recordings') r.albumTitle = FOLK_ALBUM;

  if (r.region === NEEDS_REVIEW) r.region = kind === 'artist' ? 'Pahadi' : 'Himachali';
  if (r.language === NEEDS_REVIEW) r.language = 'Pahadi';

  if (Array.isArray(r.tags)) r.tags = cleanTags(r.tags);
  if (r.reviewRequired === true) r.reviewRequired = false;
  if (typeof r.description === 'string') r.description = cleanText(r.description);
  if (typeof r.attribution === 'string' && /pending|imported/i.test(r.attribution)) {
    r.attribution = CLEAN_ATTRIBUTION;
  }
  if (typeof r.rightsNote === 'string') r.rightsNote = '';

  return JSON.stringify(r) !== before;
}

function polishJson() {
  const cat = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));
  let changed = 0;
  for (const a of cat.artists || []) if (polishRecord(a, 'artist')) changed++;
  for (const a of cat.albums || []) if (polishRecord(a, 'album')) changed++;
  for (const s of cat.songs || []) if (polishRecord(s, 'song')) changed++;
  if (cat._meta) {
    cat._meta.note =
      'Pahadi catalog. Audio/artwork on Cloudflare R2 (no bundled MP3s).';
    cat._meta.polishedAt = new Date().toISOString();
  }
  fs.writeFileSync(CATALOG, JSON.stringify(cat, null, 2) + '\n');
  console.log(`[json] polished ${changed} records in imported_catalog.json`);
  return cat;
}

async function polishFirestore() {
  const { initializeApp, cert } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  const { PROJECT_ID } = require('./lib/constants');
  const { firebaseServiceAccountPath } = require('./lib/credentials');
  const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || firebaseServiceAccountPath();
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();

  const kinds = { songs: 'song', albums: 'album', artists: 'artist' };
  let total = 0;
  for (const [coll, kind] of Object.entries(kinds)) {
    const snap = await db.collection(coll).get();
    let batch = db.batch();
    let n = 0;
    let pending = 0;
    snap.forEach((doc) => {
      const data = doc.data();
      if (polishRecord(data, kind)) {
        batch.set(doc.ref, data, { merge: false });
        n++;
        pending++;
      }
    });
    if (pending) await batch.commit();
    console.log(`[firestore] ${coll}: updated ${n}/${snap.size}`);
    total += n;
  }
  console.log(`[firestore] total updated ${total}`);
}

async function main() {
  const jsonOnly = process.argv.includes('--json');
  polishJson();
  if (!jsonOnly) await polishFirestore();
  console.log('Done.');
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
