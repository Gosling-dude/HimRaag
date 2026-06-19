/**
 * Recompute artist.songCount / artist.albumCount and album.songCount /
 * album.totalDurationMs in Firestore from the actual approved song documents.
 * Keeps the catalog self-consistent after additive imports (batched upsert of a
 * new song batch can leave the shared "Pahadi Folk" collective's counts stale).
 *
 * Read-mostly + idempotent: only the count fields are written, only when they
 * differ. Usage: node scripts/reconcile_counts.js
 */
'use strict';
const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { PROJECT_ID } = require('./lib/constants');
const { firebaseServiceAccountPath } = require('./lib/credentials');

(async () => {
  const saPath =
    process.env.GOOGLE_APPLICATION_CREDENTIALS || firebaseServiceAccountPath();
  initializeApp({
    credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))),
    projectId: PROJECT_ID,
  });
  const db = getFirestore();

  const songsSnap = await db.collection('songs').get();
  const byArtist = new Map(); // artistId -> { songs, albums:Set }
  const byAlbum = new Map(); // albumId -> { count, durMs }
  songsSnap.forEach((d) => {
    const s = d.data();
    if (s.artistId) {
      const a = byArtist.get(s.artistId) || { songs: 0, albums: new Set() };
      a.songs++;
      if (s.albumId) a.albums.add(s.albumId);
      byArtist.set(s.artistId, a);
    }
    if (s.albumId) {
      const al = byAlbum.get(s.albumId) || { count: 0, durMs: 0 };
      al.count++;
      al.durMs += Number(s.durationMs) || 0;
      byAlbum.set(s.albumId, al);
    }
  });

  let artistUpdates = 0;
  let aBatch = db.batch();
  const artistsSnap = await db.collection('artists').get();
  artistsSnap.forEach((doc) => {
    const a = byArtist.get(doc.id);
    if (!a) return;
    const cur = doc.data();
    if (cur.songCount !== a.songs || cur.albumCount !== a.albums.size) {
      aBatch.update(doc.ref, { songCount: a.songs, albumCount: a.albums.size });
      artistUpdates++;
    }
  });
  if (artistUpdates) await aBatch.commit();

  let albumUpdates = 0;
  let alBatch = db.batch();
  const albumsSnap = await db.collection('albums').get();
  albumsSnap.forEach((doc) => {
    const al = byAlbum.get(doc.id);
    if (!al) return;
    const cur = doc.data();
    if (cur.songCount !== al.count || cur.totalDurationMs !== al.durMs) {
      alBatch.update(doc.ref, {
        songCount: al.count,
        totalDurationMs: al.durMs,
      });
      albumUpdates++;
    }
  });
  if (albumUpdates) await alBatch.commit();

  console.log(
    `Reconciled: artists updated ${artistUpdates}, albums updated ${albumUpdates}`,
  );
  process.exit(0);
})().catch((e) => {
  console.error('ERR', e.message);
  process.exit(1);
});
