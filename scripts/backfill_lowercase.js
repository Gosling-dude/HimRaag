/**
 * Backfill artistNameLowercase / albumTitleLowercase on song docs (Phase 5
 * spec). titleLowercase + searchKeywords are written at import; these two are
 * added here for admin search/sort completeness. Idempotent: only writes when a
 * value is missing or differs. Additive (new fields only).
 *
 * Usage: node scripts/backfill_lowercase.js
 */
'use strict';
const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { PROJECT_ID } = require('./lib/constants');
const { firebaseServiceAccountPath } = require('./lib/credentials');

(async () => {
  const saPath =
    process.env.GOOGLE_APPLICATION_CREDENTIALS || firebaseServiceAccountPath();
  initializeApp({
    credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))),
    projectId: PROJECT_ID,
  });
  const db = getFirestore();
  const snap = await db.collection('songs').get();
  let batch = db.batch();
  let n = 0;
  let pending = 0;
  snap.forEach((doc) => {
    const s = doc.data();
    const wantArtist = (s.artistName || '').toLowerCase();
    const wantAlbum = (s.albumTitle || '').toLowerCase();
    const patch = {};
    if (s.artistNameLowercase !== wantArtist)
      patch.artistNameLowercase = wantArtist;
    if (s.albumTitleLowercase !== wantAlbum)
      patch.albumTitleLowercase = wantAlbum;
    if (Object.keys(patch).length) {
      batch.update(doc.ref, patch);
      n++;
      if (++pending % 400 === 0) {
        batch.commit();
        batch = db.batch();
      }
    }
  });
  if (pending % 400 !== 0) await batch.commit();
  console.log(`Backfilled lowercase fields on ${n}/${snap.size} song docs.`);
  process.exit(0);
})().catch((e) => {
  console.error('ERR', e.message);
  process.exit(1);
});
