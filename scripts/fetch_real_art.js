/**
 * Replace AI/branded poster covers with REAL, text-free artwork.
 *
 * Supersedes the old `regenerate_art.js`, which baked title/artist/region/HimRaag
 * text into generated covers. Per the production art direction the app must look
 * like Spotify / YouTube Music / Apple Music: natural imagery only, no text, no
 * logos, no posters.
 *
 * Resolution per item (see scripts/lib/artwork_sources.js):
 *   Songs   — real official cover via JioSaavn (strict match) → else a
 *             license-clean regional photograph (Wikimedia Commons) → else a
 *             clean placeholder (artworkUrl='' → app gradient/initials fallback).
 *   Artists — real artist photo (exact-name JioSaavn) → else clean placeholder
 *             (imageUrl=''). Never an AI/generated face.
 *   Albums  — reuse the album's representative song cover → else region photo.
 *
 * Images are downloaded and re-hosted on R2 under versioned keys (cache-bust),
 * then artworkUrl/imageUrl are repointed in Firestore AND the bundled catalog.
 * Writes THUMBNAIL_AUDIT.md with per-item source + coverage stats.
 *
 * Usage: node scripts/fetch_real_art.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { loadR2, publicSummary, firebaseServiceAccountPath } = require('./lib/credentials');
const { slugify } = require('./lib/validator');
const { PROJECT_ID } = require('./lib/constants');
const {
  httpGet, downloadImage, findSongArtwork, findArtistImage,
  buildRegionPhotoPool,
} = require('./lib/artwork_sources');

const ART_VER = 'v4'; // bump to cache-bust client-side image caches
const repoRoot = path.dirname(__dirname);
const CATALOG = path.join(repoRoot, 'assets', 'catalog', 'imported_catalog.json');

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const KNOWN_REGIONS = ['Garhwali', 'Kumaoni', 'Jaunsari', 'Himachali', 'Kinnauri', 'Sirmauri', 'Pahadi'];
function regionKey(r) { return KNOWN_REGIONS.includes(r) ? r : 'Pahadi'; }
function extFor(ct) {
  if (/png/i.test(ct)) return 'png';
  if (/webp/i.test(ct)) return 'webp';
  return 'jpg';
}
async function verify200(url) {
  const r = await httpGet(url, { binary: true });
  return r.status === 200 && r.buf && r.buf.length > 1024;
}
function seedHash(s) { let h = 5381; for (let i = 0; i < String(s).length; i++) h = ((h << 5) + h + String(s).charCodeAt(i)) >>> 0; return h; }
/** Pick a region photo and download it, trying every photo in the pool until one
 *  succeeds (a single Wikimedia thumb can 404/time out). Returns {photo,img}|null. */
async function downloadRegionPhoto(photoPool, region, seed) {
  const rk = regionKey(region);
  const list = (photoPool[rk] && photoPool[rk].length ? photoPool[rk] : photoPool.Pahadi) || [];
  if (!list.length) return null;
  const start = seedHash(seed) % list.length;
  for (let i = 0; i < list.length; i++) {
    const c = list[(start + i) % list.length];
    const img = await downloadImage(c.thumb);
    if (img) return { photo: c, img };
  }
  return null;
}

async function main() {
  const cfg = loadR2();
  const sum = publicSummary();
  const client = new S3Client({
    region: 'auto', endpoint: cfg.endpoint,
    credentials: { accessKeyId: cfg.accessKeyId, secretAccessKey: cfg.secretAccessKey },
  });
  const put = (key, body, ct) =>
    client.send(new PutObjectCommand({ Bucket: cfg.bucket, Key: key, Body: body, ContentType: ct }));
  const publicUrl = (key) => `${cfg.publicUrl}/${key}`;

  const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || firebaseServiceAccountPath();
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();

  const catalog = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));
  const catSong = new Map((catalog.songs || []).map((s) => [s.id, s]));
  const catArtist = new Map((catalog.artists || []).map((a) => [a.id, a]));
  const catAlbum = new Map((catalog.albums || []).map((a) => [a.id, a]));

  // Optional id-scope (additive imports): when HIMRAAG_ART_SONG_IDS is set, only
  // (re)fetch art for those song ids and SKIP artist/album art entirely, so the
  // existing curated covers of the original catalog are never overwritten.
  const SCOPE = (process.env.HIMRAAG_ART_SONG_IDS || '')
    .split(',').map((x) => x.trim()).filter(Boolean);
  const scoped = SCOPE.length > 0;
  const inScope = (id) => !scoped || SCOPE.includes(id);
  if (scoped) process.stdout.write(`Scoped art run: ${SCOPE.length} new song ids; artist/album art preserved.\n`);

  // ── Region photo pool (one network pass) ─────────────────────────────────────
  const songSnap = await db.collection('songs').get();
  const regionsPresent = [...new Set(songSnap.docs.map((d) => regionKey(d.data().region)))];
  process.stdout.write(`Building license-clean photo pool for regions: ${regionsPresent.join(', ')}…\n`);
  const photoPool = await buildRegionPhotoPool(regionsPresent);
  for (const r of Object.keys(photoPool)) process.stdout.write(`  pool ${r}: ${photoPool[r].length} photos\n`);

  const reports = { songs: [], artists: [], albums: [] };
  // albumId -> final artwork URL of a representative song (to reuse for albums)
  const albumCoverFromSong = new Map();

  // ── Songs ────────────────────────────────────────────────────────────────────
  let sBatch = db.batch(), sPending = 0;
  for (const doc of songSnap.docs) {
    if (!inScope(doc.id)) continue;
    const s = doc.data();
    const slug = s.slug || slugify(s.title);
    let chosen = null; // { url, source, detail }

    try {
      const real = await findSongArtwork({ title: s.title, artistName: s.artistName, region: s.region });
      if (real) {
        const img = await downloadImage(real.url);
        if (img) {
          const key = `artwork/${slug}-${ART_VER}.${extFor(img.contentType)}`;
          await put(key, img.buf, img.contentType || 'image/jpeg');
          chosen = {
            url: publicUrl(key), source: 'Actual artwork',
            detail: `JioSaavn: "${real.match.song}" / ${real.match.album} — ${real.match.artist} [${real.match.language || '?'}]`,
          };
        }
      }
    } catch (e) { /* fall through to photo */ }

    if (!chosen) {
      const got = await downloadRegionPhoto(photoPool, s.region, doc.id);
      if (got) {
        const key = `artwork/${slug}-${ART_VER}.${extFor(got.img.contentType)}`;
        await put(key, got.img.buf, got.img.contentType || 'image/jpeg');
        chosen = {
          url: publicUrl(key), source: 'Real photograph',
          detail: `Wikimedia: ${got.photo.title} · ${got.photo.license}${got.photo.attribution ? ' · © ' + got.photo.attribution : ''}`,
        };
      }
    }

    const url = chosen ? chosen.url : '';
    const source = chosen ? chosen.source : 'Placeholder';
    const detail = chosen ? chosen.detail : 'No source found → app gradient/initials placeholder';

    if (s.artworkUrl !== url) { sBatch.update(doc.ref, { artworkUrl: url }); sPending++; }
    const cs = catSong.get(doc.id);
    if (cs) cs.artworkUrl = url;
    if (s.albumId && url && !albumCoverFromSong.has(s.albumId)) albumCoverFromSong.set(s.albumId, url);

    reports.songs.push({ title: s.title, region: s.region, source, url, detail });
    process.stdout.write(`  ${source === 'Actual artwork' ? '🎵' : source === 'Real photograph' ? '🏔️ ' : '▫️ '} ${s.title} → ${source}\n`);
    await sleep(250);
  }
  if (sPending) await sBatch.commit();

  // ── Artists ────────────────────────────────────────────────────────────────
  const artistSnap = await db.collection('artists').get();
  let aBatch = db.batch(), aPending = 0;
  for (const doc of artistSnap.docs) {
    if (scoped) break; // preserve existing curated artist art in scoped imports
    const a = doc.data();
    const slug = a.slug || slugify(a.name);
    let url = '', source = 'Placeholder', detail = 'No real photo → clean placeholder avatar (no AI face)';
    try {
      const found = await findArtistImage(a.name);
      if (found) {
        const img = await downloadImage(found.url);
        if (img) {
          const key = `artists/${slug}-${ART_VER}.${extFor(img.contentType)}`;
          await put(key, img.buf, img.contentType || 'image/jpeg');
          url = publicUrl(key); source = 'Real photo'; detail = `JioSaavn artist: ${found.match.name}`;
        }
      }
    } catch (e) { /* placeholder */ }

    if (a.imageUrl !== url) { aBatch.update(doc.ref, { imageUrl: url }); aPending++; }
    const ca = catArtist.get(doc.id);
    if (ca) ca.imageUrl = url;
    reports.artists.push({ name: a.name, source, url, detail });
    process.stdout.write(`  👤 ${a.name} → ${source}\n`);
    await sleep(200);
  }
  if (aPending) await aBatch.commit();

  // ── Albums (reuse representative song cover, else region photo) ───────────────
  const albumSnap = await db.collection('albums').get();
  let alBatch = db.batch(), alPending = 0;
  for (const doc of albumSnap.docs) {
    if (scoped) break; // preserve existing curated album art in scoped imports
    const a = doc.data();
    let url = albumCoverFromSong.get(doc.id) || '';
    let source = url ? 'Actual artwork (from single)' : 'Placeholder';
    let detail = url ? 'Reuses the album’s representative song cover' : '';

    if (!url) {
      const got = await downloadRegionPhoto(photoPool, a.region || a.language, doc.id);
      if (got) {
        const slug = a.slug || slugify(a.title);
        const key = `albums/${slug}-${ART_VER}.${extFor(got.img.contentType)}`;
        await put(key, got.img.buf, got.img.contentType || 'image/jpeg');
        url = publicUrl(key); source = 'Real photograph';
        detail = `Wikimedia: ${got.photo.title} · ${got.photo.license}${got.photo.attribution ? ' · © ' + got.photo.attribution : ''}`;
      }
    }
    if (!url) detail = 'No source found → app gradient/initials placeholder';

    if (a.artworkUrl !== url) { alBatch.update(doc.ref, { artworkUrl: url }); alPending++; }
    const ca = catAlbum.get(doc.id);
    if (ca) ca.artworkUrl = url;
    reports.albums.push({ title: a.title, source, url, detail });
    process.stdout.write(`  💿 ${a.title} → ${source}\n`);
  }
  if (alPending) await alBatch.commit();

  fs.writeFileSync(CATALOG, JSON.stringify(catalog, null, 2) + '\n');

  // ── Verify a sample of public URLs ───────────────────────────────────────────
  const sample = [
    ...reports.songs.filter((r) => r.url).slice(0, 6),
    ...reports.artists.filter((r) => r.url).slice(0, 2),
    ...reports.albums.filter((r) => r.url).slice(0, 2),
  ];
  const verified = [];
  for (const it of sample) verified.push({ url: it.url, ok: await verify200(it.url) });
  const okCount = verified.filter((v) => v.ok).length;

  writeAudit(reports, sum, verified);
  const stat = (arr, label) => `${label}: ${arr.filter((r) => r.source.startsWith('Actual')).length} actual, ` +
    `${arr.filter((r) => r.source.startsWith('Real photo') || r.source === 'Real photograph').length} photo, ` +
    `${arr.filter((r) => r.source === 'Placeholder').length} placeholder (of ${arr.length})`;
  console.log('\n' + stat(reports.songs, 'Songs'));
  console.log(stat(reports.artists, 'Artists'));
  console.log(stat(reports.albums, 'Albums'));
  console.log(`Sample URL verify: ${okCount}/${verified.length} returned 200`);
  console.log('Wrote THUMBNAIL_AUDIT.md');
  if (okCount < verified.length) process.exitCode = 2;
}

// ── Audit report ─────────────────────────────────────────────────────────────
function table(rows, cols) {
  let md = '| ' + cols.join(' | ') + ' |\n|' + cols.map(() => '---').join('|') + '|\n';
  for (const r of rows) md += '| ' + r.map((c) => String(c).replace(/\|/g, '\\|')).join(' | ') + ' |\n';
  return md;
}
function pct(n, d) { return d ? Math.round((n / d) * 100) : 0; }
function writeAudit(reports, sum, verified) {
  const stamp = new Date().toISOString();
  const s = reports.songs, a = reports.artists, al = reports.albums;
  const sActual = s.filter((r) => r.source === 'Actual artwork').length;
  const sPhoto = s.filter((r) => r.source === 'Real photograph').length;
  const sPlace = s.filter((r) => r.source === 'Placeholder').length;
  const aReal = a.filter((r) => r.source === 'Real photo').length;
  const aPlace = a.filter((r) => r.source === 'Placeholder').length;

  let md = `# HimRaag — Thumbnail Audit\n\n_Generated: ${stamp}_\n\n`;
  md += `**Bucket:** \`${sum.bucket}\` · **Public base:** \`${sum.publicUrl}\`\n\n`;
  md += `All artwork is natural imagery only — **no text, no logos, no posters, no AI-generated covers**. ` +
    `Real official cover art is sourced via the public JioSaavn API (strict title/artist/language match); ` +
    `where no confident match exists, a license-clean regional photograph (Wikimedia Commons, ` +
    `Public-domain/CC0/CC-BY-SA) is used. Artists use real photos where an exact-name match exists, ` +
    `otherwise a clean placeholder avatar (never an AI face).\n\n`;

  md += `## Coverage\n\n`;
  md += table([
    ['Songs', s.length, `${sActual} (${pct(sActual, s.length)}%)`, `${sPhoto} (${pct(sPhoto, s.length)}%)`, `${sPlace}`],
    ['Artists', a.length, `${aReal} (${pct(aReal, a.length)}%)`, '—', `${aPlace}`],
    ['Albums', al.length, `${al.filter((r) => r.source.startsWith('Actual')).length}`, `${al.filter((r) => r.source === 'Real photograph').length}`, `${al.filter((r) => r.source === 'Placeholder').length}`],
  ], ['Type', 'Total', 'Actual artwork', 'Real photograph', 'Placeholder']) + '\n';

  md += `## Songs\n\n`;
  md += table(s.map((r, i) => [i + 1, r.title, r.region || '', `**${r.source}**`, r.detail, r.url ? `[link](${r.url})` : '—']),
    ['#', 'Title', 'Region', 'Source', 'Detail', 'Thumbnail']) + '\n';

  md += `## Artists\n\n`;
  md += table(a.map((r, i) => [i + 1, r.name, `**${r.source}**`, r.detail, r.url ? `[link](${r.url})` : '—']),
    ['#', 'Artist', 'Source', 'Detail', 'Image']) + '\n';

  md += `## Albums\n\n`;
  md += table(al.map((r, i) => [i + 1, r.title, `**${r.source}**`, r.detail, r.url ? `[link](${r.url})` : '—']),
    ['#', 'Album', 'Source', 'Detail', 'Artwork']) + '\n';

  md += `## Sample public-URL verification\n\n`;
  md += table(verified.map((v) => [`\`${v.url.split('/').slice(-2).join('/')}\``, v.ok ? '✅ 200' : '❌']), ['Object', 'HTTP']);

  fs.writeFileSync(path.join(repoRoot, 'THUMBNAIL_AUDIT.md'), md);
}

main().catch((e) => { console.error('fetch_real_art failed:', e); process.exit(1); });
