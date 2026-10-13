/**
 * R2 uploads through your `wrangler login` (run `npx wrangler login` in
 * backend/cdn-worker once) — no R2 access keys needed on this machine.
 */
'use strict';

const path = require('path');
const { execFileSync } = require('child_process');

const BUCKET = 'himraag-audio';
const PUBLIC_BASE = 'https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev';
const WORKER_DIR = path.join(__dirname, '..', '..', 'backend', 'cdn-worker');

/** Uploads [file] to R2 at [key] and returns its public URL. */
function upload(file, key, contentType) {
  execFileSync('npx', ['--no-install', 'wrangler', 'r2', 'object', 'put', `${BUCKET}/${key}`,
    `--file=${file}`, `--content-type=${contentType}`, '--cache-control=public, max-age=31536000, immutable', '--remote'],
  { cwd: WORKER_DIR, stdio: ['ignore', 'ignore', 'inherit'] });
  return `${PUBLIC_BASE}/${key}`;
}

module.exports = { upload, PUBLIC_BASE };
