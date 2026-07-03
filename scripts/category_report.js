/**
 * CATEGORY_DISTRIBUTION_REPORT.md — before/after region distribution across
 * Firestore (all + consumer-visible) and the bundled catalog.
 *
 * "Before" figures are passed in from the audit snapshot taken at session
 * start (scripts/seed_data/category_before.json, written once); "after" is
 * read live. Usage: node scripts/category_report.js
 */
'use strict';
const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { firebaseServiceAccountPath } = require('./lib/credentials');

const repoRoot = path.dirname(__dirname);
const BEFORE = path.join(__dirname, 'seed_data', 'category_before.json');

(async () => {
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(firebaseServiceAccountPath(), 'utf8'))), projectId: 'himraag-prod' });
  const db = getFirestore();
  const snap = await db.collection('songs').get();
  const all = {}, visible = {};
  snap.forEach((d) => {
    const s = d.data();
    const r = s.region || '(none)';
    all[r] = (all[r] || 0) + 1;
    if (s.isApproved === true && s.license !== 'DEMO_ONLY') visible[r] = (visible[r] || 0) + 1;
  });
  const bundle = JSON.parse(fs.readFileSync(path.join(repoRoot, 'assets', 'catalog', 'imported_catalog.json'), 'utf8'));
  const local = {};
  (bundle.songs || []).forEach((s) => (local[s.region] = (local[s.region] || 0) + 1));

  const before = fs.existsSync(BEFORE) ? JSON.parse(fs.readFileSync(BEFORE, 'utf8')) : null;
  const regions = ['Garhwali', 'Kumaoni', 'Himachali', 'Jaunsari', 'Kinnauri', 'Sirmauri', 'Pahadi', 'Needs Review'];
  const keys = [...new Set([...regions, ...Object.keys(all), ...Object.keys(local)])];

  let md = `# CATEGORY DISTRIBUTION REPORT\n\n_Generated: ${new Date().toISOString()}_\n\n`;
  md += `Classification sources: explicit region tokens in source filenames (Latin + Devanagari), `;
  md += `a curated known-artist→region dictionary, and public-metadata lookups (iTunes/MusicBrainz `;
  md += `title+duration matches, with per-artist region voting from album titles). Songs that stay `;
  md += `genuinely ambiguous remain in the **admin review queue** (Firestore \`Needs Review\`, `;
  md += `unpublished) — never dumped into a specific region. The bundled catalog's legacy \`Pahadi\` `;
  md += `umbrella persists only for previously-live ambiguous songs.\n\n`;
  md += `## Firestore (all songs)\n\n| Region | Before | After |\n|---|---|---|\n`;
  for (const k of keys) {
    const b = before ? (before.all[k] || 0) : '—';
    md += `| ${k} | ${b} | ${all[k] || 0} |\n`;
  }
  md += `\n## Consumer-visible (approved, non-demo)\n\n| Region | Before | After |\n|---|---|---|\n`;
  for (const k of keys) {
    const b = before ? (before.visible[k] || 0) : '—';
    md += `| ${k} | ${b} | ${visible[k] || 0} |\n`;
  }
  md += `\n## Bundled catalog (offline/local)\n\n| Region | Before | After |\n|---|---|---|\n`;
  for (const k of keys) {
    const b = before ? (before.local[k] || 0) : '—';
    md += `| ${k} | ${b} | ${local[k] || 0} |\n`;
  }
  md += `\nTotals — Firestore: ${snap.size} songs; bundled: ${(bundle.songs || []).length} songs.\n`;
  fs.writeFileSync(path.join(repoRoot, 'CATEGORY_DISTRIBUTION_REPORT.md'), md);
  console.log('all:', JSON.stringify(all));
  console.log('visible:', JSON.stringify(visible));
  console.log('local:', JSON.stringify(local));
  console.log('wrote CATEGORY_DISTRIBUTION_REPORT.md');
  process.exit(0);
})().catch((e) => { console.error(e); process.exit(1); });
