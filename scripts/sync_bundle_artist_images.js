/**
 * Sync artist imageUrl from Firestore into the bundled catalog.
 *
 * The app merges local-first, so a bundle artist with an empty imageUrl hides
 * the real photo that exists in Firestore (this is how the featured artists
 * ended up as initials avatars). Copies verified Firestore imageUrls into
 * both bundle JSONs. Never overwrites a non-empty bundle URL, never
 * regenerates anything.
 *
 * Usage: node scripts/sync_bundle_artist_images.js
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

(async () => {
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(firebaseServiceAccountPath(), 'utf8'))), projectId: 'himraag-prod' });
  const db = getFirestore();
  const fire = new Map();
  (await db.collection('artists').get()).forEach((d) => {
    const a = d.data();
    if (/^https?:/.test(a.imageUrl || '')) fire.set(d.id, a.imageUrl);
  });

  for (const file of BUNDLES) {
    if (!fs.existsSync(file)) continue;
    const cat = JSON.parse(fs.readFileSync(file, 'utf8'));
    let synced = 0;
    for (const a of cat.artists || []) {
      if (!/^https?:/.test(a.imageUrl || '') && fire.has(a.id)) {
        a.imageUrl = fire.get(a.id);
        synced++;
        console.log(`  + ${a.name} ← ${a.imageUrl.slice(-50)}`);
      }
    }
    fs.writeFileSync(file, JSON.stringify(cat, null, 2));
    console.log(`${path.relative(repoRoot, file)}: ${synced} artist images synced`);
  }
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
