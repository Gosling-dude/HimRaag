/**
 * Delete R2 media left behind by scripts/purge_pending_songs.js: the audio of
 * every deleted song, plus artwork/artist images of deleted songs, albums and
 * artists that nothing in the live catalog still points at.
 *
 * Reads the deleted docs from a backup written by purge_pending_songs.js (the
 * newest one by default) and re-checks the LIVE Firestore catalog right before
 * deleting, so a file still used by any current song/album/artist is never
 * touched. Without --apply it only prints the plan (and checks which objects
 * still exist in the bucket).
 *
 * Auth: `firebase login` session for Firestore; R2 keys from the credential
 * folder (see scripts/lib/credentials.js — set HIMRAAG_ENV_DIR if it isn't
 * <repo>/.env).
 *
 * Usage:
 *   node scripts/purge_orphaned_r2_media.js [backup.json]            # dry run
 *   node scripts/purge_orphaned_r2_media.js [backup.json] --apply    # delete
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const { loadR2 } = require('./lib/credentials');

// The S3 SDK is a scripts/ dependency; fall back to the functions install so
// this works without a separate `npm install` in scripts/.
function requireS3() {
  try {
    return require('@aws-sdk/client-s3');
  } catch {
    return require(path.join(__dirname, '../backend/functions/node_modules/@aws-sdk/client-s3'));
  }
}
const { S3Client, DeleteObjectsCommand, HeadObjectCommand } = requireS3();

const PROJECT = 'himraag-prod';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const APPLY = process.argv.includes('--apply');

// The binary resolves to <firebase-tools>/lib/bin/firebase.js.
const toolsLib = path.dirname(path.dirname(fs.realpathSync(execSync('which firebase').toString().trim())));
const auth = require(path.join(toolsLib, 'auth'));
const { configstore } = require(path.join(toolsLib, 'configstore'));

const val = (d, k) => {
  const x = (d.fields || {})[k];
  return x && x.stringValue;
};

const MEDIA_FIELDS = ['audioUrl', 'artworkUrl', 'thumbnailUrl', 'imageUrl'];

function backupPath() {
  const arg = process.argv.slice(2).find((a) => !a.startsWith('--'));
  if (arg) return path.resolve(arg);
  const dir = path.join(__dirname, 'backups');
  // Newest backup that still contains unapproved songs (i.e. taken before the purge).
  const files = fs.readdirSync(dir).filter((f) => f.endsWith('.json')).sort().reverse();
  for (const f of files) {
    const b = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
    if (b.songs.some((d) => d.fields.isApproved?.booleanValue !== true)) return path.join(dir, f);
  }
  throw new Error('No backup with deleted songs found in scripts/backups/.');
}

async function listAll(collection, headers) {
  const out = [];
  let pageToken = '';
  do {
    const url = `${BASE}/${collection}?pageSize=300${pageToken ? `&pageToken=${pageToken}` : ''}`;
    const j = await (await fetch(url, { headers })).json();
    if (j.error) throw new Error(j.error.message);
    out.push(...(j.documents || []));
    pageToken = j.nextPageToken || '';
  } while (pageToken);
  return out;
}

async function main() {
  const r2 = loadR2();
  const r2Host = new URL(r2.publicUrl).host;
  const keyOf = (url) => {
    try {
      const u = new URL(url);
      return u.host === r2Host ? decodeURIComponent(u.pathname.replace(/^\/+/, '')) : null;
    } catch {
      return null;
    }
  };

  const file = backupPath();
  const backup = JSON.parse(fs.readFileSync(file, 'utf8'));
  console.log(`Backup: ${file}`);

  const tokens = configstore.get('tokens');
  if (!tokens?.refresh_token) throw new Error('Not logged in — run `firebase login` first.');
  const { access_token } = await auth.getAccessToken(tokens.refresh_token, []);
  const headers = { Authorization: `Bearer ${access_token}` };
  const live = (await Promise.all(['songs', 'albums', 'artists'].map((c) => listAll(c, headers)))).flat();

  // Every URL the live catalog still uses — these are never deleted.
  const inUse = new Set();
  for (const d of live) for (const f of MEDIA_FIELDS) { const k = keyOf(val(d, f)); if (k) inUse.add(k); }

  const liveNames = new Set(live.map((d) => d.name));
  const gone = [...backup.songs, ...backup.albums, ...backup.artists].filter((d) => !liveNames.has(d.name));

  const candidates = new Set();
  let foreign = 0;
  for (const d of gone) {
    for (const f of MEDIA_FIELDS) {
      const url = val(d, f);
      if (!url) continue;
      const k = keyOf(url);
      if (!k) { foreign++; continue; }
      if (!inUse.has(k)) candidates.add(k);
    }
  }
  const keys = [...candidates];

  console.log(`\nDeleted docs in backup:        ${gone.length}`);
  console.log(`R2 objects to delete:          ${keys.length}`);
  console.log(`  audio:                       ${keys.filter((k) => /\.(mp3|m4a|aac|wav|ogg|flac)$/i.test(k)).length}`);
  console.log(`Still used by live catalog:    skipped`);
  if (foreign) console.log(`URLs not on ${r2Host}:   ${foreign} (ignored)`);

  const s3 = new S3Client({
    region: 'auto',
    endpoint: r2.endpoint,
    credentials: { accessKeyId: r2.accessKeyId, secretAccessKey: r2.secretAccessKey },
  });

  if (!APPLY) {
    let present = 0;
    let bytes = 0;
    for (const Key of keys) {
      try {
        const h = await s3.send(new HeadObjectCommand({ Bucket: r2.bucket, Key }));
        present++;
        bytes += h.ContentLength || 0;
      } catch { /* already gone */ }
    }
    console.log(`Present in bucket now:         ${present} (${(bytes / 1048576).toFixed(1)} MB)`);
    console.log('\nDry run — nothing changed. Re-run with --apply to delete.');
    return;
  }

  console.log('\nApplying…');
  let deleted = 0;
  for (let i = 0; i < keys.length; i += 1000) {
    const res = await s3.send(new DeleteObjectsCommand({
      Bucket: r2.bucket,
      Delete: { Objects: keys.slice(i, i + 1000).map((Key) => ({ Key })), Quiet: true },
    }));
    for (const e of res.Errors || []) console.error(`  failed: ${e.Key} — ${e.Code}`);
    deleted += keys.slice(i, i + 1000).length - (res.Errors || []).length;
  }
  console.log(`  deleted ${deleted} object(s)\n\nDone.`);
}

main().catch((e) => {
  console.error('ERROR:', e.message);
  process.exit(1);
});
