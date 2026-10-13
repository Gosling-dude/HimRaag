/**
 * Permanently remove every song that is NOT approved (isApproved != true),
 * plus albums/artists left with no approved songs, then fix the songCount /
 * albumCount / totalDurationMs on the albums and artists that remain.
 *
 * Deleting a song doc fires the `cleanupDeletedSongMedia` Cloud Function,
 * which deletes its audio (and now-unused artwork) from R2 — irreversible.
 * Albums are deleted before songs so their artwork is freed for cleanup too.
 *
 * A full JSON backup of songs/albums/artists is written to scripts/backups/
 * before anything is changed. Without --apply it only prints the plan.
 *
 * Auth: uses your `firebase login` session (no service account needed).
 *
 * Usage:
 *   node scripts/purge_pending_songs.js            # dry run
 *   node scripts/purge_pending_songs.js --apply    # actually delete
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const PROJECT = 'himraag-prod';
const DB = `projects/${PROJECT}/databases/(default)`;
const BASE = `https://firestore.googleapis.com/v1/${DB}/documents`;
const APPLY = process.argv.includes('--apply');

// Reuse the firebase-tools install behind the `firebase` CLI for its stored login.
// The binary resolves to <firebase-tools>/lib/bin/firebase.js.
const toolsLib = path.dirname(path.dirname(fs.realpathSync(execSync('which firebase').toString().trim())));
const auth = require(path.join(toolsLib, 'auth'));
const { configstore } = require(path.join(toolsLib, 'configstore'));

const val = (d, k) => {
  const x = (d.fields || {})[k];
  return x && (x.stringValue ?? x.booleanValue ?? x.integerValue);
};
const docId = (d) => d.name.split('/').pop();

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

async function commit(writes, headers, label) {
  for (let i = 0; i < writes.length; i += 400) {
    const r = await fetch(`https://firestore.googleapis.com/v1/${DB}/documents:commit`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ writes: writes.slice(i, i + 400) }),
    });
    const j = await r.json();
    if (j.error) throw new Error(`${label}: ${j.error.message}`);
    console.log(`  ${label}: committed ${j.writeResults.length}`);
  }
}

async function main() {
  const tokens = configstore.get('tokens');
  if (!tokens?.refresh_token) throw new Error('Not logged in — run `firebase login` first.');
  const { access_token } = await auth.getAccessToken(tokens.refresh_token, []);
  const headers = { Authorization: `Bearer ${access_token}`, 'Content-Type': 'application/json' };

  const [songs, albums, artists] = await Promise.all(
    ['songs', 'albums', 'artists'].map((c) => listAll(c, headers)),
  );

  const backupDir = path.join(__dirname, 'backups');
  fs.mkdirSync(backupDir, { recursive: true });
  const backupFile = path.join(backupDir, `catalog-${new Date().toISOString().replace(/[:.]/g, '-')}.json`);
  fs.writeFileSync(backupFile, JSON.stringify({ songs, albums, artists }));
  console.log(`Backup: ${backupFile}`);

  const approved = songs.filter((d) => val(d, 'isApproved') === true);
  const pending = songs.filter((d) => val(d, 'isApproved') !== true);

  // Safety: never let R2 cleanup take audio that an approved song still uses.
  const liveAudio = new Set(approved.map((d) => val(d, 'audioUrl')));
  const shared = pending.filter((d) => liveAudio.has(val(d, 'audioUrl')));
  if (shared.length) {
    throw new Error(`${shared.length} pending song(s) share audio with approved songs — aborting.`);
  }

  const liveAlbumIds = new Set(approved.map((d) => val(d, 'albumId')));
  const liveArtistIds = new Set(approved.map((d) => val(d, 'artistId')));
  const deadAlbums = albums.filter((a) => !liveAlbumIds.has(docId(a)));
  const deadArtists = artists.filter((a) => !liveArtistIds.has(docId(a)));
  const keptAlbums = albums.filter((a) => liveAlbumIds.has(docId(a)));
  const keptArtists = artists.filter((a) => liveArtistIds.has(docId(a)));

  const now = new Date().toISOString();
  const countUpdates = [];
  for (const a of keptAlbums) {
    const tracks = approved.filter((s) => val(s, 'albumId') === docId(a));
    const n = tracks.length;
    const dur = tracks.reduce((m, s) => m + Number(val(s, 'durationMs') || 0), 0);
    if (Number(val(a, 'songCount')) !== n || Number(val(a, 'totalDurationMs')) !== dur) {
      countUpdates.push({
        update: { name: a.name, fields: {
          songCount: { integerValue: String(n) },
          totalDurationMs: { integerValue: String(dur) },
          updatedAt: { timestampValue: now },
        } },
        updateMask: { fieldPaths: ['songCount', 'totalDurationMs', 'updatedAt'] },
        currentDocument: { exists: true },
      });
    }
  }
  for (const a of keptArtists) {
    const n = approved.filter((s) => val(s, 'artistId') === docId(a)).length;
    const albumN = keptAlbums.filter((x) => val(x, 'artistId') === docId(a)).length;
    if (Number(val(a, 'songCount')) !== n || Number(val(a, 'albumCount')) !== albumN) {
      countUpdates.push({
        update: { name: a.name, fields: {
          songCount: { integerValue: String(n) },
          albumCount: { integerValue: String(albumN) },
          updatedAt: { timestampValue: now },
        } },
        updateMask: { fieldPaths: ['songCount', 'albumCount', 'updatedAt'] },
        currentDocument: { exists: true },
      });
    }
  }

  console.log(`\nApproved songs kept:     ${approved.length}`);
  console.log(`Pending songs to delete: ${pending.length}`);
  console.log(`Empty albums to delete:  ${deadAlbums.length} (of ${albums.length})`);
  console.log(`Empty artists to delete: ${deadArtists.length} (of ${artists.length})`);
  console.log(`Count fixes:             ${countUpdates.length}`);

  if (!APPLY) {
    console.log('\nDry run — nothing changed. Re-run with --apply to delete.');
    return;
  }

  console.log('\nApplying…');
  await commit([...deadAlbums, ...deadArtists].map((d) => ({ delete: d.name })), headers, 'albums+artists');
  await commit(pending.map((d) => ({ delete: d.name })), headers, 'songs');
  await commit(countUpdates, headers, 'count fixes');
  console.log('\nDone.');
}

main().catch((e) => {
  console.error('ERROR:', e.message);
  process.exit(1);
});
