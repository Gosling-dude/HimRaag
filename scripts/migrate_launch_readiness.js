/**
 * One-off launch migration for live Firestore (himraag-prod).
 *
 *  1. Backfill sort fields. The server-built home feed uses indexed
 *     `orderBy(playCount)` / `orderBy(releaseYear)` queries, and Firestore
 *     silently skips docs missing the ordered field. Sets `playCount: 0` and
 *     `releaseYear: <current year>` on songs that lack them.
 *  2. Move media URLs off `pub-….r2.dev` (rate-limited, not for production)
 *     onto the custom CDN domain, for songs.audioUrl/artworkUrl,
 *     albums.artworkUrl and artists.imageUrl.
 *
 * Dry run by default — prints what would change. Add --apply to write.
 *
 * Usage:
 *   node scripts/migrate_launch_readiness.js \
 *     --media-from https://pub-xxxx.r2.dev --media-to https://cdn.himraag.in [--apply]
 *
 * Omit --media-from/--media-to to run only the backfill.
 */
'use strict';

const fs = require('fs');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { PROJECT_ID } = require('./lib/constants');
const { firebaseServiceAccountPath } = require('./lib/credentials');

const args = process.argv.slice(2);
const flag = (name) => {
  const i = args.indexOf(name);
  return i >= 0 ? args[i + 1] : undefined;
};
const APPLY = args.includes('--apply');
const MEDIA_FROM = (flag('--media-from') || '').replace(/\/+$/, '');
const MEDIA_TO = (flag('--media-to') || '').replace(/\/+$/, '');

if (Boolean(MEDIA_FROM) !== Boolean(MEDIA_TO)) {
  console.error('Pass both --media-from and --media-to, or neither.');
  process.exit(1);
}
if (MEDIA_TO && !/^https:\/\//.test(MEDIA_TO)) {
  console.error('--media-to must be an https:// URL');
  process.exit(1);
}

const URL_FIELDS = {
  songs: ['audioUrl', 'artworkUrl'],
  albums: ['artworkUrl'],
  artists: ['imageUrl'],
};

function rewrite(url) {
  if (!MEDIA_FROM || typeof url !== 'string') return null;
  return url.startsWith(`${MEDIA_FROM}/`) ? MEDIA_TO + url.slice(MEDIA_FROM.length) : null;
}

async function main() {
  const saPath = firebaseServiceAccountPath();
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();
  const year = new Date().getFullYear();

  let batch = db.batch();
  let pending = 0;
  let changedDocs = 0;
  const flush = async () => {
    if (APPLY && pending > 0) await batch.commit();
    batch = db.batch();
    pending = 0;
  };

  for (const [collection, fields] of Object.entries(URL_FIELDS)) {
    const snap = await db.collection(collection).get();
    for (const doc of snap.docs) {
      const data = doc.data();
      const update = {};

      if (collection === 'songs') {
        if (typeof data.playCount !== 'number') update.playCount = 0;
        if (typeof data.releaseYear !== 'number') update.releaseYear = year;
      }
      for (const field of fields) {
        const next = rewrite(data[field]);
        if (next) update[field] = next;
      }

      if (Object.keys(update).length === 0) continue;
      changedDocs++;
      console.log(`${APPLY ? 'UPDATE' : 'would update'} ${collection}/${doc.id}`, update);
      batch.update(doc.ref, update);
      if (++pending >= 400) await flush();
    }
  }
  await flush();

  console.log(`\n${changedDocs} document(s) ${APPLY ? 'updated' : 'would change'}.`);
  if (!APPLY && changedDocs > 0) console.log('Re-run with --apply to write.');
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
