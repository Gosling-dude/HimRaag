/**
 * Real artist photographs for every artist missing an image.
 *
 * Source priority (genuine photographs only — never AI faces/illustrations):
 *   1. Wikipedia lead image (accepted only when the page describes a
 *      singer/musician — rejects same-name non-musicians)
 *   2. JioSaavn artist portrait (exact normalized-name match only)
 *   3. none → imageUrl stays '' and the app renders its clean initials avatar
 *      (the approved neutral placeholder).
 *
 * Photos are re-hosted on R2 (artist/<slug>-v5.<ext>), then imageUrl is
 * updated in Firestore AND both bundled catalog JSONs. Emits
 * ARTIST_IMAGE_AUDIT.md. Idempotent — only touches artists without an image
 * unless --all is passed.
 *
 * Usage: node scripts/fetch_artist_images.js [--dry-run] [--all]
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { loadR2, firebaseServiceAccountPath } = require('./lib/credentials');
const { slugify } = require('./lib/validator');
const {
  downloadImage, findArtistImage, findWikipediaImage,
} = require('./lib/artwork_sources');

const PROJECT_ID = 'himraag-prod';
const VER = 'v5';
const repoRoot = path.dirname(__dirname);
const BUNDLES = [
  path.join(repoRoot, 'assets', 'catalog', 'imported_catalog.json'),
  path.join(__dirname, 'seed_data', 'imported_catalog.json'),
];
const DRY = process.argv.includes('--dry-run');
const ALL = process.argv.includes('--all');
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function main() {
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(firebaseServiceAccountPath(), 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();
  const cfg = loadR2();
  const s3 = new S3Client({
    region: 'auto', endpoint: cfg.endpoint,
    credentials: { accessKeyId: cfg.accessKeyId, secretAccessKey: cfg.secretAccessKey },
  });

  const snap = await db.collection('artists').get();
  const artists = [];
  snap.forEach((d) => artists.push({ id: d.id, ...d.data() }));
  const targets = artists.filter((a) => ALL || !/^https?:/.test(a.imageUrl || ''));
  console.log(`artists: ${artists.length}, needing image: ${targets.length}`);

  const rows = [];
  for (const a of targets) {
    let found = null;
    try {
      found = await findWikipediaImage(a.name);
      await sleep(400);
      if (!found) {
        found = await findArtistImage(a.name);
        await sleep(400);
      }
    } catch (e) { console.log(`  ! lookup failed for ${a.name}: ${e.message}`); }

    if (!found) {
      rows.push({ name: a.name, id: a.id, source: 'placeholder (initials avatar)', url: '' });
      console.log(`  – ${a.name}: no real photo found → neutral placeholder`);
      continue;
    }
    let img = await downloadImage(found.url);
    for (const alt of found.fallbacks || []) {
      if (img && img.buf.length >= 2048) break;
      img = await downloadImage(alt);
    }
    if (!img || img.buf.length < 2048) {
      rows.push({ name: a.name, id: a.id, source: 'placeholder (download failed)', url: '' });
      continue;
    }
    const ext = /png/i.test(img.contentType || '') ? 'png' : 'jpg';
    const key = `artist/${slugify(a.name)}-${VER}.${ext}`;
    const publicUrl = `${cfg.publicUrl}/${key}`;
    if (!DRY) {
      await s3.send(new PutObjectCommand({
        Bucket: cfg.bucket, Key: key, Body: img.buf,
        ContentType: img.contentType || 'image/jpeg',
      }));
      await db.collection('artists').doc(a.id).update({ imageUrl: publicUrl });
    }
    rows.push({ name: a.name, id: a.id, source: found.source, url: publicUrl });
    console.log(`  ✓ ${a.name}: ${found.source}`);
  }

  // bundled catalogs
  if (!DRY) {
    const byId = new Map(rows.filter((r) => r.url).map((r) => [r.id, r.url]));
    for (const file of BUNDLES) {
      if (!fs.existsSync(file)) continue;
      const cat = JSON.parse(fs.readFileSync(file, 'utf8'));
      let touched = 0;
      for (const a of cat.artists || []) {
        if (byId.has(a.id)) { a.imageUrl = byId.get(a.id); touched++; }
      }
      fs.writeFileSync(file, JSON.stringify(cat, null, 2));
      console.log(`${path.relative(repoRoot, file)}: ${touched} artist images updated`);
    }
  }

  // report
  const withImg = artists.filter((a) => /^https?:/.test(a.imageUrl || '')).length +
    rows.filter((r) => r.url).length;
  let md = `# ARTIST IMAGE AUDIT\n\n_Generated: ${new Date().toISOString()}_\n\n`;
  md += `Policy: real photographs only (Wikipedia lead image verified as a musician's page, `;
  md += `or JioSaavn portrait with exact name match). No AI faces, no illustrations, no text `;
  md += `cards. Artists without a genuine public photo keep a clean initials avatar.\n\n`;
  md += `| Artist | Result | Hosted URL |\n|---|---|---|\n`;
  rows.forEach((r) => (md += `| ${r.name} | ${r.source} | ${r.url ? r.url : '— (initials avatar)'} |\n`));
  md += `\n**Coverage:** ${withImg}/${artists.length} artists have a hosted real photo; `;
  md += `the remainder use the app's neutral avatar.\n`;
  fs.writeFileSync(path.join(repoRoot, 'ARTIST_IMAGE_AUDIT.md'), md);
  console.log(`done: ${rows.filter((r) => r.url).length}/${rows.length} real photos; report → ARTIST_IMAGE_AUDIT.md`);
}

main().then(() => process.exit(0)).catch((e) => { console.error(e); process.exit(1); });
