/**
 * Verify the R2 caching policy, and emit R2_CACHE_REPORT.md.
 *
 * TWO INDEPENDENT CHECKS PER OBJECT
 * ---------------------------------
 *  1. Authenticated S3 `HeadObject` — the authoritative proof that the header
 *     is stored on the object itself.
 *  2. Public `HEAD` against the r2.dev URL — the user-facing confirmation that
 *     a real client sees it.
 *
 * The public check sits behind Cloudflare's edge cache, so a URL cached before
 * the migration can still serve the OLD headers until that edge entry expires.
 * That is edge staleness, not a migration failure. To reduce it, each request
 * carries a cache-busting query string (which changes the Cloudflare cache key
 * but not the R2 object key) and `cf-cache-status` is reported alongside every
 * result. Requests are throttled and retried on 429 because r2.dev rate-limits.
 *
 * Reads the migration summary written by update_r2_cache_headers.js. Does not
 * import firebase-admin and never writes to R2.
 *
 * Usage:
 *   node scripts/verify_r2_cache.js                 # 20 per class
 *   node scripts/verify_r2_cache.js --samples=30
 */
'use strict';

const fs = require('fs');
const path = require('path');
const https = require('https');
const { ListObjectsV2Command, HeadObjectCommand } = require('@aws-sdk/client-s3');
const { loadR2, publicSummary } = require('./lib/credentials');
const { createR2Client, CACHE_CONTROL } = require('./lib/r2_client');

const repoRoot = path.dirname(__dirname);
const MIGRATION_JSON = path.join(__dirname, 'seed_data', 'r2_cache_migration.json');
const OUT_JSON = path.join(__dirname, 'seed_data', 'r2_cache_verification.json');
const REPORT = path.join(repoRoot, 'R2_CACHE_REPORT.md');

const argv = process.argv.slice(2);
const val = (n, d) => {
  const hit = argv.find((a) => a.startsWith(`--${n}=`));
  return hit ? hit.slice(n.length + 3) : d;
};
const SAMPLES = parseInt(val('samples', '20'), 10);
const CONCURRENCY = 3; // r2.dev rate-limits; stay gentle.

/** Object classes to sample, mapped to the prefixes that hold them. */
const CLASSES = [
  { name: 'MP3 audio', prefixes: ['audio/'], match: /\.mp3$/i },
  { name: 'Song artwork', prefixes: ['artwork/'], match: /\.(jpg|jpeg|png|webp)$/i },
  { name: 'Artist photos', prefixes: ['artist/', 'artists/'], match: /\.(jpg|jpeg|png|webp)$/i },
  { name: 'Album artwork', prefixes: ['albums/'], match: /\.(jpg|jpeg|png|webp)$/i },
];

async function listPrefix(client, bucket, prefix) {
  const keys = [];
  let token;
  do {
    const res = await client.send(
      new ListObjectsV2Command({ Bucket: bucket, Prefix: prefix, ContinuationToken: token, MaxKeys: 1000 })
    );
    for (const o of res.Contents || []) keys.push(o.Key);
    token = res.IsTruncated ? res.NextContinuationToken : undefined;
  } while (token);
  return keys;
}

/** Deterministic-ish random sample (Fisher–Yates on a copy). */
function sample(arr, n) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a.slice(0, Math.min(n, a.length));
}

/** Public HEAD with cache-buster; retries on 429/5xx. */
function publicHead(url, attempt = 0) {
  return new Promise((resolve) => {
    const bust = `${url.includes('?') ? '&' : '?'}cachecheck=${Date.now()}${Math.random().toString(36).slice(2, 7)}`;
    const req = https.request(`${url}${bust}`, { method: 'HEAD' }, (res) => {
      res.resume();
      const status = res.statusCode;
      if ((status === 429 || status >= 500) && attempt < 4) {
        const wait = 1500 * (attempt + 1);
        setTimeout(() => resolve(publicHead(url, attempt + 1)), wait);
        return;
      }
      resolve({
        status,
        contentType: res.headers['content-type'] || null,
        cacheControl: res.headers['cache-control'] || null,
        cfCacheStatus: res.headers['cf-cache-status'] || null,
        contentLength: res.headers['content-length'] || null,
        attempts: attempt + 1,
      });
    });
    req.on('error', (e) => {
      if (attempt < 4) {
        setTimeout(() => resolve(publicHead(url, attempt + 1)), 1500 * (attempt + 1));
        return;
      }
      resolve({ status: 0, reason: e.message, cacheControl: null, cfCacheStatus: null, attempts: attempt + 1 });
    });
    req.setTimeout(25000, () => {
      req.destroy();
      resolve({ status: 0, reason: 'timeout', cacheControl: null, cfCacheStatus: null, attempts: attempt + 1 });
    });
    req.end();
  });
}

async function runPool(items, worker, concurrency) {
  const out = new Array(items.length);
  let next = 0;
  async function drain() {
    while (next < items.length) {
      const i = next++;
      out[i] = await worker(items[i]);
    }
  }
  await Promise.all(Array.from({ length: Math.min(concurrency, items.length) }, drain));
  return out;
}

async function main() {
  const started = Date.now();
  const cfg = loadR2();
  const sum = publicSummary();
  const client = createR2Client(cfg);

  console.log(`Verifying R2 caching policy (${SAMPLES} objects per class)\n`);

  const groups = [];
  for (const cls of CLASSES) {
    let keys = [];
    for (const p of cls.prefixes) keys = keys.concat(await listPrefix(client, cfg.bucket, p));
    keys = keys.filter((k) => cls.match.test(k));
    const picked = sample(keys, SAMPLES);
    console.log(`  ${cls.name}: population ${keys.length}, sampling ${picked.length}`);

    const rows = await runPool(
      picked,
      async (key) => {
        const url = `${cfg.publicUrl}/${key.split('/').map(encodeURIComponent).join('/')}`;
        const h = await client.send(new HeadObjectCommand({ Bucket: cfg.bucket, Key: key }));
        const pub = await publicHead(url);
        return {
          key,
          url,
          s3ContentType: h.ContentType || null,
          s3CacheControl: h.CacheControl || null,
          s3Ok: h.CacheControl === CACHE_CONTROL,
          httpStatus: pub.status,
          httpContentType: pub.contentType || null,
          httpCacheControl: pub.cacheControl || null,
          cfCacheStatus: pub.cfCacheStatus || null,
          httpOk: pub.status === 200,
          httpHeaderOk: pub.cacheControl === CACHE_CONTROL,
        };
      },
      CONCURRENCY
    );

    const s3Ok = rows.filter((r) => r.s3Ok).length;
    const httpOk = rows.filter((r) => r.httpOk).length;
    const hdrOk = rows.filter((r) => r.httpHeaderOk).length;
    console.log(`    S3 header ${s3Ok}/${rows.length} · HTTP 200 ${httpOk}/${rows.length} · public header ${hdrOk}/${rows.length}`);
    groups.push({ name: cls.name, prefixes: cls.prefixes, population: keys.length, rows });
  }

  const all = groups.flatMap((g) => g.rows);
  const result = {
    generatedAt: new Date().toISOString(),
    bucket: sum.bucket,
    publicUrl: sum.publicUrl,
    policy: CACHE_CONTROL,
    samplesPerClass: SAMPLES,
    totals: {
      checked: all.length,
      s3HeaderCorrect: all.filter((r) => r.s3Ok).length,
      http200: all.filter((r) => r.httpOk).length,
      publicHeaderCorrect: all.filter((r) => r.httpHeaderOk).length,
    },
    elapsedMs: Date.now() - started,
    groups,
  };
  fs.mkdirSync(path.dirname(OUT_JSON), { recursive: true });
  fs.writeFileSync(OUT_JSON, JSON.stringify(result, null, 2));

  writeReport(result);
  console.log(`\nWrote ${path.relative(repoRoot, OUT_JSON)} and R2_CACHE_REPORT.md`);

  const bad = all.filter((r) => !r.s3Ok).length;
  if (bad) {
    console.error(`\n${bad} object(s) do NOT carry the policy at the origin — investigate.`);
    process.exitCode = 2;
  }
}

// ── report ───────────────────────────────────────────────────────────────────
function writeReport(v) {
  let mig = null;
  try {
    mig = JSON.parse(fs.readFileSync(MIGRATION_JSON, 'utf8'));
  } catch (e) {
    /* report still renders without it */
  }

  const t = v.totals;
  let md = `# HimRaag — R2 Cache-Header Report\n\n`;
  md += `_Generated: ${v.generatedAt}_\n\n`;
  md += `**Bucket:** \`${v.bucket}\` · **Public base:** \`${v.publicUrl}\`\n\n`;
  md += `**Policy applied to every object:**\n\n\`\`\`\nCache-Control: ${v.policy}\n\`\`\`\n\n`;
  md += `---\n\n## 1. Migration summary\n\n`;

  if (mig) {
    md += `| Metric | Value |\n|---|---|\n`;
    md += `| Mode | \`${mig.mode}\` |\n`;
    md += `| Total objects enumerated | **${mig.totalObjects}** |\n`;
    md += `| Objects updated | **${mig.updated}** |\n`;
    md += `| Objects skipped (already correct) | ${mig.skipped} |\n`;
    md += `| Failures | ${mig.failed} |\n`;
    md += `| Elapsed time | ${mig.elapsedHuman} |\n\n`;
    md += `### By prefix\n\n| Prefix | Total | Updated | Skipped | Failed |\n|---|---:|---:|---:|---:|\n`;
    for (const [p, s] of Object.entries(mig.byPrefix || {})) {
      md += `| \`${p}\` | ${s.total} | ${s.updated} | ${s.skipped} | ${s.failed} |\n`;
    }
    md += `\n`;
    if ((mig.failures || []).length) {
      md += `### Failures\n\n| Key | Reason |\n|---|---|\n`;
      mig.failures.forEach((f) => (md += `| \`${f.key}\` | ${f.reason} |\n`));
      md += `\n`;
    } else {
      md += `**No failures.**\n\n`;
    }
  } else {
    md += `_Migration summary unavailable (run \`node scripts/update_r2_cache_headers.js --commit\` first)._\n\n`;
  }

  md += `---\n\n## 2. Verification\n\n`;
  md += `Each sampled object is checked twice: an authenticated S3 \`HeadObject\` `;
  md += `(authoritative — proves the header is stored on the object) and a public `;
  md += `\`HEAD\` on the r2.dev URL with a cache-busting query string (proves a real `;
  md += `client sees it). \`cf-cache-status\` is shown because Cloudflare's edge may `;
  md += `still hold a pre-migration entry for a hot URL — that is edge staleness, not `;
  md += `a migration failure.\n\n`;
  md += `| Check | Result |\n|---|---|\n`;
  md += `| Objects sampled | ${t.checked} |\n`;
  md += `| Correct \`Cache-Control\` at origin (S3 HEAD) | **${t.s3HeaderCorrect} / ${t.checked}** |\n`;
  md += `| HTTP 200 OK on public URL | **${t.http200} / ${t.checked}** |\n`;
  md += `| Correct \`Cache-Control\` over public HTTP | **${t.publicHeaderCorrect} / ${t.checked}** |\n\n`;

  for (const g of v.groups) {
    md += `### ${g.name} — ${g.rows.length} sampled of ${g.population} (\`${g.prefixes.join('`, `')}\`)\n\n`;
    md += `| # | URL | Content-Type | Cache-Control | HTTP | cf-cache |\n|---|---|---|---|---|---|\n`;
    g.rows.forEach((r, i) => {
      const status = r.httpStatus === 200 ? '✅ 200 OK' : `❌ ${r.httpStatus || 'ERR'}`;
      const cc = r.httpCacheControl || r.s3CacheControl || '—';
      const ok = cc === v.policy ? '✅' : '⚠️';
      md += `| ${i + 1} | ${r.url} | \`${r.httpContentType || r.s3ContentType || '—'}\` | ${ok} \`${cc}\` | ${status} | ${r.cfCacheStatus || '—'} |\n`;
    });
    md += `\n`;
  }

  md += `---\n\n## 3. Permanence — future uploads\n\n`;
  md += `Every R2 write in this repo goes through \`scripts/lib/r2_client.js\`, whose `;
  md += `\`putObject()\` sets the policy on every \`PutObject\` and ignores any caller-supplied `;
  md += `\`CacheControl\`. Call sites routed through the helper:\n\n`;
  md += `| Script | Uploads |\n|---|---|\n`;
  md += `| \`scripts/r2_upload.js\` | audio + artwork + artist/album covers |\n`;
  md += `| \`scripts/fetch_real_art.js\` | real song/artist/album cover art |\n`;
  md += `| \`scripts/fetch_artist_images.js\` | artist photographs |\n`;
  md += `| \`scripts/generate_thumbnails.js\` | \`-t400.jpg\` thumbnails |\n`;
  md += `| \`scripts/regenerate_art.js\` | generated covers (deprecated path) |\n`;
  md += `| \`scripts/repair_artist_images.js\` | list-only — no uploads (client unified anyway) |\n\n`;
  md += `A new upload script inherits the policy simply by using the helper; the raw `;
  md += `\`PutObjectCommand\` no longer appears anywhere else in the repo.\n\n`;

  md += `## 4. Operational notes\n\n`;
  md += `- **\`immutable\` requires stable keys.** Image keys are content-versioned `;
  md += `(\`-v5\`, \`-t400\`), so a re-render produces a new key and clients pick it up. `;
  md += `**Audio keys (\`audio/<slug>.mp3\`) are not versioned** — with \`max-age=31536000, immutable\`, `;
  md += `replacing an MP3 in place will not reach clients that already cached it. Publish `;
  md += `replacement audio under a new key (e.g. \`-v2\`) instead of overwriting.\n`;
  md += `- **R2 has no per-object ACLs.** Public access comes from the bucket's `;
  md += `\`pub-*.r2.dev\` binding, so no ACL is preserved or sent — nothing to migrate.\n`;
  md += `- **Object bytes were never touched.** The migration is a server-side self-copy `;
  md += `with \`MetadataDirective: REPLACE\`, re-supplying Content-Type, user metadata, `;
  md += `Content-Disposition/Encoding/Language. Verified on a throwaway object: ETag, `;
  md += `size, content type, user metadata and disposition all identical before/after.\n`;
  md += `- **The migration is idempotent.** Objects already carrying the policy are `;
  md += `reported as \`skipped\`; re-running is safe.\n`;
  md += `- **Scope.** No Flutter, Firestore, or UI code is involved — neither script `;
  md += `imports \`firebase-admin\`.\n`;

  fs.writeFileSync(REPORT, md);
}

main().catch((e) => {
  console.error('verification failed:', e.message);
  process.exit(1);
});
