/**
 * Repair artist imageUrls (no regeneration — restores existing assets).
 *
 * Damage being fixed: the July import derived artist docs with
 * `imageUrl = song.artworkUrl` and its batch writes clobbered pre-existing
 * artist docs — replacing real hosted portraits (artist/<slug>-v5.*) with the
 * import-time generated placeholder PNGs (artwork/<file>-0.png, ~2 KB).
 *
 * Policy per artist (best real asset that already exists):
 *   1. real portrait  — artist/<slug>-v5.* object on R2
 *   2. real cover     — the artist's most popular published song's -vN artwork
 *   3. ''             — app renders the clean initials avatar
 * Generated placeholder PNGs (artwork/*.png without -vN) are never kept.
 *
 * Applies to Firestore AND both bundle JSONs. Idempotent.
 * Usage: node scripts/repair_artist_images.js [--dry-run]
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { S3Client, ListObjectsV2Command } = require('@aws-sdk/client-s3');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { loadR2, firebaseServiceAccountPath } = require('./lib/credentials');
const { slugify } = require('./lib/validator');

const repoRoot = path.dirname(__dirname);
const BUNDLES = [
  path.join(repoRoot, 'assets', 'catalog', 'imported_catalog.json'),
  path.join(__dirname, 'seed_data', 'imported_catalog.json'),
];
const DRY = process.argv.includes('--dry-run');

const isRealCover = (u) => /r2\.dev\/artwork\/.+-v\d+\.(jpg|jpeg|png|webp)$/i.test(u || '');
const isPortrait = (u) => /r2\.dev\/artists?\//i.test(u || '');
const isPlaceholderPng = (u) =>
  /r2\.dev\/artwork\//i.test(u || '') && !isRealCover(u);

(async () => {
  const cfg = loadR2();
  const s3 = new S3Client({
    region: 'auto', endpoint: cfg.endpoint,
    credentials: { accessKeyId: cfg.accessKeyId, secretAccessKey: cfg.secretAccessKey },
  });
  // All portrait objects under artist/ and artists/ prefixes.
  const portraits = new Map(); // slug -> key
  for (const prefix of ['artist/', 'artists/']) {
    let token;
    do {
      const res = await s3.send(new ListObjectsV2Command({
        Bucket: cfg.bucket, Prefix: prefix, ContinuationToken: token,
      }));
      for (const o of res.Contents || []) {
        const m = o.Key.match(/^artists?\/(.+)-v\d+\.(jpg|jpeg|png|webp)$/i);
        if (m && o.Size > 2048) portraits.set(m[1], o.Key);
      }
      token = res.IsTruncated ? res.NextContinuationToken : undefined;
    } while (token);
  }
  console.log(`portrait objects on R2: ${portraits.size}`);

  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(firebaseServiceAccountPath(), 'utf8'))), projectId: 'himraag-prod' });
  const db = getFirestore();

  // Best real cover per artist: most-played published song with -vN artwork.
  const songsSnap = await db.collection('songs').get();
  const coverByArtist = new Map();
  songsSnap.forEach((d) => {
    const s = d.data();
    if (!s.artistId || !isRealCover(s.artworkUrl)) return;
    const cur = coverByArtist.get(s.artistId);
    const score = (s.isPublished ? 1e9 : 0) + (s.playCount || 0);
    if (!cur || score > cur.score) coverByArtist.set(s.artistId, { url: s.artworkUrl, score });
  });

  const artistsSnap = await db.collection('artists').get();
  const changes = new Map(); // id -> newUrl
  artistsSnap.forEach((d) => {
    const a = d.data();
    const slug = a.slug || slugify(a.name || '');
    const portraitKey = portraits.get(slug);
    const portraitUrl = portraitKey ? `${cfg.publicUrl}/${portraitKey}` : null;
    const current = a.imageUrl || '';

    let next = current;
    if (portraitUrl) {
      next = portraitUrl; // a real portrait always wins
    } else if (isPlaceholderPng(current) || (!current && coverByArtist.has(d.id))) {
      next = coverByArtist.has(d.id) ? coverByArtist.get(d.id).url : '';
    }
    if (next !== current) changes.set(d.id, { name: a.name, from: current, to: next });
  });

  console.log(`artist docs to repair: ${changes.size}`);
  [...changes.values()].slice(0, 20).forEach((c) =>
    console.log(`  ${c.name}: ${(c.from || '(empty)').slice(-45)} → ${(c.to || '(initials)').slice(-45)}`));

  if (DRY) { console.log('DRY RUN'); process.exit(0); }

  let batch = db.batch(); let n = 0;
  for (const [id, c] of changes) {
    batch.update(db.collection('artists').doc(id), { imageUrl: c.to });
    if (++n >= 400) { await batch.commit(); batch = db.batch(); n = 0; }
  }
  if (n) await batch.commit();
  console.log(`Firestore updated: ${changes.size}`);

  for (const file of BUNDLES) {
    if (!fs.existsSync(file)) continue;
    const cat = JSON.parse(fs.readFileSync(file, 'utf8'));
    let touched = 0;
    for (const a of cat.artists || []) {
      const c = changes.get(a.id);
      if (c) { a.imageUrl = c.to; touched++; }
      else if (isPlaceholderPng(a.imageUrl)) { a.imageUrl = ''; touched++; }
    }
    fs.writeFileSync(file, JSON.stringify(cat, null, 2));
    console.log(`${path.relative(repoRoot, file)}: ${touched} updated`);
  }
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
