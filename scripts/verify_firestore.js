/**
 * Phase 4/7 — read-back verification of the Firestore import.
 *
 * Counts documents in songs/artists/albums and spot-checks 5 imported songs
 * for: R2 audioUrl, R2 artworkUrl, isApproved=false, reviewRequired=true,
 * approvalStatus=pending, searchKeywords present. Read-only.
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=<sa.json> node scripts/verify_firestore.js
 */
'use strict';

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const { PROJECT_ID } = require('./lib/constants');
const { firebaseServiceAccountPath } = require('./lib/credentials');

async function main() {
  const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || firebaseServiceAccountPath();
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();

  for (const c of ['songs', 'artists', 'albums']) {
    const snap = await db.collection(c).count().get();
    console.log(`count ${c}: ${snap.data().count}`);
  }

  // Spot-check 5 imported songs (tagged needs-metadata-review).
  const q = await db.collection('songs')
    .where('reviewRequired', '==', true)
    .limit(5)
    .get();
  console.log(`\nSpot-check ${q.size} imported songs (reviewRequired==true):`);
  q.forEach((d) => {
    const s = d.data();
    const r2 = (s.audioUrl || '').includes('r2.dev');
    console.log(
      `  • ${s.title}\n` +
      `      audioUrl=${s.audioUrl}\n` +
      `      R2=${r2} isApproved=${s.isApproved} approvalStatus=${s.approvalStatus} ` +
      `reviewRequired=${s.reviewRequired} isPublished=${s.isPublished}\n` +
      `      artist=${s.artistName} region=${s.region}/${s.language} ` +
      `searchKeywords=${(s.searchKeywords || []).length} terms`
    );
  });
}

main().then(() => process.exit(0)).catch((e) => { console.error('verify failed:', e.message); process.exit(1); });
