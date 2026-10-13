/**
 * Firestore writes over REST using your `firebase login` session (project
 * owner, so security rules don't apply) — no service-account file needed.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { PROJECT_ID } = require('./constants');

const DB = `projects/${PROJECT_ID}/databases/(default)`;

async function loginHeaders() {
  const { execSync } = require('child_process');
  const toolsLib = path.dirname(path.dirname(fs.realpathSync(execSync('which firebase').toString().trim())));
  const auth = require(path.join(toolsLib, 'auth'));
  const { configstore } = require(path.join(toolsLib, 'configstore'));
  const tokens = configstore.get('tokens');
  if (!tokens?.refresh_token) throw new Error('Not logged in — run `firebase login` first.');
  const { access_token } = await auth.getAccessToken(tokens.refresh_token, []);
  return { Authorization: `Bearer ${access_token}`, 'Content-Type': 'application/json' };
}

function encode(v) {
  if (v === null || v === undefined) return { nullValue: null };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(encode) } };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return Number.isInteger(v) ? { integerValue: String(v) } : { doubleValue: v };
  return { stringValue: String(v) };
}

/** Field-masked upsert; `mustExist` makes it an update-only write. Stamps updatedAt. */
function docWrite(collection, id, fields, mustExist) {
  return {
    update: { name: `${DB}/documents/${collection}/${id}`, fields: Object.fromEntries(Object.entries(fields).map(([k, v]) => [k, encode(v)])) },
    updateMask: { fieldPaths: Object.keys(fields) },
    ...(mustExist ? { currentDocument: { exists: true } } : {}),
    updateTransforms: [{ fieldPath: 'updatedAt', setToServerValue: 'REQUEST_TIME' }],
  };
}

/** Commits writes in chunks of 400 (each chunk is atomic). */
async function commit(writes, headers) {
  for (let i = 0; i < writes.length; i += 400) {
    const res = await fetch(`https://firestore.googleapis.com/v1/${DB}/documents:commit`, {
      method: 'POST', headers, body: JSON.stringify({ writes: writes.slice(i, i + 400) }),
    });
    const body = await res.json();
    if (body.error) throw new Error(`commit: ${body.error.message}`);
  }
}

module.exports = { loginHeaders, docWrite, commit };
