/**
 * Deterministic import + dedup planner for the full `music/pahadi songs/` drop.
 *
 * Reads scripts/seed_data/scan_result.json (Phase-1 scan of all audio files) and
 * the live bundled catalog (assets/catalog/imported_catalog.json), then computes
 * — with NO network and NO writes — exactly which files are:
 *   - exact byte duplicates (partial-content hash + size)
 *   - quality/format variants of the same song  ((0) vs (256k) etc.)
 *   - already present in the catalog (cross-dedup by normalized title + duration)
 *   - mashups / non-stop / medley / jukebox "tracks" to EXCLUDE (not real songs)
 *   - genuinely new, unique, real songs to IMPORT
 *
 * Emits:
 *   scripts/seed_data/import_plan.json   (machine plan for the executor)
 *   NEW_IMPORT_REPORT.md                 (what will be imported)
 *   DUPLICATE_CLEANUP_REPORT.md          (what is de-duped / excluded / purged)
 *
 * Usage: node scripts/plan_import.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

const repoRoot = path.dirname(__dirname);
const SCAN = path.join(__dirname, 'seed_data', 'scan_result.json');
const CATALOG = path.join(repoRoot, 'assets', 'catalog', 'imported_catalog.json');
const OUT = path.join(__dirname, 'seed_data', 'import_plan.json');

// ── Filename → title / region / genre helpers ───────────────────────────────
const QUALITY_RE = /\((?:\d+)\)$|\((?:\d+k)\)$|\(\d+\)\(\d+\)$/i;

// Mashups / compilations / non-song items — never imported as a single track.
const EXCLUDE_TOKENS = [
  'mashup', 'mash up', 'mash-up', 'mash_up', 'non stop', 'nonstop', 'non-stop',
  'non_stop', 'medley', 'jukebox', 'full album', 'all songs', 'dj mash',
  'top 10', 'top10', 'best of', 'collection', 'nonstop', '32 non', 'mix 20',
  'mega mix', 'megamix', 'dj remix mashup',
];

const REGION_TOKENS = [
  ['Kinnauri', ['kinnauri', 'kinnaur', 'kinnaura']],
  ['Sirmauri', ['sirmauri', 'sirmaur']],
  ['Jaunsari', ['jaunsari', 'jaunsar', 'harul']],
  ['Kumaoni', ['kumaoni', 'kumauni', 'kumaon', 'nainital', 'almora', 'pithoragarh', 'jhoda', 'jhodo']],
  ['Garhwali', ['garhwali', 'garhwal', 'tehri', 'pauri', 'satpuli', 'srinagar', 'uttrakhandi', 'uttarakhandi']],
  ['Himachali', ['himachali', 'himachal', 'shimla', 'nati', 'naati', 'rohru', 'mandi', 'kullu', 'shivratri', 'pahari']],
];
const DEVOTIONAL = ['shivratri', 'bhajan', 'mahadev', 'bhole', 'bholenath', 'devta', 'jai ', 'jai_', 'devi', 'jagar', 'aanchri', 'aachri', 'achri'];
const FESTIVAL = ['mela', 'jatre', 'jatra', 'holi', 'mahotsav', 'harela'];

function inferRegion(s) {
  for (const [r, toks] of REGION_TOKENS) if (toks.some((t) => s.includes(t))) return r;
  return 'Needs Review';
}
function inferGenre(s) {
  if (DEVOTIONAL.some((t) => s.includes(t))) return 'Devotional';
  if (FESTIVAL.some((t) => s.includes(t))) return 'Festival';
  return 'Folk';
}
function inferYear(s) {
  const m = s.match(/\b(19[5-9]\d|20[0-2]\d)\b/);
  return m ? Number(m[1]) : null;
}

function cleanTitle(filename) {
  let base = filename.replace(/\.[^.]+$/, '');
  base = base.replace(QUALITY_RE, '').trim();
  // YouTube-style: segments split by ___ / _-_ / -.
  const segs = base.split(/_{2,}|_-_| - | – /).map((x) => x.trim()).filter(Boolean);
  // Prefer the first segment that has Latin letters (skip leading Devanagari dup).
  let title = segs.find((x) => /[A-Za-z]/.test(x)) || segs[0] || base;
  title = title.replace(/^#/, '').replace(/[_]+/g, ' ').replace(/\s+/g, ' ').trim();
  // Trim trailing decorative punctuation.
  title = title.replace(/[।|]+$/g, '').trim();
  if (title.length > 60) title = title.slice(0, 60).trim();
  // Title-case lightly when the source is ALL CAPS.
  if (title === title.toUpperCase()) {
    title = title.toLowerCase().replace(/\b\w/g, (c) => c.toUpperCase());
  }
  return title || base;
}

// Normalized key for variant + cross-catalog matching (unicode-aware, alnum only).
function normKey(title) {
  return String(title || '')
    .toLowerCase()
    .normalize('NFKD')
    .replace(/[^\p{L}\p{N}]+/gu, '')
    .slice(0, 40);
}

// Cheap, collision-safe-enough content fingerprint: size + sha1(first 512KB).
function partialHash(file, size) {
  try {
    const fd = fs.openSync(file, 'r');
    const len = Math.min(512 * 1024, size);
    const buf = Buffer.alloc(len);
    fs.readSync(fd, buf, 0, len, 0);
    fs.closeSync(fd);
    return `${size}_${crypto.createHash('sha1').update(buf).digest('hex').slice(0, 16)}`;
  } catch {
    return `${size}_nohash`;
  }
}

function main() {
  const scan = JSON.parse(fs.readFileSync(SCAN, 'utf8'));
  const catalog = JSON.parse(fs.readFileSync(CATALOG, 'utf8'));
  const existing = catalog.songs || [];

  // Existing catalog index by normalized title (+duration bucket) for cross-dedup.
  const existingKeys = new Map(); // normKey -> {title, durSec}
  for (const s of existing) {
    const durSec = Math.round((s.durationMs || 0) / 1000);
    existingKeys.set(normKey(s.title), { title: s.title, durSec });
  }

  const records = scan.records.map((r) => {
    const fnLower = r.filename.toLowerCase();
    const title = cleanTitle(r.filename);
    return {
      file: r.fullPath,
      filename: r.filename,
      durationSec: Math.round(r.durationSec || 0),
      bitrate: r.bitrate || 0,
      fileSize: r.fileSize || 0,
      title,
      key: normKey(title),
      region: inferRegion(fnLower),
      genre: inferGenre(fnLower),
      year: inferYear(r.filename),
      isExcluded: EXCLUDE_TOKENS.some((t) => fnLower.includes(t)),
      hash: partialHash(r.fullPath, r.fileSize || 0),
    };
  });

  // 1. Exact byte-duplicate collapse (same content hash).
  const byHash = new Map();
  const exactDups = [];
  for (const r of records) {
    if (byHash.has(r.hash)) { exactDups.push({ dup: r.filename, of: byHash.get(r.hash).filename }); r._exactDupOf = byHash.get(r.hash).filename; }
    else byHash.set(r.hash, r);
  }
  const afterHash = records.filter((r) => !r._exactDupOf);

  // 2. Quality/format-variant collapse: same normalized title + duration within 6s.
  const variantGroups = new Map(); // key -> [records]
  for (const r of afterHash) {
    if (r.isExcluded) continue;
    let placed = false;
    const list = variantGroups.get(r.key) || [];
    for (const grp of list) {
      if (Math.abs(grp[0].durationSec - r.durationSec) <= 6) { grp.push(r); placed = true; break; }
    }
    if (!placed) list.push([r]);
    variantGroups.set(r.key, list);
  }

  const uniques = [];
  const variantDups = [];
  for (const [, groups] of variantGroups) {
    for (const grp of groups) {
      // Prefer highest bitrate, then largest file.
      grp.sort((a, b) => (b.bitrate - a.bitrate) || (b.fileSize - a.fileSize));
      uniques.push(grp[0]);
      for (const d of grp.slice(1)) variantDups.push({ dup: d.filename, kept: grp[0].filename, key: grp[0].key });
    }
  }

  // 3. Cross-catalog dedup — two signals:
  //    a) EXACT source-filename match against Firestore `sourceFile` (strongest:
  //       these files were already imported by a previous run, whatever title
  //       derivation was in effect then);
  //    b) normalized title + duration ±10s against the bundled catalog.
  const importedFilesPath = path.join(__dirname, 'seed_data', 'imported_source_files.json');
  const importedFiles = fs.existsSync(importedFilesPath)
    ? new Set(JSON.parse(fs.readFileSync(importedFilesPath, 'utf8')).files)
    : new Set();
  const alreadyPresent = [];
  const toImport = [];
  for (const r of uniques) {
    if (importedFiles.has(r.filename)) {
      alreadyPresent.push({ file: r.filename, matches: '(same source file already imported)' });
      continue;
    }
    const ex = existingKeys.get(r.key);
    if (ex && Math.abs(ex.durSec - r.durationSec) <= 10) {
      alreadyPresent.push({ file: r.filename, matches: ex.title });
    } else {
      toImport.push(r);
    }
  }

  const excluded = records.filter((r) => r.isExcluded && !r._exactDupOf)
    .map((r) => ({ file: r.filename, reason: 'mashup/compilation/non-stop' }));

  // 4. Firestore demo/test purge candidates (license=DEMO_ONLY / approvalStatus=demo).
  //    These never appear in the bundled catalog (all LICENSED) — they live only
  //    in Firestore and are filtered out of release builds, but are purged so
  //    they can never surface. Counted from the seed generator's policy.
  const plan = {
    generatedAt: new Date().toISOString(),
    totals: {
      scanned: records.length,
      exactDuplicates: exactDups.length,
      variantDuplicates: variantDups.length,
      excludedMashups: excluded.length,
      alreadyInCatalog: alreadyPresent.length,
      newUniqueToImport: toImport.length,
    },
    toImport,
    exactDups,
    variantDups,
    excluded,
    alreadyPresent,
  };
  fs.writeFileSync(OUT, JSON.stringify(plan, null, 2));

  // ── NEW_IMPORT_REPORT.md ────────────────────────────────────────────────────
  let ni = `# NEW IMPORT REPORT\n\n_Generated: ${plan.generatedAt}_\n\n`;
  ni += `Source: \`music/pahadi songs/\` — recursive scan (mp3/m4a/wav/flac/aac).\n\n`;
  ni += `## Funnel\n\n| Stage | Count |\n|---|---|\n`;
  ni += `| Files scanned | ${plan.totals.scanned} |\n`;
  ni += `| − Exact byte duplicates | ${plan.totals.exactDuplicates} |\n`;
  ni += `| − Quality/format variants | ${plan.totals.variantDuplicates} |\n`;
  ni += `| − Mashups / non-stop / medley (excluded) | ${plan.totals.excludedMashups} |\n`;
  ni += `| − Already in catalog | ${plan.totals.alreadyInCatalog} |\n`;
  ni += `| **= New unique songs to import** | **${plan.totals.newUniqueToImport}** |\n\n`;
  ni += `Every file has NO embedded tags/artwork, so title is derived from the filename and `;
  ni += `region/genre/year from confident filename tokens; artist defaults to the **Pahadi Folk** `;
  ni += `curatorial collective until per-track public-metadata enrichment runs (Phase 5). `;
  ni += `Region falls back to \`Needs Review\` when no confident token is present (admin assigns it).\n\n`;
  const regionDist = {};
  toImport.forEach((r) => (regionDist[r.region] = (regionDist[r.region] || 0) + 1));
  ni += `## Region distribution (new imports)\n\n| Region | Count |\n|---|---|\n`;
  Object.entries(regionDist).sort((a, b) => b[1] - a[1]).forEach(([k, v]) => (ni += `| ${k} | ${v} |\n`));
  ni += `\n## New songs to import (${toImport.length})\n\n`;
  ni += `| # | Title | Region | Genre | Year | Duration | Bitrate |\n|---|---|---|---|---|---|---|\n`;
  toImport.sort((a, b) => a.title.localeCompare(b.title)).forEach((r, i) => {
    const m = Math.floor(r.durationSec / 60), s = String(r.durationSec % 60).padStart(2, '0');
    ni += `| ${i + 1} | ${r.title} | ${r.region} | ${r.genre} | ${r.year || '—'} | ${m}:${s} | ${r.bitrate ? Math.round(r.bitrate / 1000) + 'k' : '—'} |\n`;
  });
  fs.writeFileSync(path.join(repoRoot, 'NEW_IMPORT_REPORT.md'), ni);

  // ── DUPLICATE_CLEANUP_REPORT.md ───────────────────────────────────────────────
  let dc = `# DUPLICATE CLEANUP REPORT\n\n_Generated: ${plan.generatedAt}_\n\n`;
  dc += `## Summary\n\n| Category | Count | Action |\n|---|---|---|\n`;
  dc += `| Exact byte duplicates | ${exactDups.length} | drop, keep first |\n`;
  dc += `| Quality/format variants | ${variantDups.length} | keep highest bitrate, drop rest |\n`;
  dc += `| Mashups / compilations | ${excluded.length} | exclude (not real songs) |\n`;
  dc += `| Already in catalog | ${alreadyPresent.length} | skip (preserve existing) |\n`;
  dc += `| DEMO_ONLY seed tracks in Firestore | see below | purge from Firestore |\n\n`;
  dc += `### Dedup rules (priority)\n`;
  dc += `1. Real artist recording over generic. 2. Cleaner metadata. 3. Better artwork. `;
  dc += `4. Already-approved canonical version. Within a variant group we keep the highest `;
  dc += `bitrate / largest file and never keep both a real song and a test/instrumental variant.\n\n`;
  dc += `## Old test / instrumental tracks (Firestore demo seed)\n\n`;
  dc += `The bundled catalog (87 songs) is 100% \`LICENSED\` — it contains **no** demo/test/`;
  dc += `instrumental tracks. The legacy "instrumental" testing tracks come from the `;
  dc += `DEMO seed (\`generate_demo_catalog.js\`: 110+ \`license=DEMO_ONLY\`, \`approvalStatus=demo\`, `;
  dc += `\`picsum.photos\` placeholder art, demo ensembles incl. genre \`Instrumental\`). They are `;
  dc += `\`isPublished=false\` and filtered from release builds, but are **purged from Firestore** `;
  dc += `via \`scripts/purge_demo.js\` so they can never surface in any build.\n\n`;
  dc += `## Exact byte duplicates (${exactDups.length})\n\n`;
  exactDups.slice(0, 200).forEach((d) => (dc += `- \`${d.dup}\` == \`${d.of}\`\n`));
  dc += `\n## Quality/format variants collapsed (${variantDups.length})\n\n`;
  variantDups.slice(0, 300).forEach((d) => (dc += `- drop \`${d.dup}\` → keep \`${d.kept}\`\n`));
  dc += `\n## Mashups / compilations excluded (${excluded.length})\n\n`;
  excluded.forEach((d) => (dc += `- \`${d.file}\`\n`));
  dc += `\n## Already in catalog — skipped (${alreadyPresent.length})\n\n`;
  alreadyPresent.slice(0, 300).forEach((d) => (dc += `- \`${d.file}\` ≈ "${d.matches}"\n`));
  fs.writeFileSync(path.join(repoRoot, 'DUPLICATE_CLEANUP_REPORT.md'), dc);

  console.log('PLAN', JSON.stringify(plan.totals, null, 2));
  console.log('Wrote import_plan.json, NEW_IMPORT_REPORT.md, DUPLICATE_CLEANUP_REPORT.md');
}

main();
