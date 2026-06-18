/**
 * DEPRECATED — do not run. Superseded by `scripts/fetch_real_art.js`.
 *
 * This generator bakes title/artist/region/HimRaag *text* into branded poster
 * covers, which is exactly the look the production art direction removed. Real,
 * text-free artwork (JioSaavn official covers + Wikimedia photos) is now produced
 * by `fetch_real_art.js`. Kept only for reference. Running it re-introduces the
 * poster text — guarded below behind ALLOW_BRANDED_COVERS=1.
 *
 * Regenerate professional cover art for the whole catalog and re-upload to R2.
 *
 * - Songs:   overwrite existing artwork/<key>.png with a branded cover
 *            (title + artist + region + HimRaag wordmark). URL unchanged.
 * - Artists: generate a dedicated artists/<slug>.png monogram cover, upload,
 *            and repoint imageUrl in Firestore + bundled catalog.
 * - Albums:  generate a dedicated albums/<slug>.png cover, upload, repoint
 *            artworkUrl in Firestore + bundled catalog.
 *
 * Drives from live Firestore (all 29/16/14 records) and mirrors imported
 * records into assets/catalog/imported_catalog.json. Verifies a sample of
 * public URLs return HTTP 200 and writes ARTWORK/ARTIST/ALBUM reports.
 *
 * Usage: node scripts/regenerate_art.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const https = require('https');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { loadR2, publicSummary, firebaseServiceAccountPath } = require('./lib/credentials');
const { slugify } = require('./lib/validator');
const { makeSongCover, makeArtistCover } = require('./lib/cover_art');

const ART_VER = 'v3'; // bump to cache-bust client-side image caches
const { PROJECT_ID } = require('./lib/constants');

const repoRoot = path.dirname(__dirname);
const CATALOG = path.join(repoRoot, 'assets', 'catalog', 'imported_catalog.json');

function keyFromUrl(url, publicUrl) {
  if (!url || !url.startsWith(publicUrl)) return null;
  return url.slice(publicUrl.length + 1);
}
function verifyUrl(url) {
  return new Promise((resolve) => {
    const req = https.get(url, { headers: { Range: 'bytes=0-0' } }, (res) => {
      res.resume();
      resolve({ ok: res.statusCode === 200 || res.statusCode === 206, status: res.statusCode });
    });
    req.on('error', () => resolve({ ok: false, status: 0 }));
    req.setTimeout(20000, () => { req.destroy(); resolve({ ok: false, status: 0 }); });
  });
}

async function main() {
  if (process.env.ALLOW_BRANDED_COVERS !== '1') {
    console.error('DEPRECATED: this script bakes poster text into covers. Use scripts/fetch_real_art.js instead.');
    console.error('To override (not recommended), set ALLOW_BRANDED_COVERS=1.');
    process.exit(1);
  }
  const cfg = loadR2();
  const sum = publicSummary();
  const client = new S3Client({
    region: 'auto',
    endpoint: cfg.endpoint,
    credentials: { accessKeyId: cfg.accessKeyId, secretAccessKey: cfg.secretAccessKey },
  });
  const put = (key, body) => client.send(new PutObjectCommand({ Bucket: cfg.bucket, Key: key, Body: body, ContentType: 'image/png' }));
  const publicUrl = (key) => `${cfg.publicUrl}/${key}`;

  const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || firebaseServiceAccountPath();
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();

  const catalog = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));
  const catSong = new Map((catalog.songs || []).map((s) => [s.id, s]));
  const catArtist = new Map((catalog.artists || []).map((a) => [a.id, a]));
  const catAlbum = new Map((catalog.albums || []).map((a) => [a.id, a]));

  const reports = { songs: [], artists: [], albums: [] };

  // ── Songs ──────────────────────────────────────────────────────────────────
  const songSnap = await db.collection('songs').get();
  let sBatch = db.batch(), sPending = 0;
  for (const doc of songSnap.docs) {
    const s = doc.data();
    const region = s.region && s.region !== 'Needs Review' ? s.region : (s.language || 'Pahadi');
    const key = `artwork/${s.slug || slugify(s.title)}-${ART_VER}.png`;
    const png = makeSongCover({ title: s.title, subtitle: s.artistName, region, seed: doc.id });
    await put(key, png);
    const url = publicUrl(key);
    if (s.artworkUrl !== url) { sBatch.update(doc.ref, { artworkUrl: url }); sPending++; }
    const cs = catSong.get(doc.id);
    if (cs) cs.artworkUrl = url;
    reports.songs.push({ title: s.title, key, url, bytes: png.length });
    process.stdout.write(`  ↑ song   ${key} (${png.length} B)  ${s.title}\n`);
  }
  if (sPending) await sBatch.commit();

  // ── Artists ────────────────────────────────────────────────────────────────
  const artistSnap = await db.collection('artists').get();
  let aBatch = db.batch(), aPending = 0;
  for (const doc of artistSnap.docs) {
    const a = doc.data();
    const slug = a.slug || slugify(a.name);
    const key = `artists/${slug}-${ART_VER}.png`;
    const region = a.region && a.region !== 'Needs Review' ? a.region : 'Pahadi';
    const png = makeArtistCover({ title: a.name, region, seed: doc.id });
    await put(key, png);
    const url = publicUrl(key);
    aBatch.update(doc.ref, { imageUrl: url }); aPending++;
    const ca = catArtist.get(doc.id);
    if (ca) ca.imageUrl = url;
    reports.artists.push({ name: a.name, key, url, bytes: png.length });
    process.stdout.write(`  ↑ artist ${key} (${png.length} B)  ${a.name}\n`);
  }
  if (aPending) await aBatch.commit();

  // ── Albums ─────────────────────────────────────────────────────────────────
  const albumSnap = await db.collection('albums').get();
  let alBatch = db.batch(), alPending = 0;
  for (const doc of albumSnap.docs) {
    const a = doc.data();
    const slug = a.slug || slugify(a.title);
    const key = `albums/${slug}-${ART_VER}.png`;
    const region = a.region && a.region !== 'Needs Review' ? a.region : (a.language || 'Pahadi');
    const png = makeSongCover({ title: a.title, subtitle: a.artistName, region, seed: doc.id });
    await put(key, png);
    const url = publicUrl(key);
    alBatch.update(doc.ref, { artworkUrl: url }); alPending++;
    const ca = catAlbum.get(doc.id);
    if (ca) ca.artworkUrl = url;
    reports.albums.push({ title: a.title, key, url, bytes: png.length });
    process.stdout.write(`  ↑ album  ${key} (${png.length} B)  ${a.title}\n`);
  }
  if (alPending) await alBatch.commit();

  fs.writeFileSync(CATALOG, JSON.stringify(catalog, null, 2) + '\n');

  // ── Verify a sample of public URLs ───────────────────────────────────────────
  const sample = [...reports.songs.slice(0, 4), ...reports.artists.slice(0, 3), ...reports.albums.slice(0, 3)];
  const verified = [];
  for (const it of sample) verified.push({ url: it.url, ...(await verifyUrl(it.url)) });
  const okCount = verified.filter((v) => v.ok).length;

  writeReports(reports, sum, verified);
  console.log(`\nRegenerated: songs=${reports.songs.length} artists=${reports.artists.length} albums=${reports.albums.length}`);
  console.log(`Sample URL verify: ${okCount}/${verified.length} returned 200/206`);
  console.log('Wrote ARTWORK_REPORT.md, ARTIST_REPORT.md, ALBUM_REPORT.md');
  if (okCount < verified.length) process.exitCode = 2;
}

function table(rows, cols) {
  let md = '| ' + cols.join(' | ') + ' |\n|' + cols.map(() => '---').join('|') + '|\n';
  for (const r of rows) md += '| ' + r.join(' | ') + ' |\n';
  return md;
}
function writeReports(reports, sum, verified) {
  const stamp = new Date().toISOString();
  const head = (title, n) =>
    `# ${title}\n\n_Generated: ${stamp}_\n\n**Bucket:** \`${sum.bucket}\` · **Public base:** \`${sum.publicUrl}\`\n\n` +
    `Covers are generated 600×600 branded PNGs (region gradient + monogram + title + HimRaag wordmark). ` +
    `Real licensed artwork is not scraped from third-party services. Count: **${n}**.\n\n`;

  let vmd = '## Sample public-URL verification\n\n' +
    table(verified.map((v) => [`\`${v.url.split('/').slice(-2).join('/')}\``, v.ok ? `✅ ${v.status}` : `❌ ${v.status}`]), ['Object', 'HTTP']);

  fs.writeFileSync(path.join(repoRoot, 'ARTWORK_REPORT.md'),
    head('HimRaag — Song Artwork Report (Phase 3)', reports.songs.length) +
    table(reports.songs.map((r, i) => [i + 1, r.title, `\`${r.key}\``, `${r.bytes} B`]), ['#', 'Title', 'R2 key', 'Size']) + '\n' + vmd);

  fs.writeFileSync(path.join(repoRoot, 'ARTIST_REPORT.md'),
    head('HimRaag — Artist Image Report (Phase 4)', reports.artists.length) +
    table(reports.artists.map((r, i) => [i + 1, r.name, `\`${r.key}\``, `${r.bytes} B`]), ['#', 'Artist', 'R2 key', 'Size']) + '\n' + vmd);

  fs.writeFileSync(path.join(repoRoot, 'ALBUM_REPORT.md'),
    head('HimRaag — Album Cover Report (Phase 5)', reports.albums.length) +
    table(reports.albums.map((r, i) => [i + 1, r.title, `\`${r.key}\``, `${r.bytes} B`]), ['#', 'Album', 'R2 key', 'Size']) + '\n' + vmd);
}

main().catch((e) => { console.error('regenerate failed:', e); process.exit(1); });
