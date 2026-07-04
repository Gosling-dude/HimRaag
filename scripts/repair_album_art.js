/**
 * Repair album artworkUrl: replace import-time placeholder PNGs with the
 * album's representative REAL song cover (most-played published song whose
 * artwork is a -vN real cover). No regeneration — reuses existing R2 assets.
 * Applies to Firestore + both bundle JSONs. Idempotent.
 *
 * Usage: node scripts/repair_album_art.js [--dry-run]
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { firebaseServiceAccountPath } = require('./lib/credentials');

const repoRoot = path.dirname(__dirname);
const BUNDLES = [
  path.join(repoRoot, 'assets', 'catalog', 'imported_catalog.json'),
  path.join(__dirname, 'seed_data', 'imported_catalog.json'),
];
const DRY = process.argv.includes('--dry-run');
const isRealCover = (u) => /r2\.dev\/artwork\/.+-v\d+\.(jpg|jpeg|png|webp)$/i.test(u || '');

(async () => {
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(firebaseServiceAccountPath(), 'utf8'))), projectId: 'himraag-prod' });
  const db = getFirestore();

  const songsSnap = await db.collection('songs').get();
  const coverByAlbum = new Map();
  songsSnap.forEach((d) => {
    const s = d.data();
    if (!s.albumId || !isRealCover(s.artworkUrl)) return;
    const cur = coverByAlbum.get(s.albumId);
    const score = (s.isPublished ? 1e9 : 0) + (s.playCount || 0);
    if (!cur || score > cur.score) coverByAlbum.set(s.albumId, { url: s.artworkUrl, score });
  });

  const snap = await db.collection('albums').get();
  const changes = new Map();
  snap.forEach((d) => {
    const a = d.data();
    if (!isRealCover(a.artworkUrl) && coverByAlbum.has(d.id)) {
      changes.set(d.id, coverByAlbum.get(d.id).url);
    }
  });
  console.log(`albums to repair: ${changes.size} / ${snap.size}`);
  if (DRY) { process.exit(0); }

  let batch = db.batch(); let n = 0;
  for (const [id, url] of changes) {
    batch.update(db.collection('albums').doc(id), { artworkUrl: url });
    if (++n >= 400) { await batch.commit(); batch = db.batch(); n = 0; }
  }
  if (n) await batch.commit();
  console.log(`Firestore updated: ${changes.size}`);

  for (const file of BUNDLES) {
    if (!fs.existsSync(file)) continue;
    const cat = JSON.parse(fs.readFileSync(file, 'utf8'));
    let touched = 0;
    for (const a of cat.albums || []) {
      if (changes.has(a.id)) { a.artworkUrl = changes.get(a.id); touched++; }
    }
    fs.writeFileSync(file, JSON.stringify(cat, null, 2));
    console.log(`${path.relative(repoRoot, file)}: ${touched} updated`);
  }
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
