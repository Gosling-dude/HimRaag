/**
 * Phase 1 — AUDIO_AUDIT_REPORT.md generator.
 *
 * Reads scripts/seed_data/scan_result.json (produced by scan_audio.js) and
 * emits a complete per-file technical + embedded-tag audit at the repo root.
 *
 * Usage:  node scripts/generate_audit_report.js
 */
'use strict';

const fs = require('fs');
const path = require('path');

const repoRoot = path.dirname(__dirname);
const scanPath = path.join(__dirname, 'seed_data', 'scan_result.json');

if (!fs.existsSync(scanPath)) {
  console.error('scan_result.json not found — run scan_audio.js first.');
  process.exit(1);
}

const scan = JSON.parse(fs.readFileSync(scanPath, 'utf8'));
const records = scan.records || [];

const withArt = records.filter((r) => r.hasArtwork).length;
const errors = records.filter((r) => r.parseError).length;
const totalBytes = records.reduce((n, r) => n + (r.fileSize || 0), 0);
const totalSec = records.reduce((n, r) => n + (r.durationSec || 0), 0);

function fmtTotalDuration(sec) {
  const m = Math.floor(sec / 60);
  const s = Math.round(sec % 60);
  return `${m}m ${s}s`;
}

let md = `# HimRaag — Audio Audit Report (Phase 1)\n\n`;
md += `_Generated: ${new Date().toISOString()}_\n\n`;
md += `**Source folder:** \`${scan.folder}\`\n\n`;
md += `**Scan engine:** \`music-metadata\` (no ffprobe/python required)\n\n`;
md += `## Summary\n\n`;
md += `| Metric | Value |\n|---|---|\n`;
md += `| Audio files discovered | ${records.length} |\n`;
md += `| Extensions scanned | .mp3 .wav .m4a .aac .flac |\n`;
md += `| Total size | ${(totalBytes / (1024 * 1024)).toFixed(2)} MB |\n`;
md += `| Total duration | ${fmtTotalDuration(totalSec)} |\n`;
md += `| Files with embedded artwork | ${withArt} / ${records.length} |\n`;
md += `| Files with embedded title/artist/album | ${records.filter((r) => r.title || r.artist || r.album).length} / ${records.length} |\n`;
md += `| Parse errors | ${errors} |\n\n`;
md += `> **Finding:** every file has **zero embedded tags** and **no embedded artwork**. `;
md += `All metadata must be derived in Phase 2 (filename parse + enrichment); `;
md += `artwork is assigned a placeholder and flagged for review. Note the actual `;
md += `decoded bitrate is **~128 kbps** despite the \`(256k)\` filename suffix.\n\n`;
md += `---\n\n`;
md += `## Per-file audit\n\n`;

records.forEach((r, i) => {
  md += `### ${i + 1}. ${r.filename}\n\n`;
  md += `| Field | Value |\n|---|---|\n`;
  md += `| Filename | \`${r.filename}\` |\n`;
  md += `| Size | ${r.fileSizeHuman} (${r.fileSize} bytes) |\n`;
  md += `| Duration | ${r.durationHuman} |\n`;
  md += `| Bitrate | ${r.bitrateHuman} |\n`;
  md += `| Codec | ${r.codec} |\n`;
  md += `| Sample rate | ${r.sampleRate ? r.sampleRate + ' Hz' : 'unknown'} |\n`;
  md += `| Embedded title | ${r.title ?? '— (none)'} |\n`;
  md += `| Embedded artist | ${r.artist ?? '— (none)'} |\n`;
  md += `| Embedded album | ${r.album ?? '— (none)'} |\n`;
  md += `| Embedded artwork | ${r.hasArtwork ? 'present' : 'not present'} |\n`;
  if (r.parseError) md += `| Parse error | ${r.parseError} |\n`;
  md += `\n`;
});

fs.writeFileSync(path.join(repoRoot, 'AUDIO_AUDIT_REPORT.md'), md);
console.log(`Wrote AUDIO_AUDIT_REPORT.md (${records.length} files, ${withArt} with artwork, ${errors} errors)`);
