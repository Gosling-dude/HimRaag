/**
 * HimRaag local-audio scanner & metadata extractor.
 *
 * Recursively scans a folder for audio files (.mp3 .wav .m4a .aac .flac),
 * extracts embedded metadata + technical info, classifies metadata quality,
 * and writes:
 *   - scripts/seed_data/scan_result.json   (machine-readable, feeds import)
 *   - IMPORT_REPORT.md                      (per-file technical + tag report)
 *   - METADATA_QUALITY_REPORT.md            (complete/partial/missing buckets)
 *
 * Usage:
 *   node scripts/scan_audio.js "D:\\Personal Projects\\HimRaag\\music"
 *
 * No ffprobe/python required — uses the `music-metadata` parser.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const mm = require('music-metadata');

const AUDIO_EXT = new Set(['.mp3', '.wav', '.m4a', '.aac', '.flac']);
const ROOT = process.cwd();

function walk(dir) {
  const out = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) out.push(...walk(full));
    else if (AUDIO_EXT.has(path.extname(entry.name).toLowerCase())) out.push(full);
  }
  return out;
}

function fmtDuration(seconds) {
  if (!Number.isFinite(seconds) || seconds <= 0) return '00:00';
  const total = Math.round(seconds);
  const m = Math.floor(total / 60);
  const s = total % 60;
  return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}`;
}

function fmtSize(bytes) {
  const mb = bytes / (1024 * 1024);
  return `${mb.toFixed(2)} MB`;
}

function nonEmpty(v) {
  return v !== undefined && v !== null && String(v).trim() !== '';
}

async function extract(file) {
  const stat = fs.statSync(file);
  const result = {
    fullPath: file,
    filename: path.basename(file),
    ext: path.extname(file).toLowerCase(),
    fileSize: stat.size,
    fileSizeHuman: fmtSize(stat.size),
    durationSec: null,
    durationHuman: '00:00',
    bitrate: null,
    bitrateHuman: 'unknown',
    codec: 'unknown',
    sampleRate: null,
    title: null,
    artist: null,
    album: null,
    albumArtist: null,
    year: null,
    genre: null,
    hasArtwork: false,
    parseError: null,
  };

  try {
    const meta = await mm.parseFile(file, { duration: true });
    const f = meta.format || {};
    const c = meta.common || {};

    result.durationSec = f.duration ?? null;
    result.durationHuman = fmtDuration(f.duration);
    result.bitrate = f.bitrate ? Math.round(f.bitrate) : null;
    result.bitrateHuman = f.bitrate ? `${Math.round(f.bitrate / 1000)} kbps` : 'unknown';
    result.codec = f.codec || f.container || 'unknown';
    result.sampleRate = f.sampleRate ?? null;

    result.title = nonEmpty(c.title) ? c.title.trim() : null;
    result.artist = nonEmpty(c.artist) ? c.artist.trim() : null;
    result.album = nonEmpty(c.album) ? c.album.trim() : null;
    result.albumArtist = nonEmpty(c.albumartist) ? c.albumartist.trim() : null;
    result.year = Number.isFinite(c.year) ? c.year : null;
    result.genre = Array.isArray(c.genre) && c.genre.length ? c.genre[0] : null;
    result.hasArtwork = Array.isArray(c.picture) && c.picture.length > 0;
  } catch (e) {
    result.parseError = e.message;
  }
  return result;
}

function classify(r) {
  const core = ['title', 'artist', 'album'];
  const present = core.filter((k) => nonEmpty(r[k])).length;
  if (present === core.length) return 'complete';
  if (present === 0) return 'missing';
  return 'partial';
}

function rel(p) {
  return path.relative(ROOT, p).replace(/\\/g, '/');
}

async function main() {
  const folder = process.argv[2];
  if (!folder || !fs.existsSync(folder)) {
    console.error(`Folder not found: ${folder}`);
    process.exit(1);
  }

  const files = walk(folder).sort();
  console.log(`Scanning ${files.length} audio file(s) under ${folder}\n`);

  const records = [];
  for (const file of files) {
    const r = await extract(file);
    r.quality = classify(r);
    records.push(r);
    console.log(
      `  ${r.quality.padEnd(8)} | ${r.durationHuman} | ${r.bitrateHuman.padEnd(9)} | ${r.filename}`
    );
  }

  // ─── scan_result.json ───────────────────────────────────────────────────────
  const outDir = path.join(__dirname, 'seed_data');
  fs.mkdirSync(outDir, { recursive: true });
  fs.writeFileSync(
    path.join(outDir, 'scan_result.json'),
    JSON.stringify({ scannedAt: new Date().toISOString(), folder, count: records.length, records }, null, 2)
  );

  const counts = {
    complete: records.filter((r) => r.quality === 'complete').length,
    partial: records.filter((r) => r.quality === 'partial').length,
    missing: records.filter((r) => r.quality === 'missing').length,
  };

  // ─── IMPORT_REPORT.md ─────────────────────────────────────────────────────────
  let imp = `# HimRaag — Audio Import Report\n\n`;
  imp += `_Generated: ${new Date().toISOString()}_\n\n`;
  imp += `**Source folder:** \`${folder}\`\n\n`;
  imp += `**Files found:** ${records.length} `;
  imp += `(complete: ${counts.complete}, partial: ${counts.partial}, missing: ${counts.missing})\n\n`;
  imp += `Extensions scanned: .mp3 .wav .m4a .aac .flac\n\n`;
  imp += `---\n\n`;

  records.forEach((r, i) => {
    imp += `## ${i + 1}. ${r.filename}\n\n`;
    imp += `| Field | Value |\n|---|---|\n`;
    imp += `| Full path | \`${r.fullPath}\` |\n`;
    imp += `| Filename | ${r.filename} |\n`;
    imp += `| Duration | ${r.durationHuman} |\n`;
    imp += `| File size | ${r.fileSizeHuman} (${r.fileSize} bytes) |\n`;
    imp += `| Bitrate | ${r.bitrateHuman} |\n`;
    imp += `| Codec | ${r.codec} |\n`;
    imp += `| Sample rate | ${r.sampleRate ? r.sampleRate + ' Hz' : 'unknown'} |\n`;
    imp += `| Embedded title | ${r.title ?? '— (missing)'} |\n`;
    imp += `| Embedded artist | ${r.artist ?? '— (missing)'} |\n`;
    imp += `| Embedded album | ${r.album ?? '— (missing)'} |\n`;
    imp += `| Year | ${r.year ?? '— (missing)'} |\n`;
    imp += `| Genre | ${r.genre ?? '— (missing)'} |\n`;
    imp += `| Embedded artwork | ${r.hasArtwork ? 'present' : 'not present'} |\n`;
    imp += `| Metadata quality | **${r.quality}** |\n`;
    if (r.parseError) imp += `| Parse error | ${r.parseError} |\n`;
    imp += `\n`;
  });

  fs.writeFileSync(path.join(ROOT, 'IMPORT_REPORT.md'), imp);

  // ─── METADATA_QUALITY_REPORT.md ───────────────────────────────────────────────
  let q = `# HimRaag — Metadata Quality Report\n\n`;
  q += `_Generated: ${new Date().toISOString()}_\n\n`;
  q += `**Total files:** ${records.length}\n\n`;
  q += `| Bucket | Count | Definition |\n|---|---|---|\n`;
  q += `| ✅ Complete | ${counts.complete} | embedded title **and** artist **and** album |\n`;
  q += `| ⚠️ Partial | ${counts.partial} | some but not all of title/artist/album |\n`;
  q += `| ❌ Missing | ${counts.missing} | none of title/artist/album embedded |\n\n`;
  q += `---\n\n`;

  const summaryRow = (r) =>
    `| ${r.filename} | ${r.title ?? '—'} | ${r.artist ?? '—'} | ${r.album ?? '—'} | ` +
    `${r.year ?? '—'} | ${r.genre ?? '—'} | ${r.hasArtwork ? 'yes' : 'no'} | ${r.durationHuman} |`;

  for (const bucket of ['complete', 'partial', 'missing']) {
    const rows = records.filter((r) => r.quality === bucket);
    const label = { complete: '✅ Complete metadata', partial: '⚠️ Partial metadata', missing: '❌ Missing metadata' }[bucket];
    q += `## ${label} (${rows.length})\n\n`;
    if (!rows.length) {
      q += `_None._\n\n`;
      continue;
    }
    q += `| File | Title | Artist | Album | Year | Genre | Art | Duration |\n`;
    q += `|---|---|---|---|---|---|---|---|\n`;
    rows.forEach((r) => (q += summaryRow(r) + '\n'));
    q += `\n`;
  }

  // What needs fixing
  q += `---\n\n## Fields needing review\n\n`;
  const need = (pred) => records.filter(pred).map((r) => r.filename);
  const list = (arr) => (arr.length ? arr.map((f) => `- ${f}`).join('\n') : '_none_');
  q += `### Missing artist (${need((r) => !r.artist).length})\n${list(need((r) => !r.artist))}\n\n`;
  q += `### Missing album (${need((r) => !r.album).length})\n${list(need((r) => !r.album))}\n\n`;
  q += `### Missing title (${need((r) => !r.title).length})\n${list(need((r) => !r.title))}\n\n`;
  q += `### Missing artwork (${need((r) => !r.hasArtwork).length})\n${list(need((r) => !r.hasArtwork))}\n\n`;
  q += `### Missing year (${need((r) => !r.year).length})\n${list(need((r) => !r.year))}\n\n`;
  q += `### Missing genre (${need((r) => !r.genre).length})\n${list(need((r) => !r.genre))}\n\n`;
  q += `> **Region** and **Language** are never embedded in audio tags — every imported `;
  q += `track is flagged \`region = Needs Review\`, \`language = Needs Review\` and must be `;
  q += `assigned from the Admin Dashboard.\n`;

  fs.writeFileSync(path.join(ROOT, 'METADATA_QUALITY_REPORT.md'), q);

  console.log(`\nSummary: complete=${counts.complete}  partial=${counts.partial}  missing=${counts.missing}`);
  console.log(`Wrote: IMPORT_REPORT.md, METADATA_QUALITY_REPORT.md, scripts/seed_data/scan_result.json`);
}

main().catch((e) => {
  console.error('Scan failed:', e);
  process.exit(1);
});
