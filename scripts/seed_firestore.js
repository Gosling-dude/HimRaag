/**
 * HimRaag Firestore seed (demo catalog).
 *
 * This is a thin, repeatable orchestrator:
 *   1. (Re)generates the legally-safe DEMO-ONLY catalog → scripts/seed_data/catalog.json
 *   2. Ingests it through the validating import pipeline (scripts/import.js)
 *
 * It intentionally contains NO inline catalog data — the catalog lives in the
 * generator so seeding is reproducible and the same validation runs every time.
 *
 * IMPORTANT — legal: everything seeded here is license='DEMO_ONLY',
 * approvalStatus='demo', isPublished=false. It is for INTERNAL TESTING ONLY and
 * must never be shipped publicly. Replace with licensed content (via the same
 * import pipeline) before release. See docs/CONTENT_SYSTEM.md.
 *
 * Usage:
 *   # dry-run (validate only, no writes, no creds needed):
 *   node scripts/seed_firestore.js
 *
 *   # write to Firestore (project: himraag-prod):
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/to/sa.json node scripts/seed_firestore.js --commit
 *
 * Get the service-account key from:
 *   Firebase Console → Project Settings → Service Accounts → Generate new private key
 */

'use strict';

const { execFileSync } = require('child_process');
const path = require('path');

const commit = process.argv.includes('--commit');
const offline = process.argv.includes('--no-network');
const node = process.execPath;
const here = __dirname;

function run(scriptArgs) {
  execFileSync(node, scriptArgs, { stdio: 'inherit', cwd: path.dirname(here) });
}

console.log('🌱 HimRaag seed — generating demo catalog...\n');
run([path.join(here, 'generate_demo_catalog.js')]);

const catalog = path.join(here, 'seed_data', 'catalog.json');
const importArgs = [path.join(here, 'import.js'), '--json', catalog];
if (commit) importArgs.push('--commit');
if (offline) importArgs.push('--no-network');

console.log('\n🌱 HimRaag seed — importing catalog...\n');
run(importArgs);

if (!commit) {
  console.log(
    '\nℹ️  Dry-run only. To write to Firestore:\n' +
    '   GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node scripts/seed_firestore.js --commit'
  );
}
