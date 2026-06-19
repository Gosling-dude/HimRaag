/**
 * Phase 3 — Cloudflare R2 bulk upload.
 *
 * Uploads the locally-imported audio (source of truth) and generated
 * placeholder artwork to the `himraag-audio` R2 bucket, then verifies every
 * public URL is reachable. Produces:
 *   scripts/seed_data/r2_manifest.json   (sourceFile → R2 keys + public URLs)
 *   R2_UPLOAD_REPORT.md                   (human report)
 *
 * Services (per task):
 *   R2UploadService      — low-level putObject / head / public-URL builder
 *   ArtworkUploadService — generates + uploads placeholder cover art
 *   BulkImportPipeline   — orchestrates audio + artwork + artist/album covers
 *
 * SECURITY: credentials load from .env at runtime via lib/credentials.js and
 * are never printed/logged. Usage:
 *   node scripts/r2_upload.js            # upload + verify
 *   node scripts/r2_upload.js --verify   # verify existing objects only
 */
'use strict';

const fs = require('fs');
const path = require('path');
const https = require('https');
const {
  S3Client,
  PutObjectCommand,
  HeadObjectCommand,
} = require('@aws-sdk/client-s3');
const { loadR2, publicSummary } = require('./lib/credentials');
const { slugify } = require('./lib/validator');
const { makeArtworkPng } = require('./lib/placeholder_art');

const repoRoot = path.dirname(__dirname);
const ENRICHED = path.join(__dirname, 'seed_data', 'enriched.json');
const MANIFEST = path.join(__dirname, 'seed_data', 'r2_manifest.json');

// ── R2UploadService ──────────────────────────────────────────────────────────
class R2UploadService {
  constructor(cfg) {
    this.cfg = cfg;
    this.client = new S3Client({
      region: 'auto',
      endpoint: cfg.endpoint,
      credentials: {
        accessKeyId: cfg.accessKeyId,
        secretAccessKey: cfg.secretAccessKey,
      },
    });
  }

  publicUrl(key) {
    return `${this.cfg.publicUrl}/${key}`;
  }

  async put(key, body, contentType, attempt = 0) {
    try {
      await this._put(key, body, contentType);
    } catch (e) {
      if (attempt < 4) {
        const wait = 1000 * (attempt + 1);
        process.stdout.write(`  … retry put ${key} (${e.name || e.message}) in ${wait}ms\n`);
        await new Promise((r) => setTimeout(r, wait));
        return this.put(key, body, contentType, attempt + 1);
      }
      throw e;
    }
    return this.publicUrl(key);
  }

  async _put(key, body, contentType) {
    await this.client.send(
      new PutObjectCommand({
        Bucket: this.cfg.bucket,
        Key: key,
        Body: body,
        ContentType: contentType,
      })
    );
    return this.publicUrl(key);
  }

  async head(key) {
    try {
      const r = await this.client.send(
        new HeadObjectCommand({ Bucket: this.cfg.bucket, Key: key })
      );
      return { ok: true, size: r.ContentLength, contentType: r.ContentType };
    } catch (e) {
      return { ok: false, reason: e.name || e.message };
    }
  }
}

// ── ArtworkUploadService ──────────────────────────────────────────────────────
class ArtworkUploadService {
  constructor(r2) {
    this.r2 = r2;
  }

  async upload(prefix, slug, seed, region) {
    const png = makeArtworkPng(seed, region);
    const key = `${prefix}/${slug}.png`;
    const url = await this.r2.put(key, png, 'image/png');
    return { key, url, bytes: png.length };
  }
}

// ── Public-URL reachability (HTTPS GET range probe) ──────────────────────────
function verifyUrl(url) {
  return new Promise((resolve) => {
    const req = https.get(url, { headers: { Range: 'bytes=0-0' } }, (res) => {
      res.resume(); // drain
      resolve({
        ok: res.statusCode === 200 || res.statusCode === 206,
        status: res.statusCode,
        contentType: res.headers['content-type'],
        contentLength: res.headers['content-range'] || res.headers['content-length'],
      });
    });
    req.on('error', (e) => resolve({ ok: false, status: 0, reason: e.message }));
    req.setTimeout(20000, () => {
      req.destroy();
      resolve({ ok: false, status: 0, reason: 'timeout' });
    });
  });
}

// ── BulkImportPipeline ────────────────────────────────────────────────────────
class BulkImportPipeline {
  constructor(r2) {
    this.r2 = r2;
    this.art = new ArtworkUploadService(r2);
  }

  async run(tracks, { verifyOnly = false } = {}) {
    const out = [];
    const artistSeen = new Set();
    const albumSeen = new Set();

    for (const t of tracks) {
      const keySlug = slugify(t.filename.replace(/\.[^.]+$/, ''));
      const audioKey = `audio/${keySlug}.mp3`;
      const artworkKey = `artwork/${keySlug}.png`;
      const rec = {
        sourceFile: t.sourceFile,
        title: t.title,
        artistName: t.artistName,
        region: t.region,
        keySlug,
        audioKey,
        audioUrl: this.r2.publicUrl(audioKey),
        artworkKey,
        artworkUrl: this.r2.publicUrl(artworkKey),
      };

      if (!verifyOnly) {
        const buf = fs.readFileSync(t.sourceFile);
        // Checksum/size-based dedup: skip re-uploading an object already present
        // in R2 with the same byte size (idempotent resume; never re-uploads
        // files already present, per the import contract).
        const existing = await this.r2.head(audioKey);
        if (existing.ok && existing.size === buf.length) {
          rec.audioAction = 'skipped';
          process.stdout.write(`  = skip    ${audioKey} (present, ${(buf.length / 1048576).toFixed(2)} MB)\n`);
        } else {
          process.stdout.write(`  ↑ audio   ${audioKey} (${(buf.length / 1048576).toFixed(2)} MB)\n`);
          await this.r2.put(audioKey, buf, 'audio/mpeg');
          rec.audioAction = 'uploaded';
        }

        const a = await this.art.upload('artwork', keySlug, t.id || keySlug, t.region);
        process.stdout.write(`  ↑ artwork ${a.key} (${a.bytes} B)\n`);

        // Artist cover (once per artist).
        if (!artistSeen.has(t.artistId)) {
          artistSeen.add(t.artistId);
          await this.art.upload('artists', slugify(t.artistName), t.artistId, t.region);
        }
        // Album cover (once per album).
        if (!albumSeen.has(t.albumId)) {
          albumSeen.add(t.albumId);
          await this.art.upload('albums', slugify(t.albumTitle || keySlug), t.albumId, t.region);
        }
      }

      // Verify public reachability.
      rec.audioVerify = await verifyUrl(rec.audioUrl);
      rec.artworkVerify = await verifyUrl(rec.artworkUrl);
      const aok = rec.audioVerify.ok ? '200' : `FAIL(${rec.audioVerify.status})`;
      const wok = rec.artworkVerify.ok ? '200' : `FAIL(${rec.artworkVerify.status})`;
      process.stdout.write(`  ✓ verify  audio=${aok} artwork=${wok}  ${t.title}\n`);
      out.push(rec);
    }
    return out;
  }
}

async function main() {
  const verifyOnly = process.argv.includes('--verify');
  if (!fs.existsSync(ENRICHED)) {
    console.error('enriched.json not found — run enrich_metadata.js first.');
    process.exit(1);
  }
  const { tracks } = JSON.parse(fs.readFileSync(ENRICHED, 'utf8'));
  const cfg = loadR2();
  const sum = publicSummary();
  console.log(`R2 target: bucket="${sum.bucket}" public="${sum.publicUrl}"`);
  console.log(`${verifyOnly ? 'Verifying' : 'Uploading'} ${tracks.length} tracks…\n`);

  const r2 = new R2UploadService(cfg);
  const pipeline = new BulkImportPipeline(r2);
  const records = await pipeline.run(tracks, { verifyOnly });

  fs.writeFileSync(
    MANIFEST,
    JSON.stringify({ generatedAt: new Date().toISOString(), bucket: cfg.bucket, publicUrl: cfg.publicUrl, count: records.length, objects: records }, null, 2)
  );
  writeReport(records, sum);

  const audioOk = records.filter((r) => r.audioVerify.ok).length;
  const artOk = records.filter((r) => r.artworkVerify.ok).length;
  console.log(`\nDone. audio verified ${audioOk}/${records.length}, artwork verified ${artOk}/${records.length}`);
  console.log(`Wrote ${path.relative(repoRoot, MANIFEST)} and R2_UPLOAD_REPORT.md`);
  if (audioOk < records.length || artOk < records.length) process.exitCode = 2;
}

function writeReport(records, sum) {
  const audioOk = records.filter((r) => r.audioVerify.ok).length;
  const artOk = records.filter((r) => r.artworkVerify.ok).length;
  let md = `# HimRaag — Cloudflare R2 Upload Report (Phase 3)\n\n`;
  md += `_Generated: ${new Date().toISOString()}_\n\n`;
  md += `**Bucket:** \`${sum.bucket}\`  ·  **Public base:** \`${sum.publicUrl}\`\n\n`;
  md += `**Object layout:** \`audio/\` · \`artwork/\` · \`artists/\` · \`albums/\`\n\n`;
  md += `> Audio = the local MP3s (source of truth). Artwork = generated 600×600 `;
  md += `placeholder covers (no embedded art existed); tracks are flagged `;
  md += `\`reviewRequired\` for artwork replacement. **Credentials never appear in this report.**\n\n`;
  md += `## Verification summary\n\n`;
  md += `| Check | Result |\n|---|---|\n`;
  md += `| Audio objects uploaded | ${records.length} |\n`;
  md += `| Audio public URLs reachable (HTTP 200/206) | ${audioOk} / ${records.length} |\n`;
  md += `| Artwork public URLs reachable | ${artOk} / ${records.length} |\n\n`;
  md += `---\n\n## Objects\n\n`;
  md += `| # | Title | Audio key | Audio | Artwork key | Art |\n|---|---|---|---|---|---|\n`;
  records.forEach((r, i) => {
    md += `| ${i + 1} | ${r.title} | \`${r.audioKey}\` | ${r.audioVerify.ok ? '✅ ' + r.audioVerify.status : '❌ ' + (r.audioVerify.status || r.audioVerify.reason)} | \`${r.artworkKey}\` | ${r.artworkVerify.ok ? '✅' : '❌'} |\n`;
  });
  md += `\n## Public URLs (first 5)\n\n`;
  records.slice(0, 5).forEach((r) => {
    md += `- **${r.title}**\n  - audio: ${r.audioUrl}\n  - artwork: ${r.artworkUrl}\n`;
  });
  fs.writeFileSync(path.join(repoRoot, 'R2_UPLOAD_REPORT.md'), md);
}

main().catch((e) => {
  console.error('R2 upload failed:', e.message);
  process.exit(1);
});
