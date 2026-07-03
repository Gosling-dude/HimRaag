/* Read-only audit for pre-production stabilization: region distribution,
 * artwork/image coverage, duplicate suspects, publish state. */
'use strict';
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const fs = require('fs');
const path = require('path');
const { firebaseServiceAccountPath } = require('./lib/credentials');

const PROJECT_ID = 'himraag-prod';

const norm = (v) => String(v || '').toLowerCase().normalize('NFKD')
  .replace(/[̀-ͯ]/g, '').replace(/[^a-z0-9]+/g, ' ').trim();

(async () => {
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(firebaseServiceAccountPath(), 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();

  const songs = [];
  (await db.collection('songs').get()).forEach((d) => songs.push({ id: d.id, ...d.data() }));
  const artists = [];
  (await db.collection('artists').get()).forEach((d) => artists.push({ id: d.id, ...d.data() }));
  const albums = [];
  (await db.collection('albums').get()).forEach((d) => albums.push({ id: d.id, ...d.data() }));

  const pub = (s) => s.isPublished === true;
  const regionDist = {};
  const regionDistPublished = {};
  for (const s of songs) {
    const r = s.region || '(none)';
    regionDist[r] = (regionDist[r] || 0) + 1;
    if (pub(s)) regionDistPublished[r] = (regionDistPublished[r] || 0) + 1;
  }

  // duplicate suspects among ALL songs: same normalized title+artist
  const byKey = new Map();
  for (const s of songs) {
    const k = `${norm(s.title)}|${norm(s.artistName || s.artist)}`;
    if (!byKey.has(k)) byKey.set(k, []);
    byKey.get(k).push({ id: s.id, title: s.title, artist: s.artistName || s.artist, published: pub(s), review: s.reviewRequired === true });
  }
  const dupGroups = [...byKey.values()].filter((g) => g.length > 1);

  const noArt = songs.filter((s) => !s.thumbnailUrl && !s.artworkUrl && !s.coverUrl).map((s) => s.id);
  const artistNoImg = artists.map((a) => ({ id: a.id, name: a.name, img: a.imageUrl || a.photoUrl || '', featured: a.isFeatured === true }))
    .filter((a) => !/^https?:/.test(a.img));

  const out = {
    counts: { songs: songs.length, published: songs.filter(pub).length, artists: artists.length, albums: albums.length },
    regionDist, regionDistPublished,
    dupGroupCount: dupGroups.length,
    dupGroups: dupGroups.slice(0, 40),
    songsNoArtwork: noArt.length,
    artistsMissingImage: artistNoImg,
    artistList: artists.map((a) => ({ id: a.id, name: a.name, featured: a.isFeatured === true, img: (a.imageUrl || '').slice(0, 60) })),
    sampleSong: songs.find(pub),
    sampleReviewSong: songs.find((s) => s.reviewRequired === true),
  };
  fs.writeFileSync(path.join(__dirname, 'seed_data', 'stabilize_audit.json'), JSON.stringify(out, null, 2));
  console.log(JSON.stringify({ ...out, dupGroups: undefined, artistList: undefined, sampleSong: undefined, sampleReviewSong: undefined }, null, 2));
  console.log('full JSON -> scripts/seed_data/stabilize_audit.json');
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
