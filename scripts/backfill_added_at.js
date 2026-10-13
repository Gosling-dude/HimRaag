/**
 * One-off: give every song an `addedAt` timestamp (when it joined the
 * catalog) so New Releases can show recently added songs. releaseYear can't
 * do that — older imports were all stamped with the import year.
 *
 * Uses each song doc's Firestore createTime; songs that already have
 * addedAt are left alone, so re-running is safe.
 *
 * Usage: node scripts/backfill_added_at.js [--apply]
 */
'use strict';

const { PROJECT_ID } = require('./lib/constants');
const { loginHeaders, commit } = require('./lib/firebase_rest');

const DB = `projects/${PROJECT_ID}/databases/(default)`;

async function main() {
  const headers = await loginHeaders();
  const docs = [];
  let token;
  do {
    const url = `https://firestore.googleapis.com/v1/${DB}/documents/songs?pageSize=300`
      + `&mask.fieldPaths=addedAt${token ? `&pageToken=${encodeURIComponent(token)}` : ''}`;
    const body = await (await fetch(url, { headers })).json();
    if (body.error) throw new Error(body.error.message);
    docs.push(...(body.documents || []));
    token = body.nextPageToken;
  } while (token);

  const todo = docs.filter((d) => !d.fields?.addedAt);
  console.log(`songs=${docs.length} missing addedAt=${todo.length}`);
  if (!process.argv.includes('--apply')) { console.log('dry run — re-run with --apply.'); return; }

  await commit(todo.map((d) => ({
    update: { name: d.name, fields: { addedAt: { timestampValue: d.createTime } } },
    updateMask: { fieldPaths: ['addedAt'] },
    currentDocument: { exists: true },
  })), headers);
  console.log(`set addedAt on ${todo.length} songs`);
}

main().then(() => process.exit(0)).catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
