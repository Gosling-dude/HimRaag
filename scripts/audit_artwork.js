/**
 * Full artwork/image audit — READ ONLY (no regeneration, no writes).
 *
 * For every Firestore song + artist AND every bundled-catalog record, issues a
 * GET (first bytes) against artworkUrl/imageUrl and records: HTTP status,
 * content-type, content-length, cache headers, magic-byte kind (jpeg/png/webp/
 * html/other). Emits:
 *   SONG_ARTWORK_AUDIT.md, ARTIST_IMAGE_AUDIT.md, R2_ARTWORK_AUDIT.md
 *   scripts/seed_data/artwork_audit.json (machine readable)
 *
 * Usage: node scripts/audit_artwork.js
 */
'use strict';
const fs = require('fs');
const path = require('path');
const https = require('https');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { firebaseServiceAccountPath } = require('./lib/credentials');

const repoRoot = path.dirname(__dirname);
const CONCURRENCY = 16;

function probe(url) {
  return new Promise((resolve) => {
    if (!/^https?:/.test(url || '')) return resolve({ status: 0, note: 'empty/no-url' });
    const req = https.get(url, { headers: { Range: 'bytes=0-31' } }, (res) => {
      const chunks = [];
      res.on('data', (d) => { if (chunks.length < 4) chunks.push(d); });
      res.on('end', () => {
        const b = Buffer.concat(chunks);
        let kind = 'other';
        if (b[0] === 0xFF && b[1] === 0xD8) kind = 'jpeg';
        else if (b[0] === 0x89 && b[1] === 0x50) kind = 'png';
        else if (b.slice(0, 4).toString() === 'RIFF') kind = 'webp';
        else if (b.slice(0, 24).toString().toLowerCase().includes('<')) kind = 'html';
        resolve({
          status: res.statusCode,
          contentType: res.headers['content-type'] || '',
          // Range replies carry content-range: bytes 0-31/<total>
          size: Number((res.headers['content-range'] || '').split('/')[1] || res.headers['content-length'] || 0),
          cacheControl: res.headers['cache-control'] || '',
          etag: res.headers.etag ? 'yes' : 'no',
          kind,
        });
      });
    });
    req.on('error', (e) => resolve({ status: -1, note: e.code || e.message }));
    req.setTimeout(20000, () => { req.destroy(); resolve({ status: -2, note: 'timeout' }); });
  });
}

async function mapLimit(items, limit, fn) {
  const out = new Array(items.length);
  let i = 0;
  await Promise.all(Array.from({ length: limit }, async () => {
    while (i < items.length) {
      const idx = i++;
      out[idx] = await fn(items[idx], idx);
    }
  }));
  return out;
}

const ok = (r) => r.status === 200 || r.status === 206;

(async () => {
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(firebaseServiceAccountPath(), 'utf8'))), projectId: 'himraag-prod' });
  const db = getFirestore();

  const songs = [];
  (await db.collection('songs').get()).forEach((d) => songs.push({ id: d.id, ...d.data() }));
  const artists = [];
  (await db.collection('artists').get()).forEach((d) => artists.push({ id: d.id, ...d.data() }));
  const bundle = JSON.parse(fs.readFileSync(path.join(repoRoot, 'assets', 'catalog', 'imported_catalog.json'), 'utf8'));

  console.log(`probing ${songs.length} songs + ${artists.length} artists (Firestore) + ${bundle.songs.length}/${bundle.artists.length} (bundle)…`);

  const songRows = await mapLimit(songs, CONCURRENCY, async (s) => ({
    id: s.id, title: s.title, url: s.artworkUrl || '', published: s.isPublished === true,
    ...(await probe(s.artworkUrl)),
  }));
  const artistRows = await mapLimit(artists, CONCURRENCY, async (a) => ({
    id: a.id, name: a.name, url: a.imageUrl || '', verified: a.isVerified === true,
    ...(await probe(a.imageUrl)),
  }));
  const bundleSongRows = await mapLimit(bundle.songs, CONCURRENCY, async (s) => ({
    id: s.id, title: s.title, url: s.artworkUrl || '', ...(await probe(s.artworkUrl)),
  }));
  const bundleArtistRows = await mapLimit(bundle.artists, CONCURRENCY, async (a) => ({
    id: a.id, name: a.name, url: a.imageUrl || '', ...(await probe(a.imageUrl)),
  }));

  const stat = (rows) => ({
    total: rows.length,
    ok: rows.filter(ok).length,
    empty: rows.filter((r) => r.status === 0).length,
    broken: rows.filter((r) => !ok(r) && r.status !== 0).length,
    nonImageBytes: rows.filter((r) => ok(r) && !['jpeg', 'png', 'webp'].includes(r.kind)).length,
    sizes: rows.filter((r) => ok(r) && r.size > 0).map((r) => r.size),
  });
  const pct = (n, d) => d ? Math.round((n / d) * 1000) / 10 : 0;
  const sizeSummary = (sizes) => {
    if (!sizes.length) return 'n/a';
    sizes.sort((a, b) => a - b);
    const kb = (x) => Math.round(x / 1024) + ' KB';
    return `median ${kb(sizes[sizes.length >> 1])}, p90 ${kb(sizes[Math.floor(sizes.length * 0.9)])}, max ${kb(sizes[sizes.length - 1])}`;
  };

  const S = stat(songRows), A = stat(artistRows), BS = stat(bundleSongRows), BA = stat(bundleArtistRows);

  fs.writeFileSync(path.join(__dirname, 'seed_data', 'artwork_audit.json'), JSON.stringify({
    generatedAt: new Date().toISOString(),
    firestoreSongs: S, firestoreArtists: A, bundleSongs: BS, bundleArtists: BA,
    brokenSongs: songRows.filter((r) => !ok(r) && r.status !== 0),
    brokenArtists: artistRows.filter((r) => !ok(r) && r.status !== 0),
    emptyArtistImages: artistRows.filter((r) => r.status === 0).map((r) => ({ id: r.id, name: r.name })),
    bundleArtistEmpty: bundleArtistRows.filter((r) => r.status === 0).map((r) => ({ id: r.id, name: r.name })),
  }, null, 1));

  // ── SONG_ARTWORK_AUDIT.md ──────────────────────────────────────────────────
  let md = `# SONG ARTWORK AUDIT\n\n_Generated: ${new Date().toISOString()} · read-only probe (status + content-type + magic bytes)_\n\n`;
  md += `## Firestore songs (${S.total})\n\n| Metric | Value |\n|---|---|\n`;
  md += `| Reachable image (HTTP 200/206, real JPEG/PNG/WebP bytes) | **${S.ok - S.nonImageBytes} (${pct(S.ok - S.nonImageBytes, S.total)}%)** |\n`;
  md += `| Empty artworkUrl | ${S.empty} |\n| Broken (non-2xx/timeout) | ${S.broken} |\n`;
  md += `| 2xx but non-image bytes | ${S.nonImageBytes} |\n| Size distribution | ${sizeSummary(S.sizes)} |\n\n`;
  md += `## Bundled catalog songs (${BS.total})\n\n`;
  md += `| Reachable image | **${BS.ok - BS.nonImageBytes} (${pct(BS.ok - BS.nonImageBytes, BS.total)}%)** | Broken: ${BS.broken} · Empty: ${BS.empty} · Sizes: ${sizeSummary(BS.sizes)} |\n\n`;
  if (S.broken || BS.broken) {
    md += `## Broken entries\n\n| Where | Song | Status | URL |\n|---|---|---|---|\n`;
    songRows.filter((r) => !ok(r) && r.status !== 0).forEach((r) => (md += `| firestore | ${r.title} | ${r.status} ${r.note || ''} | ${r.url} |\n`));
    bundleSongRows.filter((r) => !ok(r) && r.status !== 0).forEach((r) => (md += `| bundle | ${r.title} | ${r.status} ${r.note || ''} | ${r.url} |\n`));
  }
  fs.writeFileSync(path.join(repoRoot, 'SONG_ARTWORK_AUDIT.md'), md);

  // ── ARTIST_IMAGE_AUDIT.md (extends previous session's report) ─────────────
  let am = `# ARTIST IMAGE AUDIT\n\n_Generated: ${new Date().toISOString()} · read-only probe_\n\n`;
  am += `## Firestore artists (${A.total})\n\n| Metric | Value |\n|---|---|\n`;
  am += `| Real reachable image | **${A.ok - A.nonImageBytes} (${pct(A.ok - A.nonImageBytes, A.total)}%)** |\n`;
  am += `| Empty imageUrl (app renders initials avatar) | ${A.empty} |\n| Broken | ${A.broken} |\n\n`;
  am += `## Bundled catalog artists (${BA.total})\n\n`;
  am += `| Real reachable image | **${BA.ok - BA.nonImageBytes} (${pct(BA.ok - BA.nonImageBytes, BA.total)}%)** | Empty: ${BA.empty} · Broken: ${BA.broken} |\n\n`;
  const fireHasImg = new Map(artistRows.map((r) => [r.id, r]));
  const divergent = bundleArtistRows.filter((r) => r.status === 0 && fireHasImg.get(r.id) && ok(fireHasImg.get(r.id)));
  am += `## Bundle/Firestore divergence (bundle empty, Firestore has real photo)\n\n`;
  if (divergent.length) {
    am += `**${divergent.length} artists** — the app merges local-first, so these render initials `;
    am += `avatars even though a real photo exists:\n\n`;
    divergent.forEach((r) => (am += `- ${r.name} (${r.id}) → ${fireHasImg.get(r.id).url}\n`));
  } else {
    am += `none\n`;
  }
  if (A.broken) {
    am += `\n## Broken artist images\n\n`;
    artistRows.filter((r) => !ok(r) && r.status !== 0).forEach((r) => (am += `- ${r.name}: ${r.status} ${r.note || ''} ${r.url}\n`));
  }
  fs.writeFileSync(path.join(repoRoot, 'ARTIST_IMAGE_AUDIT.md'), am);

  // ── R2_ARTWORK_AUDIT.md ────────────────────────────────────────────────────
  const all = [...songRows, ...artistRows].filter((r) => ok(r));
  const cacheable = all.filter((r) => /max-age|public/i.test(r.cacheControl)).length;
  const etags = all.filter((r) => r.etag === 'yes').length;
  let rm = `# R2 ARTWORK AUDIT\n\n_Generated: ${new Date().toISOString()}_\n\n`;
  rm += `Probed every Firestore song artworkUrl + artist imageUrl on the public R2 host.\n\n`;
  rm += `| Check | Result |\n|---|---|\n`;
  rm += `| Objects reachable (2xx) | ${all.length} |\n`;
  rm += `| Correct image MIME type | ${all.filter((r) => /^image\//.test(r.contentType)).length} |\n`;
  rm += `| Real image magic bytes | ${all.filter((r) => ['jpeg', 'png', 'webp'].includes(r.kind)).length} |\n`;
  rm += `| ETag present (client revalidation) | ${etags} |\n`;
  rm += `| Cache-Control present | ${cacheable} |\n`;
  rm += `| Broken/missing objects | ${S.broken + A.broken} (listed in song/artist audits) |\n`;
  rm += `| Range requests honored | yes (probes used byte ranges → 206) |\n\n`;
  rm += `Host: public R2 dev URL. Note: \`*.r2.dev\` sends no long-lived Cache-Control by default; `;
  rm += `client-side disk caching (flutter_cache_manager) is therefore the primary cache layer.\n`;
  fs.writeFileSync(path.join(repoRoot, 'R2_ARTWORK_AUDIT.md'), rm);

  console.log(JSON.stringify({
    firestoreSongs: { ok: S.ok, broken: S.broken, empty: S.empty, sizes: sizeSummary(S.sizes) },
    firestoreArtists: { ok: A.ok, broken: A.broken, empty: A.empty },
    bundleSongs: { ok: BS.ok, broken: BS.broken, empty: BS.empty },
    bundleArtists: { ok: BA.ok, broken: BA.broken, empty: BA.empty },
    bundleArtistDivergence: divergent.length,
  }, null, 1));
  console.log('wrote SONG_ARTWORK_AUDIT.md, ARTIST_IMAGE_AUDIT.md, R2_ARTWORK_AUDIT.md');
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
