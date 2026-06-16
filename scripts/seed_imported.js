/**
 * HimRaag Firestore seed — locally-imported real audio.
 *
 * Parallel to seed_firestore.js (which seeds the DEMO-ONLY catalog). This
 * orchestrates the local-audio pipeline end-to-end:
 *   1. scan_audio.js            → extract metadata + durations from the folder
 *   2. generate_import_catalog.js → copy audio into assets/audio/ + build catalog
 *   3. import.js                → validate (and optionally --commit) to Firestore
 *
 * The bundled audio plays in-app via asset:/// URLs; imported tracks are
 * approved+visible and flagged "needs-metadata-review" for the dashboard.
 *
 * Usage:
 *   # dry-run (scan + generate + validate, no Firestore writes):
 *   node scripts/seed_imported.js
 *   node scripts/seed_imported.js "D:\\Personal Projects\\HimRaag\\music"
 *
 *   # write to Firestore (project: himraag-prod):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node scripts/seed_imported.js --commit
 *
 * No GOOGLE_APPLICATION_CREDENTIALS? Use the Admin Dashboard → Import instead:
 *   paste the `songs` array from scripts/seed_data/imported_catalog.json.
 */

'use strict';

const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const node = process.execPath;
const here = __dirname;
const repoRoot = path.dirname(here);

const argv = process.argv.slice(2);
const commit = argv.includes('--commit');
const folderArg = argv.find((a) => !a.startsWith('--'));
const musicFolder = folderArg || path.join(repoRoot, 'music');

function run(scriptArgs) {
  execFileSync(node, scriptArgs, { stdio: 'inherit', cwd: repoRoot });
}

if (fs.existsSync(musicFolder)) {
  console.log(`🎧 HimRaag import — scanning "${musicFolder}"...\n`);
  run([path.join(here, 'scan_audio.js'), musicFolder]);
} else {
  console.log(`ℹ️  Music folder not found (${musicFolder}); reusing existing scan_result.json.\n`);
}

console.log('\n🎧 HimRaag import — bundling audio + generating catalog...\n');
run([path.join(here, 'generate_import_catalog.js')]);

const catalog = path.join(here, 'seed_data', 'imported_catalog.json');
const importArgs = [path.join(here, 'import.js'), '--json', catalog, '--no-network'];
if (commit) importArgs.push('--commit');

console.log('\n🎧 HimRaag import — validating catalog...\n');
run(importArgs);

if (!commit) {
  console.log(
    '\nℹ️  Dry-run only. To write to Firestore:\n' +
    '   GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node scripts/seed_imported.js --commit\n' +
    '   …or paste scripts/seed_data/imported_catalog.json songs into Admin → Import.'
  );
}
