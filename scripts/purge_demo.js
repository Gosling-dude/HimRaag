/**
 * Purge legacy DEMO/test/instrumental tracks from Firestore.
 *
 * The bundled catalog (assets/catalog/imported_catalog.json) is 100% LICENSED and
 * contains no demo content. The old "instrumental testing tracks" live only in
 * Firestore — seeded by generate_demo_catalog.js as license='DEMO_ONLY',
 * approvalStatus='demo', isPublished=false (placeholder picsum art, demo
 * ensembles). They are filtered from release builds, but this script removes them
 * outright so they can never surface in any build.
 *
 * Targets ONLY docs that are unambiguously demo/test:
 *   license == 'DEMO_ONLY'  OR  approvalStatus == 'demo'  OR  isDemo == true
 * Real LICENSED catalog songs are never touched.
 *
 * Usage:
 *   node scripts/purge_demo.js            # dry-run (counts only)
 *   node scripts/purge_demo.js --commit   # delete
 */
'use strict';

const fs = require('fs');
const { firebaseServiceAccountPath } = require('./lib/credentials');

const PROJECT_ID = 'himraag-prod';
const COMMIT = process.argv.includes('--commit');
const COLLECTIONS = ['songs', 'albums', 'artists'];

function isDemo(d) {
  return d.license === 'DEMO_ONLY' || d.approvalStatus === 'demo' || d.isDemo === true;
}

async function main() {
  const { initializeApp, cert } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  const saPath = firebaseServiceAccountPath();
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();

  const summary = {};
  for (const col of COLLECTIONS) {
    const snap = await db.collection(col).get();
    const demo = snap.docs.filter((doc) => isDemo(doc.data()));
    summary[col] = { total: snap.size, demo: demo.length };
    console.log(`${col}: ${snap.size} docs, ${demo.length} demo/test`);
    for (const doc of demo) {
      const d = doc.data();
      console.log(`   ${COMMIT ? 'DELETE' : 'would delete'} ${col}/${doc.id}  "${d.title || d.name || ''}" [${d.license}/${d.approvalStatus}]`);
      if (COMMIT) await doc.ref.delete();
    }
  }

  console.log('\nSummary:', JSON.stringify(summary));
  console.log(COMMIT ? '✅ Demo/test docs deleted.' : 'ℹ️  Dry-run. Re-run with --commit to delete.');
}

main().catch((e) => { console.error('purge_demo failed:', e.message); process.exit(1); });
