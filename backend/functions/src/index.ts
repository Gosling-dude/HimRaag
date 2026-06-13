import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import algoliasearch from 'algoliasearch';

admin.initializeApp();
const db = admin.firestore();
const storage = admin.storage();

const ALGOLIA_APP_ID = functions.config().algolia.app_id;
const ALGOLIA_ADMIN_KEY = functions.config().algolia.admin_key;
const algoliaClient = algoliasearch(ALGOLIA_APP_ID, ALGOLIA_ADMIN_KEY);

// ─── Algolia Sync ───────────────────────────────────────────────────────────

export const onSongCreatedOrUpdated = functions.firestore
  .document('songs/{songId}')
  .onWrite(async (change, context) => {
    const songId = context.params.songId;
    const index = algoliaClient.initIndex('songs');

    if (!change.after.exists) {
      await index.deleteObject(songId);
      return;
    }

    const data = change.after.data()!;
    if (!data.isApproved) {
      await index.deleteObject(songId).catch(() => null);
      return;
    }

    await index.saveObject({
      objectID: songId,
      ...data,
    });
  });

export const onArtistWrite = functions.firestore
  .document('artists/{artistId}')
  .onWrite(async (change, context) => {
    const artistId = context.params.artistId;
    const index = algoliaClient.initIndex('artists');

    if (!change.after.exists) {
      await index.deleteObject(artistId);
      return;
    }

    await index.saveObject({
      objectID: artistId,
      ...change.after.data(),
    });
  });

export const onAlbumWrite = functions.firestore
  .document('albums/{albumId}')
  .onWrite(async (change, context) => {
    const albumId = context.params.albumId;
    const index = algoliaClient.initIndex('albums');

    if (!change.after.exists) {
      await index.deleteObject(albumId);
      return;
    }

    const data = change.after.data()!;
    if (!data.isApproved) return;

    await index.saveObject({
      objectID: albumId,
      ...data,
    });
  });

// ─── Play Count ─────────────────────────────────────────────────────────────

export const incrementPlayCount = functions.https.onCall(async (data, context) => {
  const { songId } = data;
  if (!songId) throw new functions.https.HttpsError('invalid-argument', 'songId required');

  await db.collection('songs').doc(songId).update({
    playCount: admin.firestore.FieldValue.increment(1),
  });

  return { success: true };
});

// ─── Content Moderation ─────────────────────────────────────────────────────

export const approveSong = functions.https.onCall(async (data, context) => {
  if (!context.auth?.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Must be admin');
  }

  const { songId, approved } = data;
  await db.collection('songs').doc(songId).update({
    isApproved: approved,
    moderatedAt: admin.firestore.FieldValue.serverTimestamp(),
    moderatedBy: context.auth.uid,
  });

  return { success: true };
});

// ─── Storage Cleanup ────────────────────────────────────────────────────────

export const cleanupDeletedSongFiles = functions.firestore
  .document('songs/{songId}')
  .onDelete(async (snapshot, context) => {
    const data = snapshot.data();
    const bucket = storage.bucket();

    const filesToDelete = [
      data.audioStoragePath,
      data.artworkStoragePath,
    ].filter(Boolean);

    await Promise.allSettled(
      filesToDelete.map((path: string) => bucket.file(path).delete().catch(() => null))
    );
  });

// ─── User Analytics ─────────────────────────────────────────────────────────

export const recordUserActivity = functions.https.onCall(async (data, context) => {
  if (!context.auth) return;

  const { action, songId, albumId, artistId } = data;
  await db.collection('analytics').add({
    userId: context.auth.uid,
    action,
    songId: songId || null,
    albumId: albumId || null,
    artistId: artistId || null,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
  });
});

// ─── Admin: Bulk Index ───────────────────────────────────────────────────────

export const reindexAllSongs = functions.https.onCall(async (data, context) => {
  if (!context.auth?.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }

  const index = algoliaClient.initIndex('songs');
  const snapshot = await db.collection('songs').where('isApproved', '==', true).get();

  const objects = snapshot.docs.map(doc => ({
    objectID: doc.id,
    ...doc.data(),
  }));

  await index.saveObjects(objects);
  return { indexed: objects.length };
});
