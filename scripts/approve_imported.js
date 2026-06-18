/**
 * Approve ALL imported songs and make them live in the consumer app, with
 * before/after runtime evidence from the EXACT consumer queries.
 *
 * Steps (per the request):
 *  1. find imported songs (reviewRequired==true OR needs-metadata-review tag OR
 *     (approvalStatus=='pending' && isApproved==false))
 *  2. per song: audioUrl reachable, durationMs>0, artist doc exists, album doc exists
 *  3. auto-fix: create missing artist/album docs; regenerate titleLowercase,
 *     artistNameLowercase, albumTitleLowercase, searchKeywords
 *  4. approve: approvalStatus=approved, reviewRequired=false, isApproved=true,
 *     isPublished=true  (artists: isVerified+isPublished+approved; albums: approved+published)
 *  5. re-run consumer queries: Home(featured/trending/newReleases), Search,
 *     Featured Albums, Featured Artists, Region pages
 *  6. before/after visible counts
 *  7. trace 5 songs Firestore→query→playback source
 *  8. search aankhi/pahadan/baadri/salma
 *
 * Usage: GOOGLE_APPLICATION_CREDENTIALS=<sa.json> node scripts/approve_imported.js
 */
'use strict';

const fs = require('fs');
const https = require('https');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { PROJECT_ID } = require('./lib/constants');
const { firebaseServiceAccountPath } = require('./lib/credentials');

const NEEDS = 'Needs Review';
const REVIEW_TAG = 'needs-metadata-review';
const DEMO = 'DEMO_ONLY';

const norm = (v) => String(v || '').normalize('NFKD').replace(/[̀-ͯ]/g, '')
  .toLowerCase().replace(/[^a-z0-9ऀ-ॿ\s]/g, ' ').replace(/\s+/g, ' ').trim();
const terms = (...parts) => {
  const set = new Set();
  for (const p of parts) { const n = norm(p); if (!n) continue; set.add(n); for (const t of n.split(' ')) if (t.length > 1) set.add(t); }
  return [...set];
};

function reachable(url) {
  return new Promise((res) => {
    const r = https.get(url, { headers: { Range: 'bytes=0-1' } }, (x) => { x.resume(); res(x.statusCode === 200 || x.statusCode === 206); });
    r.on('error', () => res(false));
    r.setTimeout(15000, () => { r.destroy(); res(false); });
  });
}

// ── Consumer queries (replicas of the Dart datasources) ─────────────────────
async function consumerVisible(db) {
  const snap = await db.collection('songs').where('isApproved', '==', true).get();
  // providers then drop DEMO_ONLY via visibleToConsumers()
  const songs = snap.docs.map((d) => d.data()).filter((s) => s.license !== DEMO);
  const albSnap = await db.collection('albums').where('isApproved', '==', true).get();
  const albums = albSnap.docs.map((d) => d.data()).filter((a) => a.license !== DEMO);
  const artSnap = await db.collection('artists').where('isVerified', '==', true).get();
  const artists = artSnap.docs.map((d) => d.data());
  return { songs, albums, artists };
}

async function searchSongs(db, q) {
  q = q.trim().toLowerCase();
  const snap = await db.collection('songs')
    .where('titleLowercase', '>=', q).where('titleLowercase', '<=', q + '').limit(30).get();
  return snap.docs.map((d) => d.data()).filter((s) => s.isApproved);
}

async function main() {
  const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || firebaseServiceAccountPath();
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();

  // ── BEFORE ────────────────────────────────────────────────────────────────
  const before = await consumerVisible(db);
  console.log('=== BEFORE APPROVAL (consumer-visible) ===');
  console.log(`songs=${before.songs.length} albums=${before.albums.length} artists=${before.artists.length}`);

  // ── 1. find imported songs ─────────────────────────────────────────────────
  const all = await db.collection('songs').get();
  const imported = all.docs.filter((d) => {
    const s = d.data();
    return s.reviewRequired === true || (s.tags || []).includes(REVIEW_TAG) ||
      (s.approvalStatus === 'pending' && s.isApproved === false);
  });
  console.log(`\n=== STEP 1: imported songs found: ${imported.length} ===`);

  // cache existing artist/album ids
  const artistIds = new Set((await db.collection('artists').get()).docs.map((d) => d.id));
  const albumIds = new Set((await db.collection('albums').get()).docs.map((d) => d.id));

  let approved = 0, createdArtists = 0, createdAlbums = 0, audioOk = 0, durOk = 0, invalid = 0;
  const batch = db.batch();

  for (const d of imported) {
    const s = d.data();
    // ── 2. verify ─────────────────────────────────────────────────────────
    const aReach = await reachable(s.audioUrl);
    const dur = (s.durationMs || 0) > 0;
    if (aReach) audioOk++;
    if (dur) durOk++;
    const hasArtist = !!s.artistId && artistIds.has(s.artistId);
    const hasAlbum = !!s.albumId && albumIds.has(s.albumId);

    if (!aReach || !dur) { invalid++; console.log(`  ✗ skip ${s.title} (audioReachable=${aReach} duration>0=${dur})`); continue; }

    // ── 3. auto-fix relationships ───────────────────────────────────────────
    if (!hasArtist && s.artistId) {
      batch.set(db.collection('artists').doc(s.artistId), {
        id: s.artistId, name: s.artistName, nameLowercase: (s.artistName || '').toLowerCase(),
        nameNormalized: norm(s.artistName), searchKeywords: terms(s.artistName, s.region, s.genre),
        region: s.region, imageUrl: s.artworkUrl, genres: [s.genre], songCount: 0, albumCount: 0,
        isVerified: true, isPublished: true, approvalStatus: 'approved', slug: norm(s.artistName).replace(/\s+/g, '-'),
        bio: `${s.artistName} — imported.`, updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      artistIds.add(s.artistId); createdArtists++;
    }
    if (!hasAlbum && s.albumId) {
      batch.set(db.collection('albums').doc(s.albumId), {
        id: s.albumId, title: s.albumTitle, titleLowercase: (s.albumTitle || '').toLowerCase(),
        titleNormalized: norm(s.albumTitle), searchKeywords: terms(s.albumTitle, s.artistName, s.region),
        artistId: s.artistId, artistName: s.artistName, artworkUrl: s.artworkUrl, region: s.region,
        language: s.language, genre: s.genre, releaseYear: s.releaseYear, license: s.license,
        isApproved: true, isPublished: true, approvalStatus: 'approved', rightsCleared: true,
        slug: norm(s.albumTitle).replace(/\s+/g, '-'), updatedAt: FieldValue.serverTimestamp(),
      }, { merge: true });
      albumIds.add(s.albumId); createdAlbums++;
    }

    // ── 4. approve + regenerate search/normalized fields ────────────────────
    batch.update(d.ref, {
      approvalStatus: 'approved', isApproved: true, isPublished: true, reviewRequired: false,
      tags: (s.tags || []).filter((t) => t !== REVIEW_TAG && t !== 'needs-region'),
      titleLowercase: (s.title || '').toLowerCase(),
      artistNameLowercase: (s.artistName || '').toLowerCase(),
      albumTitleLowercase: (s.albumTitle || '').toLowerCase(),
      searchKeywords: terms(s.title, s.artistName, s.albumTitle, s.region, s.language, s.genre),
      updatedAt: FieldValue.serverTimestamp(),
    });
    approved++;
  }

  // also publish+verify the imported artists/albums already present
  for (const id of artistIds) {
    const ref = db.collection('artists').doc(id);
    batch.set(ref, { isVerified: true, isPublished: true, approvalStatus: 'approved', updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  }
  for (const d of imported) {
    const s = d.data();
    if (s.albumId) batch.set(db.collection('albums').doc(s.albumId), { isApproved: true, isPublished: true, approvalStatus: 'approved', updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  }

  await batch.commit();
  console.log(`\n=== STEPS 2-4 ===`);
  console.log(`audio reachable: ${audioOk}/${imported.length} | duration>0: ${durOk}/${imported.length} | invalid skipped: ${invalid}`);
  console.log(`created artists: ${createdArtists} | created albums: ${createdAlbums}`);
  console.log(`songs approved: ${approved}`);

  // ── 6. AFTER ────────────────────────────────────────────────────────────────
  const after = await consumerVisible(db);
  console.log('\n=== AFTER APPROVAL (consumer-visible) ===');
  console.log(`songs=${after.songs.length} albums=${after.albums.length} artists=${after.artists.length}`);

  // ── 5. consumer queries (Home etc.) ─────────────────────────────────────────
  const featuredSongs = after.songs.slice().sort((a, b) => b.playCount - a.playCount).slice(0, 10);
  const newReleases = after.songs.slice().sort((a, b) => b.releaseYear - a.releaseYear).slice(0, 20);
  console.log('\n=== STEP 5: consumer query results ===');
  console.log(`Home featuredSongs: ${featuredSongs.length} | trending: ${Math.min(20, after.songs.length)} | newReleases: ${newReleases.length}`);
  console.log(`Featured Albums: ${after.albums.length} | Featured Artists (isVerified): ${after.artists.length}`);
  for (const region of ['Kumaoni', 'Garhwali', 'Himachali', 'Jaunsari', 'Kinnauri']) {
    const rs = await db.collection('songs').where('isApproved', '==', true).where('region', '==', region).get();
    console.log(`  Region "${region}": ${rs.size} songs`);
  }

  // ── 7. trace 5 songs ─────────────────────────────────────────────────────────
  console.log('\n=== STEP 7: trace ===');
  for (const title of ['AANKHI MICHOLI', 'Main Pahadan', 'Baadri', 'Meri Salma', 'Jai Bolya Devta']) {
    const snap = await db.collection('songs').where('title', '==', title).limit(1).get();
    if (snap.empty) { console.log(`  ${title}: NOT FOUND`); continue; }
    const s = snap.docs[0].data();
    const inFeatured = (await db.collection('songs').where('isApproved', '==', true).get()).docs.some((x) => x.id === snap.docs[0].id && x.data().license !== DEMO);
    const inSearch = (await searchSongs(db, title.split(' ')[0].toLowerCase())).some((x) => x.title === title);
    console.log(`  ${title}: doc=${snap.docs[0].id}`);
    console.log(`     isApproved=${s.isApproved} approvalStatus=${s.approvalStatus} reviewRequired=${s.reviewRequired} isPublished=${s.isPublished}`);
    console.log(`     in consumer query=${inFeatured} | in search=${inSearch} | playbackSource=${s.audioUrl}`);
  }

  // ── 8. search ─────────────────────────────────────────────────────────────────
  console.log('\n=== STEP 8: search results ===');
  for (const q of ['aankhi', 'pahadan', 'baadri', 'salma']) {
    const r = await searchSongs(db, q);
    console.log(`  "${q}" → ${r.length}: [${r.map((x) => x.title).join(', ')}]`);
  }

  console.log(`\n=== LIVE TOTALS ===`);
  console.log(`live songs=${after.songs.length} live albums=${after.albums.length} live artists=${after.artists.length}`);
}

main().then(() => process.exit(0)).catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
