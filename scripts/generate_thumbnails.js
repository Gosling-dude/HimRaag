/**
 * List/grid thumbnails for heavy covers (P0.5).
 *
 * For every unique real song cover (-vN object) larger than 150 KB, generate a
 * 400 px (longest edge) JPEG q80 thumbnail and upload it as `<key>-t400.jpg`.
 * Originals are untouched (detail screens keep full resolution). All object
 * traffic uses the S3 API — the rate-limited public r2.dev URL is never hit.
 *
 * Then set `thumbnailUrl` on every Firestore song + bundle song:
 *   - the -t400 URL when one was generated
 *   - '' otherwise (the app falls back to artworkUrl, already ≤ ~150 KB)
 *
 * Idempotent: skips thumbs that already exist. Usage:
 *   node scripts/generate_thumbnails.js
 */
'use strict';
const fs = require('fs');
const path = require('path');
const sharp = require('sharp');
const { GetObjectCommand, HeadObjectCommand, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { createR2Client, putObject } = require('./lib/r2_client');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { loadR2, firebaseServiceAccountPath } = require('./lib/credentials');

const repoRoot = path.dirname(__dirname);
const BUNDLES = [
  path.join(repoRoot, 'assets', 'catalog', 'imported_catalog.json'),
  path.join(__dirname, 'seed_data', 'imported_catalog.json'),
];
// 0 = thumbnail every real cover: the app swaps list/grid URLs to -t400 by
// convention, so every cover needs a thumb variant (originals untouched).
const SIZE_THRESHOLD = 0;
const THUMB_EDGE = 400;

const streamToBuffer = (stream) => new Promise((res, rej) => {
  const chunks = [];
  stream.on('data', (c) => chunks.push(c));
  stream.on('end', () => res(Buffer.concat(chunks)));
  stream.on('error', rej);
});

(async () => {
  const cfg = loadR2();
  const s3 = createR2Client(cfg);

  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(firebaseServiceAccountPath(), 'utf8'))), projectId: 'himraag-prod' });
  const db = getFirestore();

  // 1. sizes of all artwork objects (one list pass — no public URL traffic)
  const sizeByKey = new Map();
  let token;
  do {
    const res = await s3.send(new ListObjectsV2Command({ Bucket: cfg.bucket, Prefix: 'artwork/', ContinuationToken: token }));
    for (const o of res.Contents || []) sizeByKey.set(o.Key, o.Size);
    token = res.IsTruncated ? res.NextContinuationToken : undefined;
  } while (token);
  console.log(`artwork objects listed: ${sizeByKey.size}`);

  // 2. unique real covers referenced by songs
  const songsSnap = await db.collection('songs').get();
  const urlPrefix = `${cfg.publicUrl}/`;
  const keyFor = (u) => (u || '').startsWith(urlPrefix) ? u.slice(urlPrefix.length) : null;
  const wanted = new Map(); // originalKey -> thumbKey
  songsSnap.forEach((d) => {
    const key = keyFor(d.data().artworkUrl);
    if (!key || !/-v\d+\.(jpg|jpeg|png|webp)$/i.test(key)) return;
    if ((sizeByKey.get(key) || 0) > SIZE_THRESHOLD) {
      wanted.set(key, key.replace(/\.(jpg|jpeg|png|webp)$/i, '-t400.jpg'));
    }
  });
  console.log(`covers needing a thumbnail (> ${SIZE_THRESHOLD / 1024} KB): ${wanted.size}`);

  // 3. generate missing thumbs
  let made = 0, skipped = 0, failed = 0;
  for (const [key, thumbKey] of wanted) {
    if (sizeByKey.has(thumbKey)) { skipped++; continue; }
    try {
      const obj = await s3.send(new GetObjectCommand({ Bucket: cfg.bucket, Key: key }));
      const buf = await streamToBuffer(obj.Body);
      const out = await sharp(buf)
        .resize(THUMB_EDGE, THUMB_EDGE, { fit: 'inside', withoutEnlargement: true })
        .jpeg({ quality: 80, mozjpeg: true })
        .toBuffer();
      await putObject(s3, cfg.bucket, thumbKey, out, 'image/jpeg');
      made++;
      if (made % 50 === 0) console.log(`  … ${made}/${wanted.size}`);
    } catch (e) {
      failed++;
      console.log(`  ! ${key}: ${e.message}`);
    }
  }
  console.log(`thumbnails: made=${made} existing=${skipped} failed=${failed}`);

  // 4. write thumbnailUrl on songs (Firestore + bundles)
  const thumbUrlFor = (u) => {
    const key = keyFor(u);
    const t = key && wanted.get(key);
    return t ? `${urlPrefix}${t}` : '';
  };

  let batch = db.batch(); let n = 0; let updated = 0;
  for (const d of songsSnap.docs) {
    const s = d.data();
    const t = thumbUrlFor(s.artworkUrl);
    if ((s.thumbnailUrl || '') !== t) {
      batch.update(d.ref, { thumbnailUrl: t });
      updated++;
      if (++n >= 400) { await batch.commit(); batch = db.batch(); n = 0; }
    }
  }
  if (n) await batch.commit();
  console.log(`Firestore songs updated with thumbnailUrl: ${updated}`);

  for (const file of BUNDLES) {
    if (!fs.existsSync(file)) continue;
    const cat = JSON.parse(fs.readFileSync(file, 'utf8'));
    let touched = 0;
    for (const s of cat.songs || []) {
      const t = thumbUrlFor(s.artworkUrl);
      if ((s.thumbnailUrl || '') !== t) { s.thumbnailUrl = t; touched++; }
    }
    fs.writeFileSync(file, JSON.stringify(cat, null, 2));
    console.log(`${path.relative(repoRoot, file)}: ${touched} songs updated`);
  }
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
