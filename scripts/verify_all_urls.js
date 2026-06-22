/**
 * Phase 9 — verify every consumer-facing R2 URL returns HTTP 200/206.
 * Checks song audioUrl + artworkUrl, artist imageUrl, album artworkUrl from
 * live Firestore. Writes UI_VERIFICATION_REPORT.md. Read-only.
 */
'use strict';
const fs = require('fs');
const path = require('path');
const https = require('https');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { PROJECT_ID } = require('./lib/constants');
const { firebaseServiceAccountPath } = require('./lib/credentials');

function head(url) {
  return new Promise((resolve) => {
    if (!url || !/^https?:\/\//.test(url)) return resolve({ url, ok: false, status: 'no-url' });
    const req = https.get(url, { headers: { Range: 'bytes=0-0' } }, (res) => {
      res.resume();
      resolve({ url, ok: res.statusCode === 200 || res.statusCode === 206, status: res.statusCode, type: res.headers['content-type'] });
    });
    req.on('error', () => resolve({ url, ok: false, status: 'error' }));
    req.setTimeout(20000, () => { req.destroy(); resolve({ url, ok: false, status: 'timeout' }); });
  });
}
async function pool(items, fn, n = 8) {
  const out = []; let i = 0;
  await Promise.all(Array.from({ length: n }, async () => {
    while (i < items.length) { const idx = i++; out[idx] = await fn(items[idx]); }
  }));
  return out;
}

async function main() {
  const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || firebaseServiceAccountPath();
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();

  const checks = [];
  (await db.collection('songs').get()).forEach((d) => {
    const s = d.data();
    checks.push({ kind: 'song-audio', name: s.title, url: s.audioUrl });
    checks.push({ kind: 'song-art', name: s.title, url: s.artworkUrl });
  });
  (await db.collection('artists').get()).forEach((d) => checks.push({ kind: 'artist-img', name: d.data().name, url: d.data().imageUrl }));
  (await db.collection('albums').get()).forEach((d) => checks.push({ kind: 'album-art', name: d.data().title, url: d.data().artworkUrl }));

  const results = await pool(checks, async (c) => ({ ...c, ...(await head(c.url)) }));
  const byKind = {};
  for (const r of results) {
    byKind[r.kind] ??= { ok: 0, total: 0 };
    byKind[r.kind].total++;
    if (r.ok) byKind[r.kind].ok++;
  }
  const fails = results.filter((r) => !r.ok);

  let md = `# HimRaag — UI / Asset Verification Report (Phase 9)\n\n_Generated: ${new Date().toISOString()}_\n\n`;
  md += `All consumer-facing Cloudflare R2 URLs probed (HTTP Range GET).\n\n## Summary\n\n| Asset type | Reachable (200/206) |\n|---|---|\n`;
  for (const [k, v] of Object.entries(byKind)) md += `| ${k} | ${v.ok}/${v.total} |\n`;
  md += `| **Total** | **${results.filter((r) => r.ok).length}/${results.length}** |\n\n`;
  if (fails.length) {
    md += `## Failures\n\n| Type | Name | Status | URL |\n|---|---|---|---|\n`;
    for (const f of fails) md += `| ${f.kind} | ${f.name} | ${f.status} | ${f.url || ''} |\n`;
  } else {
    md += `## Failures\n\nNone — every URL returned 200/206. ✅\n`;
  }
  fs.writeFileSync(path.join(__dirname, '..', 'UI_VERIFICATION_REPORT.md'), md);

  console.log(`Checked ${results.length} URLs; reachable ${results.filter((r) => r.ok).length}; failures ${fails.length}`);
  for (const [k, v] of Object.entries(byKind)) console.log(`  ${k}: ${v.ok}/${v.total}`);
  if (fails.length) { fails.slice(0, 10).forEach((f) => console.log(`  FAIL ${f.kind} ${f.name} ${f.status}`)); process.exitCode = 2; }
}
main().then(() => process.exit(process.exitCode || 0)).catch((e) => { console.error(e); process.exit(1); });
