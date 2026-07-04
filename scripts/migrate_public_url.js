/**
 * One-shot migration of every public R2 URL to a new base (run this after
 * attaching a custom domain to the bucket in the Cloudflare dashboard:
 * R2 → himraag-audio → Settings → Custom Domains).
 *
 * The rate-limited pub-*.r2.dev development URL is the root cause of the
 * artwork-loading failures under burst load; a custom domain has no such
 * limit and gets real CDN caching.
 *
 * Rewrites audioUrl / artworkUrl / thumbnailUrl / imageUrl in Firestore
 * (songs, albums, artists) and both bundle JSONs, then updates the Public URL
 * line in the .env credential file so future scripts emit the new base.
 *
 * Usage:
 *   node scripts/migrate_public_url.js --to https://cdn.yourdomain.com [--dry-run]
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { loadR2, firebaseServiceAccountPath, envDir } = require('./lib/credentials');

const repoRoot = path.dirname(__dirname);
const BUNDLES = [
  path.join(repoRoot, 'assets', 'catalog', 'imported_catalog.json'),
  path.join(__dirname, 'seed_data', 'imported_catalog.json'),
];
const toIdx = process.argv.indexOf('--to');
const NEW_BASE = toIdx > -1 ? String(process.argv[toIdx + 1] || '').replace(/\/+$/, '') : null;
const DRY = process.argv.includes('--dry-run');
if (!NEW_BASE || !/^https:\/\//.test(NEW_BASE)) {
  console.error('Usage: node scripts/migrate_public_url.js --to https://<custom-domain> [--dry-run]');
  process.exit(1);
}

(async () => {
  const OLD_BASE = loadR2().publicUrl.replace(/\/+$/, '');
  if (OLD_BASE === NEW_BASE) { console.log('Base unchanged — nothing to do.'); process.exit(0); }
  const swap = (u) => (typeof u === 'string' && u.startsWith(OLD_BASE)) ? NEW_BASE + u.slice(OLD_BASE.length) : u;
  console.log(`migrating ${OLD_BASE} → ${NEW_BASE}${DRY ? ' (dry-run)' : ''}`);

  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(firebaseServiceAccountPath(), 'utf8'))), projectId: 'himraag-prod' });
  const db = getFirestore();
  const FIELDS = ['audioUrl', 'artworkUrl', 'thumbnailUrl', 'imageUrl'];

  for (const coll of ['songs', 'albums', 'artists']) {
    const snap = await db.collection(coll).get();
    let batch = db.batch(); let n = 0; let changed = 0;
    for (const d of snap.docs) {
      const data = d.data();
      const upd = {};
      for (const f of FIELDS) {
        const next = swap(data[f]);
        if (next !== data[f]) upd[f] = next;
      }
      if (Object.keys(upd).length) {
        changed++;
        if (!DRY) {
          batch.update(d.ref, upd);
          if (++n >= 400) { await batch.commit(); batch = db.batch(); n = 0; }
        }
      }
    }
    if (!DRY && n) await batch.commit();
    console.log(`  ${coll}: ${changed} docs updated`);
  }

  for (const file of BUNDLES) {
    if (!fs.existsSync(file)) continue;
    const raw = fs.readFileSync(file, 'utf8');
    const next = raw.split(OLD_BASE).join(NEW_BASE);
    const count = raw.split(OLD_BASE).length - 1;
    if (!DRY) fs.writeFileSync(file, next);
    console.log(`  ${path.relative(repoRoot, file)}: ${count} URL(s) rewritten`);
  }

  // Update the credential file's Public URL so future pipeline runs use it.
  if (!DRY) {
    const dir = envDir();
    const credFile = fs.readdirSync(dir).find((f) => /cloud|r2|credential/i.test(f) && f.endsWith('.txt'));
    if (credFile) {
      const p = path.join(dir, credFile);
      const txt = fs.readFileSync(p, 'utf8');
      fs.writeFileSync(p, txt.replace(/^(\s*Public URL\s*[:=]\s*).+$/mi, `$1${NEW_BASE}`));
      console.log(`  ${credFile}: Public URL updated`);
    }
  }
  console.log('done — rebuild the app so the bundled catalog ships the new URLs.');
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
