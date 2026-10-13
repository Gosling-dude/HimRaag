import { initializeApp } from 'firebase-admin/app';
import {
  DocumentReference,
  FieldValue,
  getFirestore,
  Timestamp,
} from 'firebase-admin/firestore';
import { logger } from 'firebase-functions/v2';
import { defineSecret, defineString } from 'firebase-functions/params';
import { HttpsError, onCall } from 'firebase-functions/v2/https';
import { onSchedule } from 'firebase-functions/v2/scheduler';
import { onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { DeleteObjectCommand, S3Client } from '@aws-sdk/client-s3';

import {
  applyDailyQuota,
  istDayKey,
  mergeCounts,
  PlayCounts,
  PlayPayloadError,
  rankTrending,
  recentDayKeys,
  validatePlays,
} from './logic/plays';
import {
  buildHomeFeed,
  byNumberDesc,
  pickFeaturedArtists,
  DocRecord,
  FEED_VERSION,
} from './logic/feed';
import { mediaKeyFromUrl, parseHostList } from './logic/media';

initializeApp();
const db = getFirestore();

const REGION = 'asia-south1';

// ─── Params & secrets ───────────────────────────────────────────────────────
// Set with `firebase functions:secrets:set R2_ACCESS_KEY_ID` etc.; plain
// params are prompted on first deploy and stored in functions/.env.<project>.
const R2_ACCOUNT_ID = defineString('R2_ACCOUNT_ID');
const R2_BUCKET = defineString('R2_BUCKET', { default: 'himraag-audio' });
const MEDIA_HOSTS = defineString('MEDIA_HOSTS', {
  description:
    'Comma-separated hosts that serve R2 media, e.g. cdn.himraag.in,pub-xxxx.r2.dev',
});
const R2_ACCESS_KEY_ID = defineSecret('R2_ACCESS_KEY_ID');
const R2_SECRET_ACCESS_KEY = defineSecret('R2_SECRET_ACCESS_KEY');

// ─── Collections (server-only; client access denied by security rules) ──────

/** Sharded write buffers for incoming plays. Spreading writes over N docs
 *  keeps each doc far below Firestore's ~1 sustained write/sec/doc limit. */
const PLAY_SHARDS = 'playShards';
const PLAY_SHARD_COUNT = 20;
/** Shard contents claimed by the aggregator but not yet applied. */
const PLAY_BATCHES = 'playBatches';
/** One doc per IST day: `{ counts: { songId: n } }`. Feeds trending. */
const DAILY_PLAYS = 'dailyPlays';
/** Per-user daily counters for abuse limiting. */
const PLAY_QUOTAS = 'playQuotas';
const FEEDS = 'feeds';

const PAHADI_REGIONS = [
  'Garhwali',
  'Kumaoni',
  'Jaunsari',
  'Himachali',
  'Kinnauri',
  'Sirmauri',
];

// ─── Play counting ──────────────────────────────────────────────────────────

/**
 * Records a batch of plays from one client. The app buffers plays locally
 * (a play = 30s listened) and flushes ~every 10 plays, so this runs about
 * once or twice per user per day.
 *
 * Writes only to a random shard doc; song docs are updated by
 * [aggregatePlays], so no song document ever becomes a write hotspot.
 */
export const recordPlays = onCall(
  {
    region: REGION,
    // Flip to true once App Check (Play Integrity) is configured in the
    // Firebase console and the app ships firebase_app_check.
    enforceAppCheck: false,
    maxInstances: 20,
  },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError('unauthenticated', 'Sign in (guest is fine) first');
    }

    let requested: PlayCounts;
    try {
      requested = validatePlays((request.data as { plays?: unknown })?.plays);
    } catch (e) {
      if (e instanceof PlayPayloadError) {
        throw new HttpsError('invalid-argument', e.message);
      }
      throw e;
    }

    const day = istDayKey(new Date());
    const quotaRef = db.collection(PLAY_QUOTAS).doc(uid);
    const result = await db.runTransaction(async (tx) => {
      const snap = await tx.get(quotaRef);
      const used = snap.get('day') === day ? Number(snap.get('count')) || 0 : 0;
      const quota = applyDailyQuota(requested, used);
      if (quota.acceptedTotal > 0) {
        tx.set(quotaRef, { day, count: used + quota.acceptedTotal });
      }
      return quota;
    });

    if (result.acceptedTotal > 0) {
      const shard = Math.floor(Math.random() * PLAY_SHARD_COUNT);
      const increments: Record<string, FieldValue> = {};
      for (const [songId, n] of Object.entries(result.accepted)) {
        increments[songId] = FieldValue.increment(n);
      }
      await db
        .collection(PLAY_SHARDS)
        .doc(String(shard))
        .set({ counts: increments }, { merge: true });
    }

    return { accepted: result.acceptedTotal, dropped: result.dropped };
  },
);

/** Moves every shard's counts into a playBatches doc, atomically per shard. */
async function claimShards(): Promise<void> {
  for (let i = 0; i < PLAY_SHARD_COUNT; i++) {
    const shardRef = db.collection(PLAY_SHARDS).doc(String(i));
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(shardRef);
      const counts = snap.get('counts') as PlayCounts | undefined;
      if (!snap.exists || !counts || Object.keys(counts).length === 0) return;
      tx.create(db.collection(PLAY_BATCHES).doc(), {
        counts,
        claimedAt: FieldValue.serverTimestamp(),
      });
      tx.delete(shardRef);
    });
  }
}

/**
 * Applies claimed batches to song docs + today's dailyPlays doc. A batch doc
 * is deleted only after its counts are written, so a crash mid-run retries
 * (worst case: a few plays double-counted, never silently lost).
 */
async function applyBatches(): Promise<number> {
  const batches = await db.collection(PLAY_BATCHES).limit(200).get();
  if (batches.empty) return 0;

  let totals: PlayCounts = {};
  for (const doc of batches.docs) {
    totals = mergeCounts(totals, (doc.get('counts') as PlayCounts) ?? {});
  }

  // Only increment songs that exist; ids are validated but not looked up at
  // record time (that would cost a read per play).
  const songIds = Object.keys(totals);
  const existing = new Set<string>();
  for (let i = 0; i < songIds.length; i += 300) {
    const refs = songIds
      .slice(i, i + 300)
      .map((id) => db.collection('songs').doc(id));
    const snaps = await db.getAll(...refs);
    for (const s of snaps) if (s.exists) existing.add(s.id);
  }

  const dailyIncrements: Record<string, FieldValue> = {};
  const writes: Array<[DocumentReference, Record<string, unknown>]> = [];
  for (const [songId, n] of Object.entries(totals)) {
    if (!existing.has(songId)) continue;
    dailyIncrements[songId] = FieldValue.increment(n);
    writes.push([
      db.collection('songs').doc(songId),
      { playCount: FieldValue.increment(n) },
    ]);
  }

  // dailyPlays (1 write) + song increments, in chunks under the 500-op limit.
  const day = istDayKey(new Date());
  let batch = db.batch();
  let ops = 0;
  if (Object.keys(dailyIncrements).length > 0) {
    batch.set(
      db.collection(DAILY_PLAYS).doc(day),
      { counts: dailyIncrements, updatedAt: FieldValue.serverTimestamp() },
      { merge: true },
    );
    ops++;
  }
  for (const [ref, data] of writes) {
    batch.update(ref, data);
    if (++ops >= 450) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  for (const doc of batches.docs) {
    batch.delete(doc.ref);
    if (++ops >= 450) {
      await batch.commit();
      batch = db.batch();
      ops = 0;
    }
  }
  if (ops > 0) await batch.commit();

  return Object.values(totals).reduce((s, n) => s + n, 0);
}

// ─── Home feed ──────────────────────────────────────────────────────────────

function records(
  snap: FirebaseFirestore.QuerySnapshot,
): DocRecord[] {
  return snap.docs.map((d) => ({ id: d.id, data: d.data() }));
}

/** Rebuilds `feeds/home` from a handful of indexed queries (~200 reads). */
async function rebuildHomeFeed(): Promise<void> {
  const songs = db.collection('songs').where('isApproved', '==', true);

  const [featuredSnap, newSnap, albumsSnap, artistsSnap] = await Promise.all([
    songs.orderBy('playCount', 'desc').limit(20).get(),
    songs.orderBy('releaseYear', 'desc').limit(40).get(),
    db.collection('albums').where('isApproved', '==', true).limit(20).get(),
    db.collection('artists').where('isVerified', '==', true).get(),
  ]);

  const regionEntries = await Promise.all(
    PAHADI_REGIONS.map(async (region) => {
      const snap = await songs
        .where('region', '==', region)
        .orderBy('playCount', 'desc')
        .limit(30)
        .get();
      return [region, records(snap)] as const;
    }),
  );

  // Trending: decayed plays over the last 7 days, topped up with all-time
  // popular songs while the catalog has little play history.
  const dayKeys = recentDayKeys(new Date(), 7);
  const daySnaps = await db.getAll(
    ...dayKeys.map((k) => db.collection(DAILY_PLAYS).doc(k)),
  );
  const rankedIds = rankTrending(
    daySnaps.map((s) => (s.get('counts') as PlayCounts) ?? {}),
  ).slice(0, 40);
  const trending: DocRecord[] = [];
  if (rankedIds.length > 0) {
    const snaps = await db.getAll(
      ...rankedIds.map((id) => db.collection('songs').doc(id)),
    );
    for (const s of snaps) {
      if (s.exists && s.get('isApproved') === true) {
        trending.push({ id: s.id, data: s.data()! });
      }
    }
  }
  for (const r of records(featuredSnap)) {
    if (trending.length >= 40) break;
    if (!trending.some((t) => t.id === r.id)) trending.push(r);
  }

  const feed = buildHomeFeed({
    featured: records(featuredSnap),
    trending,
    newReleases: records(newSnap),
    regions: Object.fromEntries(regionEntries),
    albums: records(albumsSnap).sort(byNumberDesc('releaseYear')),
    artists: pickFeaturedArtists(records(artistsSnap)),
  });

  await db
    .collection(FEEDS)
    .doc('home')
    .set({ ...feed, generatedAt: Timestamp.now() });
  logger.info('home feed rebuilt', {
    version: FEED_VERSION,
    songs: Object.keys(feed.songs).length,
    trending: feed.trendingSongIds.length,
  });
}

/** Every 30 min: fold buffered plays into songs, then refresh the home feed. */
export const aggregatePlays = onSchedule(
  { region: REGION, schedule: 'every 30 minutes', timeZone: 'Asia/Kolkata' },
  async () => {
    await claimShards();
    const applied = await applyBatches();
    logger.info('plays aggregated', { applied });
    await rebuildHomeFeed();
  },
);

function requireAdmin(auth: { token: Record<string, unknown> } | undefined) {
  if (auth?.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Admin only');
  }
}

/** Admin: refresh Home immediately after publishing content. */
export const refreshHomeFeed = onCall({ region: REGION }, async (request) => {
  requireAdmin(request.auth);
  await rebuildHomeFeed();
  return { success: true };
});

// ─── Content moderation ─────────────────────────────────────────────────────

/** Mirrors the admin dashboard's setApprovalStatus: approving publishes. */
export const approveSong = onCall({ region: REGION }, async (request) => {
  requireAdmin(request.auth);
  const { songId, approved } = (request.data ?? {}) as {
    songId?: unknown;
    approved?: unknown;
  };
  if (typeof songId !== 'string' || typeof approved !== 'boolean') {
    throw new HttpsError('invalid-argument', 'songId and approved required');
  }
  await db.collection('songs').doc(songId).update({
    isApproved: approved,
    isPublished: approved,
    approvalStatus: approved ? 'approved' : 'rejected',
    moderatedAt: FieldValue.serverTimestamp(),
    moderatedBy: request.auth!.uid,
  });
  return { success: true };
});

// ─── R2 cleanup ─────────────────────────────────────────────────────────────

/**
 * When a song doc is deleted, delete its audio from R2. Artwork is deleted
 * only if no other song or album still points at the same URL (album covers
 * are often shared with their tracks).
 */
export const cleanupDeletedSongMedia = onDocumentDeleted(
  {
    region: REGION,
    document: 'songs/{songId}',
    secrets: [R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY],
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const hosts = parseHostList(MEDIA_HOSTS.value());
    const keys: string[] = [];

    const audioKey = mediaKeyFromUrl(data.audioUrl, hosts);
    if (audioKey) keys.push(audioKey);

    const artworkUrl = data.artworkUrl as string | undefined;
    const artworkKey = mediaKeyFromUrl(artworkUrl, hosts);
    if (artworkKey && artworkUrl) {
      const [songRefs, albumRefs] = await Promise.all([
        db.collection('songs').where('artworkUrl', '==', artworkUrl).limit(1).get(),
        db.collection('albums').where('artworkUrl', '==', artworkUrl).limit(1).get(),
      ]);
      if (songRefs.empty && albumRefs.empty) keys.push(artworkKey);
    }
    if (keys.length === 0) return;

    const s3 = new S3Client({
      region: 'auto',
      endpoint: `https://${R2_ACCOUNT_ID.value()}.r2.cloudflarestorage.com`,
      credentials: {
        accessKeyId: R2_ACCESS_KEY_ID.value(),
        secretAccessKey: R2_SECRET_ACCESS_KEY.value(),
      },
    });
    const results = await Promise.allSettled(
      keys.map((Key) =>
        s3.send(new DeleteObjectCommand({ Bucket: R2_BUCKET.value(), Key })),
      ),
    );
    results.forEach((r, i) => {
      if (r.status === 'rejected') {
        logger.error('R2 delete failed', { key: keys[i], error: String(r.reason) });
      } else {
        logger.info('R2 object deleted', { key: keys[i] });
      }
    });
  },
);
