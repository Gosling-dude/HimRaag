/**
 * Credential loader for the R2 + Firebase pipeline.
 *
 * SECURITY: values are read from the gitignored `.env/` folder at runtime and
 * returned in-memory only. This module NEVER prints, logs, or serializes secret
 * values. The only fields safe to surface (bucket name, public base URL) are
 * exposed via `publicSummary()`.
 *
 * Resolution order for the creds folder:
 *   1. process.env.HIMRAAG_ENV_DIR
 *   2. <repoRoot>/.env
 */
'use strict';

const fs = require('fs');
const path = require('path');

const repoRoot = path.resolve(__dirname, '..', '..');

function envDir() {
  return process.env.HIMRAAG_ENV_DIR || path.join(repoRoot, '.env');
}

/** Parse the Cloudflare credential text file into a key→value map. */
function loadR2() {
  const dir = envDir();
  const file = fs
    .readdirSync(dir)
    .find((f) => /cloud|r2|credential/i.test(f) && f.endsWith('.txt'));
  if (!file) {
    throw new Error(`R2 credential .txt not found under ${dir}`);
  }
  const text = fs.readFileSync(path.join(dir, file), 'utf8');
  const get = (k) => {
    const m = text.match(new RegExp(`^\\s*${k}\\s*[:=]\\s*(.+)$`, 'mi'));
    return m ? m[1].trim() : null;
  };
  const accountId = get('Account ID');
  const bucket = get('Bucket Name');
  const accessKeyId = get('Access Key ID');
  const secretAccessKey = get('Secret Access Key');
  const publicUrl = (get('Public URL') || '').replace(/\/+$/, '');

  const missing = [];
  if (!accountId) missing.push('Account ID');
  if (!bucket) missing.push('Bucket Name');
  if (!accessKeyId) missing.push('Access Key ID');
  if (!secretAccessKey) missing.push('Secret Access Key');
  if (!publicUrl) missing.push('Public URL');
  if (missing.length) {
    throw new Error(`R2 credential file is missing: ${missing.join(', ')}`);
  }

  return {
    accountId,
    bucket,
    accessKeyId,
    secretAccessKey,
    publicUrl,
    endpoint: `https://${accountId}.r2.cloudflarestorage.com`,
  };
}

/** Absolute path to the Firebase service-account JSON (never reads contents). */
function firebaseServiceAccountPath() {
  const dir = envDir();
  const file = fs
    .readdirSync(dir)
    .find((f) => /adminsdk|serviceaccount|firebase/i.test(f) && f.endsWith('.json'));
  if (!file) {
    throw new Error(`Firebase service-account .json not found under ${dir}`);
  }
  return path.join(dir, file);
}

/** Only non-secret fields — safe to print/report. */
function publicSummary() {
  const r2 = loadR2();
  return { bucket: r2.bucket, publicUrl: r2.publicUrl, endpointHost: `${r2.accountId.slice(0, 4)}…r2.cloudflarestorage.com` };
}

module.exports = { loadR2, firebaseServiceAccountPath, publicSummary, envDir };
