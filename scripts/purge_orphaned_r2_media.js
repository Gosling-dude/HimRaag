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
 * <repo>/.env). Without that folder, deletes go through your `wrangler login`
 * (run in backend/cdn-worker) instead.
 *
 * Usage:
 *   node scripts/purge_orphaned_r2_media.js [backup.json]            # dry run
 *   node scripts/purge_orphaned_r2_media.js [backup.json] --apply    # delete
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { execSync, execFileSync } = require('child_process');
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
const { S3Client, DeleteObjectsCommand } = requireS3();

const PROJECT = 'himraag-prod';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
const APPLY = process.argv.includes('--apply');
// Used when the R2 credential folder isn't available (deletes then go via wrangler).
const DEFAULT_BUCKET = 'himraag-audio';
const DEFAULT_PUBLIC_URL = 'https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev';
const WORKER_DIR = path.join(__dirname, '..', 'backend', 'cdn-worker');

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
    const url = `${BASE}/${collection}?pageSize=300${pageToken ? `&pageToken=${encodeURIComponent(pageToken)}` : ''}`;
    const j = await (await fetch(url, { headers })).json();
    if (j.error) throw new Error(j.error.message);
    out.push(...(j.documents || []));
    pageToken = j.nextPageToken || '';
  } while (pageToken);
  return out;
}

async function main() {
  let r2 = null;
  try {
    r2 = loadR2();
  } catch (e) {
    console.log(`R2 keys unavailable (${e.message}) — deletes will use wrangler.`);
  }
  const publicUrl = r2?.publicUrl || DEFAULT_PUBLIC_URL;
  const r2Host = new URL(publicUrl).host;
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
  console.log(`Live catalog docs:             ${live.length}`);

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

  // The bucket is publicly readable, so presence is checked over HTTP.
  const present = [];
  let bytes = 0;
  for (const key of keys) {
    const res = await fetch(`${publicUrl}/${key.split('/').map(encodeURIComponent).join('/')}`, { method: 'HEAD' });
    if (res.ok) { present.push(key); bytes += Number(res.headers.get('content-length')) || 0; }
  }
  console.log(`Present in bucket now:         ${present.length} (${(bytes / 1048576).toFixed(1)} MB)`);

  if (!APPLY) {
    console.log('\nDry run — nothing changed. Re-run with --apply to delete.');
    return;
  }

  console.log('\nApplying…');
  let deleted = 0;
  if (!r2) {
    for (const key of present) {
      try {
        execFileSync('npx', ['--no-install', 'wrangler', 'r2', 'object', 'delete', `${DEFAULT_BUCKET}/${key}`, '--remote'],
          { cwd: WORKER_DIR, stdio: 'ignore' });
        deleted++;
      } catch {
        console.error(`  failed: ${key}`);
      }
      process.stdout.write(`\r  deleted ${deleted}/${present.length}`);
    }
    console.log('\n\nDone.');
    return;
  }
  const s3 = new S3Client({
    region: 'auto',
    endpoint: r2.endpoint,
    credentials: { accessKeyId: r2.accessKeyId, secretAccessKey: r2.secretAccessKey },
  });
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
