/**
 * Phase 2 — Metadata enrichment + confidence scoring.
 *
 * Reads scripts/seed_data/scan_result.json (Phase 1). Embedded tags are absent
 * for every file, so metadata is derived from the (information-rich) filenames
 * with a per-field confidence score and a recorded source. Region/language/
 * artist hints in the filenames ("Kumauni Song", "Garhwali", "Jaunsari",
 * "by Surinder Sharma", "Lalit Mohan Joshi", …) are mapped to the canonical
 * taxonomy in scripts/lib/constants.js.
 *
 * Field-resolution policy (per the task):
 *   1. embedded tag        → trust it            (source: "embedded", conf 1.0)
 *   2. else filename token → parse it            (source: "filename",  conf .6–.95)
 *   3. else curated/web    → public-knowledge map (source: "web",      conf .8)
 *   4. else placeholder    → Unknown/Needs Review (source: "placeholder", conf 0)
 *
 * reviewRequired = true when any CORE field (artist, region, language) is below
 * the confidence threshold, OR artwork is missing (always, here).
 *
 * Outputs:
 *   scripts/seed_data/enriched.json   (machine-readable, feeds catalog + R2 + Firestore)
 *   METADATA_ENRICHMENT_REPORT.md     (human report: confidence + source + inferred fields)
 *
 * Usage:  node scripts/enrich_metadata.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { slugify, songId, artistId, albumId } = require('./lib/validator');
const { NEEDS_REVIEW, REGIONS, LANGUAGES, GENRES } = require('./lib/constants');

const repoRoot = path.dirname(__dirname);
const SCAN = path.join(__dirname, 'seed_data', 'scan_result.json');
const OUT = path.join(__dirname, 'seed_data', 'enriched.json');

const PLACEHOLDER_ARTIST = 'Unknown Artist';
const PLACEHOLDER_ALBUM = 'Imported Recordings';
const CONF_THRESHOLD = 0.6; // core fields below this → reviewRequired

// ── Noise tokens stripped when cleaning a display title ──────────────────────
const NOISE = [
  'slowed', 'reverb', 'reverbed', '8d', '8d audio', '8d song', 'lofi',
  'lofi version', 'lofi song', 'cover song', 'reprise', 'car drive mix',
  'heavy bass', 'latest', 'dj song', 'dj', 'song', 'official', 'video',
  'audio', 'mix', 'remix', 'full', 'hd', 'new', 'prod', 'feat', 'ft',
  'the retro lab', 'y series', 'oreio beats', 'folk tone 3', 'letest',
  'nati', 'pahari', 'pahadi', 'himachali', 'kumauni', 'kumaoni', 'garhwali',
  'jaunsari', 'kinnauri', 'reprise 2026',
];

// ── Region / language keyword detection (token → canonical) ──────────────────
const REGION_KEYWORDS = [
  [/kinnaur|kinnauri/i, 'Kinnauri'],
  [/jaunsar|jaunsari/i, 'Jaunsari'],
  [/garhwal|garhwali|gadwali/i, 'Garhwali'],
  [/kumaun|kumaoni|kumauni/i, 'Kumaoni'],
  [/sirmaur|sirmauri/i, 'Sirmauri'],
  [/himachal|himachali|pahari|nati|pahadi/i, 'Himachali'],
];

// Place-name → region hints (used when no explicit region keyword present).
const PLACE_HINTS = [
  [/rohru/i, 'Himachali'], // Rohru, Shimla
  [/satpuli/i, 'Garhwali'], // Satpuli, Pauri Garhwal
];

const GENRE_KEYWORDS = [
  [/devta|devi|bhakti|jai\s|jagar|bhajan/i, 'Devotional'],
  [/mela|jatre|jatra|fair/i, 'Festival'],
  [/shaadi|byah|wedding/i, 'Wedding'],
];

/**
 * Curated knowledge derived from the filename tokens + public familiarity with
 * the Uttarakhandi/Himachali folk scene. `source: 'filename'` = the value is
 * explicitly written in the filename; `source: 'web'` = inferred from
 * publicly-known artist/region association (no audio downloaded). Keyed by the
 * slug of the raw filename (stable, deterministic).
 */
const CURATED = {
  // explicit "Kinnauri Cover Song"
  'ang-songi-kinnauri-cover-song-reprise-2026-256k': {
    artist: null, region: 'Kinnauri', language: 'Kinnauri', year: 2026,
    aSrc: 'placeholder', rSrc: 'filename', lSrc: 'filename', ySrc: 'filename',
  },
  // "Pahari Jaunsari Dj Song 2021 … Sardar Singh Sharma … Himachali"
  'baadri-latest-pahari-jaunsari-dj-song-2021-sardar-singh-sharma-himachali-song-y-': {
    artist: 'Sardar Singh Sharma', region: 'Jaunsari', language: 'Jaunsari', year: 2021,
    aSrc: 'filename', rSrc: 'filename', lSrc: 'filename', ySrc: 'filename',
  },
  // "Kumauni Song … Lalit Mohan Joshi"
  'dhire-dhire-o-chanda-kumauni-song-lalit-mohan-joshi-lofi-song-slowed-reverb-paha': {
    artist: 'Lalit Mohan Joshi', region: 'Kumaoni', language: 'Kumaoni', year: null,
    aSrc: 'filename', rSrc: 'filename', lSrc: 'filename', ySrc: 'placeholder',
  },
  // "Himachali Song … Palak,Hardik … 2026 (Oreio Beats)"
  'kolang-oreio-beats-latest-pahadi-song-2026-himachali-song-palak-hardik-256k': {
    artist: 'Palak, Hardik', region: 'Himachali', language: 'Himachali', year: 2026,
    aSrc: 'filename', rSrc: 'filename', lSrc: 'filename', ySrc: 'filename',
  },
  // "Kumaoni Song … Diksha Dhaundiyal … Pooja Dhaundiyal"
  'main-pahadan-kumaoni-song-diksha-dhaundiyal-pooja-dhaundiyal-slowed-reverb-256k': {
    artist: 'Diksha Dhaundiyal, Pooja Dhaundiyal', region: 'Kumaoni', language: 'Kumaoni', year: null,
    aSrc: 'filename', rSrc: 'filename', lSrc: 'filename', ySrc: 'placeholder',
  },
  // "Garhwali Song … Rohit Chauhan" — Satpuli ka Mela → Festival
  'satpuli-ka-mela-garhwali-song-rohit-chauhan-slowed-reverbed-8d-song-256k': {
    artist: 'Rohit Chauhan', region: 'Garhwali', language: 'Garhwali', year: null,
    aSrc: 'filename', rSrc: 'filename', lSrc: 'filename', ySrc: 'placeholder',
  },
  // "Thakur Dass Rathi … The Retro Lab" — Rathi → Himachali (Sirmaur/Shimla belt)
  'sushma-meri-janiye-car-drive-mix-heavy-bass-thakur-dass-rathi-the-retro-lab-256k': {
    artist: 'Thakur Dass Rathi', region: 'Himachali', language: 'Himachali', year: null,
    aSrc: 'filename', rSrc: 'web', lSrc: 'web', ySrc: 'placeholder',
  },
  // "Jitendra Tomkyal … Kumauni Song"
  'teri-surmyali-aankhi-jitendra-tomkyal-kumauni-song-lofi-version-slowed-reverbed-': {
    artist: 'Jitendra Tomkyal', region: 'Kumaoni', language: 'Kumaoni', year: null,
    aSrc: 'filename', rSrc: 'filename', lSrc: 'filename', ySrc: 'placeholder',
  },
  // "Seema Raniye … letest pahadi nati 2024 … by surinder Sharma"
  'driver-horon-bajade-ho-seema-raniye-letest-pahadi-nati-2024-folk-tone-3-by-surin': {
    artist: 'Surinder Sharma', region: 'Himachali', language: 'Himachali', year: 2024,
    aSrc: 'filename', rSrc: 'filename', lSrc: 'filename', ySrc: 'filename',
  },
  // "Rekha … Prod Zorawar Hunk" (producer, not necessarily the singer)
  'rekha-prod-zorawar-hunk-256k': {
    artist: 'Zorawar Hunk', region: 'Himachali', language: 'Pahadi', year: null,
    aSrc: 'web', rSrc: 'web', lSrc: 'web', ySrc: 'placeholder',
  },
  // "Jumi Jimi O Rohru Ri Jatre" — Rohru (Shimla) + Jatre (fair)
  'jumi-jimi-o-rohru-ri-jatre-256k': {
    artist: null, region: 'Himachali', language: 'Himachali', year: null,
    aSrc: 'placeholder', rSrc: 'web', lSrc: 'web', ySrc: 'placeholder',
  },
  // web: Sanjay Sharma, PahariSong Records, 2022 (specific, single attribution)
  'fukla-chane-bindiya-256k': {
    artist: 'Sanjay Sharma', region: 'Himachali', language: 'Pahadi', year: 2022,
    aSrc: 'web', rSrc: 'web', lSrc: 'web', ySrc: 'web',
  },
  // web: well-known Himachali Pahari Nati (multiple versions — region only)
  'bamniye-256k': {
    artist: null, region: 'Himachali', language: 'Pahadi', year: null,
    aSrc: 'placeholder', rSrc: 'web', lSrc: 'web', ySrc: 'placeholder',
  },
  // web: "Meri Salma" Pahari Nati (Spotify) — region only
  'meri-salma-256k': {
    artist: null, region: 'Himachali', language: 'Pahadi', year: null,
    aSrc: 'placeholder', rSrc: 'web', lSrc: 'web', ySrc: 'placeholder',
  },
  // web: Himachali Pahari (multiple versions) — region only
  'jhuriye-256k': {
    artist: null, region: 'Himachali', language: 'Pahadi', year: null,
    aSrc: 'placeholder', rSrc: 'web', lSrc: 'web', ySrc: 'placeholder',
  },
  // web: Himachali/UK Pahari (Oreio Beats) — region only
  'jhauliye-256k': {
    artist: null, region: 'Himachali', language: 'Pahadi', year: null,
    aSrc: 'placeholder', rSrc: 'web', lSrc: 'web', ySrc: 'placeholder',
  },
  // web: Himachali Pahari devotional ("Devta") — region only, genre→Devotional
  'jai-bolya-devta-256k': {
    artist: null, region: 'Himachali', language: 'Pahadi', year: null,
    aSrc: 'placeholder', rSrc: 'web', lSrc: 'web', ySrc: 'placeholder',
  },
};

function rawKey(filename) {
  return slugify(filename.replace(/\.[^.]+$/, ''));
}

function cleanTitle(filename) {
  // The display title is the FIRST segment before a multi-delimiter break.
  let base = filename.replace(/\.[^.]+$/, '');
  base = base.replace(/\(?\d{2,3}k\)?/gi, ' '); // strip "(256k)"
  // Split on runs of underscores/dashes that act as section separators.
  let head = base.split(/_{2,}|\s-\s|__+/)[0];
  head = head.replace(/[_]+/g, ' ');
  // Drop devanagari duplicate (e.g. "Main Pahadan मैं पहाड़न" keeps roman).
  head = head.replace(/[ऀ-ॿ]+/g, ' ');
  head = head.replace(/[#🚘]+/g, ' ');
  // Remove trailing noise words.
  let words = head.split(/\s+/).filter(Boolean);
  while (words.length > 1 && NOISE.includes(words[words.length - 1].toLowerCase())) {
    words.pop();
  }
  let t = words.join(' ').replace(/\s{2,}/g, ' ').trim();
  // Title-case lightly (keep existing capitals).
  t = t.replace(/\b([a-z])/g, (m, c) => c.toUpperCase());
  return t || base.trim();
}

function detect(list, hay) {
  for (const [re, val] of list) if (re.test(hay)) return val;
  return null;
}

function enrichOne(r) {
  const key = rawKey(r.filename);
  const hay = r.filename;
  const cur = CURATED[key] || {};
  const fields = {};

  // ── Title ──────────────────────────────────────────────────────────────
  const title = r.title || cleanTitle(r.filename);
  fields.title = { value: title, source: r.title ? 'embedded' : 'filename', conf: r.title ? 1 : 0.9 };

  // ── Artist ─────────────────────────────────────────────────────────────
  let artist = r.artist || cur.artist || null;
  let aSrc = r.artist ? 'embedded' : (cur.artist ? (cur.aSrc || 'filename') : 'placeholder');
  let aConf = r.artist ? 1 : (cur.artist ? (cur.aSrc === 'web' ? 0.8 : 0.9) : 0);
  if (!artist) { artist = PLACEHOLDER_ARTIST; }
  fields.artist = { value: artist, source: aSrc, conf: aConf };

  // ── Region ─────────────────────────────────────────────────────────────
  let region = cur.region || detect(REGION_KEYWORDS, hay) || detect(PLACE_HINTS, hay);
  let rSrc = cur.region ? (cur.rSrc || 'filename')
    : (detect(REGION_KEYWORDS, hay) ? 'filename' : (detect(PLACE_HINTS, hay) ? 'web' : 'placeholder'));
  let rConf = region ? (rSrc === 'web' ? 0.7 : 0.9) : 0;
  if (!region) { region = NEEDS_REVIEW; }
  fields.region = { value: region, source: rSrc, conf: rConf };

  // ── Language ───────────────────────────────────────────────────────────
  let language = cur.language || detect(REGION_KEYWORDS, hay);
  let lSrc = cur.language ? (cur.lSrc || 'filename') : (detect(REGION_KEYWORDS, hay) ? 'filename' : 'placeholder');
  // Himachali region default language → Pahadi unless an explicit dialect named.
  let lConf = language ? (lSrc === 'web' ? 0.7 : 0.9) : 0;
  if (!language) { language = NEEDS_REVIEW; }
  fields.language = { value: language, source: lSrc, conf: lConf };

  // ── Year ───────────────────────────────────────────────────────────────
  const yMatch = hay.match(/\b(19\d{2}|20[0-3]\d)\b/);
  let year = (cur.year != null ? cur.year : (yMatch ? parseInt(yMatch[1], 10) : null));
  let ySrc = cur.year != null ? (cur.ySrc || 'filename') : (yMatch ? 'filename' : 'placeholder');
  fields.year = { value: year, source: ySrc, conf: year ? (ySrc === 'filename' ? 0.85 : 0.5) : 0 };

  // ── Genre ──────────────────────────────────────────────────────────────
  let genre = detect(GENRE_KEYWORDS, hay) || 'Folk';
  let gSrc = detect(GENRE_KEYWORDS, hay) ? 'filename' : 'default';
  fields.genre = { value: genre, source: gSrc, conf: gSrc === 'filename' ? 0.8 : 0.4 };

  // ── Album: group by artist (real artists get an album per artist;
  //     placeholder-artist tracks share "Imported Recordings"). ───────────
  const albumTitle = artist === PLACEHOLDER_ARTIST
    ? PLACEHOLDER_ALBUM
    : `${title}`; // single track → its own single; review can regroup
  fields.album = {
    value: artist === PLACEHOLDER_ARTIST ? PLACEHOLDER_ALBUM : 'Singles',
    source: 'derived', conf: 0.5,
  };

  // ── Review flag ─────────────────────────────────────────────────────────
  const coreConf = [fields.artist.conf, fields.region.conf, fields.language.conf];
  const lowCore = coreConf.some((c) => c < CONF_THRESHOLD);
  const reviewRequired = lowCore || !r.hasArtwork; // artwork always missing here
  const reviewReasons = [];
  if (fields.artist.conf < CONF_THRESHOLD) reviewReasons.push('artist uncertain');
  if (fields.region.conf < CONF_THRESHOLD) reviewReasons.push('region uncertain');
  if (fields.language.conf < CONF_THRESHOLD) reviewReasons.push('language uncertain');
  if (!r.hasArtwork) reviewReasons.push('artwork is placeholder');

  const overall = (
    fields.title.conf + fields.artist.conf + fields.region.conf +
    fields.language.conf + fields.genre.conf
  ) / 5;

  return {
    sourceFile: r.fullPath,
    filename: r.filename,
    durationMs: Math.round((r.durationSec || 0) * 1000),
    title: fields.title.value,
    artistName: fields.artist.value,
    albumTitle: fields.album.value === 'Singles' ? `${fields.title.value}` : PLACEHOLDER_ALBUM,
    region: fields.region.value,
    language: fields.language.value,
    genre: fields.genre.value,
    releaseYear: fields.year.value,
    hasArtwork: !!r.hasArtwork,
    reviewRequired,
    reviewReasons,
    overallConfidence: Number(overall.toFixed(2)),
    fields, // per-field {value, source, conf}
  };
}

function main() {
  if (!fs.existsSync(SCAN)) {
    console.error('scan_result.json not found — run scan_audio.js first.');
    process.exit(1);
  }
  const scan = JSON.parse(fs.readFileSync(SCAN, 'utf8'));
  const enriched = (scan.records || []).map(enrichOne);

  // Stable ids/slugs (mirror the validator helpers used downstream).
  enriched.forEach((e) => {
    e.slug = slugify(e.title);
    e.id = songId(e.artistName, e.title);
    e.artistId = artistId(e.artistName);
    e.albumId = albumId(e.artistName, e.albumTitle);
  });

  fs.writeFileSync(OUT, JSON.stringify({
    generatedAt: new Date().toISOString(),
    source: scan.folder,
    count: enriched.length,
    confidenceThreshold: CONF_THRESHOLD,
    tracks: enriched,
  }, null, 2));

  writeReport(enriched, scan.folder);

  const needReview = enriched.filter((e) => e.reviewRequired).length;
  const idArtists = new Set(enriched.map((e) => e.artistId)).size;
  console.log(`Enriched ${enriched.length} tracks → ${path.relative(repoRoot, OUT)}`);
  console.log(`  distinct artists: ${idArtists} | reviewRequired: ${needReview}`);
  console.log(`  Wrote METADATA_ENRICHMENT_REPORT.md`);
}

function srcBadge(s) {
  return { embedded: '🎯 embedded', filename: '📄 filename', web: '🌐 web', derived: '🧮 derived', default: '⚙️ default', placeholder: '🚧 placeholder' }[s] || s;
}

function writeReport(rows, folder) {
  const known = rows.filter((r) => r.artistName !== PLACEHOLDER_ARTIST).length;
  const review = rows.filter((r) => r.reviewRequired).length;
  let md = `# HimRaag — Metadata Enrichment Report (Phase 2)\n\n`;
  md += `_Generated: ${new Date().toISOString()}_\n\n`;
  md += `**Source:** \`${folder}\`\n\n`;
  md += `**Method:** embedded tags were absent for all files, so every field is `;
  md += `derived from filename tokens, mapped to the canonical taxonomy `;
  md += `(\`scripts/lib/constants.js\`). Publicly-known artist↔region associations `;
  md += `fill a few gaps (source \`🌐 web\`). **No audio was downloaded.**\n\n`;
  md += `## Summary\n\n`;
  md += `| Metric | Value |\n|---|---|\n`;
  md += `| Tracks enriched | ${rows.length} |\n`;
  md += `| Artist identified (non-placeholder) | ${known} / ${rows.length} |\n`;
  md += `| Flagged \`reviewRequired=true\` | ${review} / ${rows.length} |\n`;
  md += `| Confidence threshold (core fields) | ${CONF_THRESHOLD} |\n\n`;
  md += `**Source legend:** 🎯 embedded · 📄 filename · 🌐 web · 🧮 derived · ⚙️ default · 🚧 placeholder\n\n`;
  md += `---\n\n`;
  md += `## Per-track enrichment\n\n`;

  rows.forEach((r, i) => {
    md += `### ${i + 1}. ${r.title}\n\n`;
    md += `\`${r.filename}\`\n\n`;
    md += `Overall confidence: **${r.overallConfidence}** · reviewRequired: **${r.reviewRequired}**`;
    if (r.reviewReasons.length) md += ` (${r.reviewReasons.join('; ')})`;
    md += `\n\n`;
    md += `| Field | Value | Source | Confidence |\n|---|---|---|---|\n`;
    md += `| Title | ${r.fields.title.value} | ${srcBadge(r.fields.title.source)} | ${r.fields.title.conf} |\n`;
    md += `| Artist | ${r.fields.artist.value} | ${srcBadge(r.fields.artist.source)} | ${r.fields.artist.conf} |\n`;
    md += `| Region | ${r.fields.region.value} | ${srcBadge(r.fields.region.source)} | ${r.fields.region.conf} |\n`;
    md += `| Language | ${r.fields.language.value} | ${srcBadge(r.fields.language.source)} | ${r.fields.language.conf} |\n`;
    md += `| Genre | ${r.fields.genre.value} | ${srcBadge(r.fields.genre.source)} | ${r.fields.genre.conf} |\n`;
    md += `| Year | ${r.fields.year.value ?? '—'} | ${srcBadge(r.fields.year.source)} | ${r.fields.year.conf} |\n`;
    md += `| Album | ${r.albumTitle} | ${srcBadge('derived')} | 0.5 |\n`;
    md += `\n`;
  });

  fs.writeFileSync(path.join(repoRoot, 'METADATA_ENRICHMENT_REPORT.md'), md);
}

main();
