/**
 * Replace artist profile images with verified real photos.
 *
 * Input is a reviewed results file (one entry per artist):
 *   { id, name, status: "found" | "none", file, sourcePage, personShown, evidence }
 * where `file` is a downloaded photo relative to --photos.
 *
 * found → resized to ≤800px JPEG, uploaded to R2 as artist/<id>-v6.jpg, and
 *         artists/<id>.imageUrl points at it.
 * none  → imageUrl cleared, so the app shows its initials avatar instead of the
 *         old generated monogram or a borrowed song poster.
 * Mirrors imageUrl into the bundled catalog (assets/catalog/imported_catalog.json)
 * and writes scripts/seed_data/artist_photos_report.md listing every photo's
 * source page — the list to work from when asking artists for permission.
 *
 * Usage:
 *   node scripts/apply_artist_photos.js --results <file.json> --photos <dir>           # dry run
 *   node scripts/apply_artist_photos.js --results <file.json> --photos <dir> --apply   # upload + write
 *
 * Uploads use `wrangler r2 object put` (run `npx wrangler login` in
 * backend/cdn-worker first); Firestore writes use your `firebase login`.
 */
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');
const { PROJECT_ID } = require('./lib/constants');
const { loginHeaders, docWrite, commit } = require('./lib/firebase_rest');

const arg = (name) => { const i = process.argv.indexOf(name); return i > 0 ? process.argv[i + 1] : null; };
const APPLY = process.argv.includes('--apply');
const RESULTS = arg('--results');
const PHOTOS = arg('--photos');
const BUCKET = 'himraag-audio';
const PUBLIC_BASE = 'https://pub-fbd0e71ca20e41deaf8e1ea21cea0e42.r2.dev';
const VERSION = 'v6'; // bump to cache-bust client image caches
const repoRoot = path.dirname(__dirname);
const WORKER_DIR = path.join(repoRoot, 'backend', 'cdn-worker');
const CATALOG = path.join(repoRoot, 'assets', 'catalog', 'imported_catalog.json');
const REPORT = path.join(__dirname, 'seed_data', 'artist_photos_report.md');

async function listArtists() {
  const base = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/artists?pageSize=300`;
  const out = [];
  let token;
  do {
    const body = await (await fetch(base + (token ? `&pageToken=${encodeURIComponent(token)}` : ''))).json();
    if (body.error) throw new Error(body.error.message);
    for (const d of body.documents || []) {
      out.push({ id: d.name.split('/').pop(), name: d.fields.name?.stringValue, imageUrl: d.fields.imageUrl?.stringValue || '' });
    }
    token = body.nextPageToken;
  } while (token);
  return out;
}

/** ≤800px JPEG copy in a temp dir (sips ships with macOS). */
function toJpeg(src, id) {
  const out = path.join(os.tmpdir(), `himraag-artist-${id}.jpg`);
  execFileSync('sips', ['-Z', '800', '-s', 'format', 'jpeg', '-s', 'formatOptions', '85', src, '--out', out], { stdio: 'ignore' });
  return out;
}

function upload(file, key) {
  execFileSync('npx', ['--no-install', 'wrangler', 'r2', 'object', 'put', `${BUCKET}/${key}`,
    `--file=${file}`, '--content-type=image/jpeg', '--cache-control=public, max-age=31536000, immutable', '--remote'],
  { cwd: WORKER_DIR, stdio: ['ignore', 'ignore', 'inherit'] });
}

async function main() {
  if (!RESULTS || !PHOTOS) throw new Error('usage: --results <file.json> --photos <dir> [--apply]');
  const results = new Map(JSON.parse(fs.readFileSync(RESULTS, 'utf8')).map((r) => [r.id, r]));
  const artists = await listArtists();

  const plan = artists.filter((a) => a.id !== 'artist_unknown_artist').map((a) => {
    const r = results.get(a.id);
    const file = r?.status === 'found' && r.file ? path.join(PHOTOS, path.basename(r.file)) : null;
    if (file && !fs.existsSync(file)) throw new Error(`${a.id}: photo missing at ${file}`);
    const key = file ? `artist/${a.id.replace(/^artist_/, '').replace(/_/g, '-')}-${VERSION}.jpg` : null;
    return { ...a, result: r, file, key, newUrl: key ? `${PUBLIC_BASE}/${key}` : '' };
  });
  const found = plan.filter((p) => p.file);
  const cleared = plan.filter((p) => !p.file && p.imageUrl);
  console.log(`artists=${plan.length} photos=${found.length} cleared=${cleared.length} unchanged=${plan.length - found.length - cleared.length}`);

  let md = `# Artist photos — ${APPLY ? 'APPLIED' : 'dry run'} ${new Date().toISOString()}\n\n`;
  md += `${found.length} artists have a real photo; ${plan.length - found.length} show the initials avatar.\n`;
  md += 'Photos come from public profiles/articles and are copyrighted by their owners — get each artist\'s permission before a public release.\n\n';
  md += '| # | Artist | Photo shows | Source page | Why it is them |\n|---|---|---|---|---|\n';
  const esc = (v) => String(v ?? '').replace(/\|/g, '\\|').replace(/\n/g, ' ');
  found.forEach((p, i) => {
    md += `| ${i + 1} | ${esc(p.name)} | ${esc(p.result.personShown)} | ${esc(p.result.sourcePage)} | ${esc(p.result.evidence)} |\n`;
  });
  md += `\n## No verified photo (initials avatar)\n\n${plan.filter((p) => !p.file).map((p) => `- ${p.name}`).join('\n')}\n`;
  fs.writeFileSync(REPORT, md);
  console.log(`report → ${path.relative(process.cwd(), REPORT)}`);

  if (!APPLY) { console.log('dry run — nothing uploaded or written. Re-run with --apply.'); return; }

  for (const [i, p] of found.entries()) {
    upload(toJpeg(p.file, p.id), p.key);
    process.stdout.write(`\r  uploaded ${i + 1}/${found.length}`);
  }
  console.log();

  const changed = plan.filter((p) => p.newUrl !== p.imageUrl);
  await commit(changed.map((p) => docWrite('artists', p.id, { imageUrl: p.newUrl }, true)), await loginHeaders());
  console.log(`Firestore: updated imageUrl on ${changed.length} artists`);

  const catalog = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));
  const urls = new Map(plan.map((p) => [p.id, p.newUrl]));
  for (const a of catalog.artists) if (urls.has(a.id)) a.imageUrl = urls.get(a.id);
  fs.writeFileSync(CATALOG, JSON.stringify(catalog, null, 2) + '\n');
  console.log('bundled catalog updated');
}

main().then(() => process.exit(0)).catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
