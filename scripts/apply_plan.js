/**
 * Bridge: narrow scan_result.json down to exactly the new-unique songs chosen by
 * plan_import.js, so the EXISTING, proven import pipeline (enrich → refine →
 * generate_import_catalog → r2_upload → fetch_real_art → import → merge) runs on
 * the 237 new tracks only — never re-touching the 65 already in the catalog, the
 * 6 mashups, or the duplicate variants.
 *
 * The full scan is preserved at scan_result.full.json. Idempotent.
 *
 * Usage:
 *   node scripts/apply_plan.js
 * Then run the documented pipeline (see NEW_IMPORT_REPORT.md → Execution).
 */
'use strict';
const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, 'seed_data');
const scanPath = path.join(dir, 'scan_result.json');
const fullPath = path.join(dir, 'scan_result.full.json');
const planPath = path.join(dir, 'import_plan.json');

const plan = JSON.parse(fs.readFileSync(planPath, 'utf8'));
// Keep the untouched full scan once.
if (!fs.existsSync(fullPath)) fs.copyFileSync(scanPath, fullPath);
const full = JSON.parse(fs.readFileSync(fullPath, 'utf8'));

const keep = new Set(plan.toImport.map((r) => r.file));
const records = full.records.filter((r) => keep.has(r.fullPath));

fs.writeFileSync(
  scanPath,
  JSON.stringify(
    { scannedAt: new Date().toISOString(), folder: full.folder, scope: 'plan_import:new-uniques', count: records.length, records },
    null,
    2
  )
);
console.log(`scan_result.json scoped to ${records.length} new-unique tracks (full backup: scan_result.full.json).`);
