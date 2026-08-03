/**
 * One-time migration: stamp the caching policy onto every existing R2 object.
 *
 * Objects uploaded before lib/r2_client.js existed carry no `Cache-Control`,
 * so clients revalidate them on every view. This walks the whole bucket and
 * rewrites the header in place.
 *
 * HOW IT PRESERVES THE OBJECT
 * ---------------------------
 * Metadata on S3/R2 cannot be patched — the only in-place edit is a self-copy
 * with `MetadataDirective: 'REPLACE'`, which drops every system/user header you
 * do not re-supply. So each object is first `HeadObject`-ed and its
 * ContentType, user Metadata, ContentDisposition, ContentEncoding and
 * ContentLanguage are carried onto the copy verbatim. Only `CacheControl`
 * changes. The body is never downloaded or re-uploaded (server-side copy), so
 * bytes, key and ETag-relevant content are untouched.
 *
 * On ACLs: R2 has no per-object ACLs — public access comes from the bucket's
 * `pub-*.r2.dev` binding — so there is no ACL to preserve, and none is sent.
 *
 * This script deliberately does NOT import firebase-admin: it cannot touch
 * Firestore even by accident.
 *
 * Usage:
 *   node scripts/update_r2_cache_headers.js               # dry run (default)
 *   node scripts/update_r2_cache_headers.js --dry-run
 *   node scripts/update_r2_cache_headers.js --commit
 *   node scripts/update_r2_cache_headers.js --commit --prefix=artwork/
 *   node scripts/update_r2_cache_headers.js --commit --concurrency=12
 *   node scripts/update_r2_cache_headers.js --commit --limit=1   # smoke test
 */
'use strict';

const fs = require('fs');
const path = require('path');
const {
  ListObjectsV2Command,
  HeadObjectCommand,
  CopyObjectCommand,
} = require('@aws-sdk/client-s3');
const { loadR2, publicSummary } = require('./lib/credentials');
const { createR2Client, CACHE_CONTROL } = require('./lib/r2_client');

const OUT = path.join(__dirname, 'seed_data', 'r2_cache_migration.json');

// ── args ─────────────────────────────────────────────────────────────────────
const argv = process.argv.slice(2);
const has = (f) => argv.includes(f);
const val = (name, dflt) => {
  const hit = argv.find((a) => a.startsWith(`--${name}=`));
  return hit ? hit.slice(name.length + 3) : dflt;
};
// Dry run is the default: --commit must be explicit.
const COMMIT = has('--commit');
const PREFIX = val('prefix', '');
const LIMIT = parseInt(val('limit', '0'), 10) || 0;
const CONCURRENCY = Math.max(1, parseInt(val('concurrency', '8'), 10));

/** Bucket-wide object listing (paginated). */
async function listAll(client, bucket, prefix) {
  const keys = [];
  let token;
  do {
    const res = await client.send(
      new ListObjectsV2Command({
        Bucket: bucket,
        Prefix: prefix || undefined,
        ContinuationToken: token,
        MaxKeys: 1000,
      })
    );
    for (const o of res.Contents || []) keys.push({ key: o.Key, size: o.Size });
    token = res.IsTruncated ? res.NextContinuationToken : undefined;
    process.stdout.write(`\r  listed ${keys.length} objects…`);
  } while (token);
  process.stdout.write('\n');
  return keys;
}

/** Top-level prefix of a key, for per-prefix reporting. */
const groupOf = (key) => (key.includes('/') ? `${key.split('/')[0]}/` : '(root)');

/**
 * Rewrite one object's Cache-Control, preserving everything else.
 * Returns 'skipped' when the policy is already correct.
 */
async function migrateOne(client, bucket, key) {
  const head = await client.send(new HeadObjectCommand({ Bucket: bucket, Key: key }));

  if (head.CacheControl === CACHE_CONTROL) {
    return { action: 'skipped', reason: 'already correct', contentType: head.ContentType };
  }

  const preserved = {
    ContentType: head.ContentType || 'application/octet-stream',
    Metadata: head.Metadata || {},
  };
  // Only send optional headers that actually exist — R2 rejects empty values.
  if (head.ContentDisposition) preserved.ContentDisposition = head.ContentDisposition;
  if (head.ContentEncoding) preserved.ContentEncoding = head.ContentEncoding;
  if (head.ContentLanguage) preserved.ContentLanguage = head.ContentLanguage;

  if (!COMMIT) {
    return {
      action: 'would-update',
      before: head.CacheControl || null,
      contentType: preserved.ContentType,
      metadataKeys: Object.keys(preserved.Metadata).length,
    };
  }

  await client.send(
    new CopyObjectCommand({
      Bucket: bucket,
      Key: key,
      // Self-copy. The key must be URI-encoded inside CopySource.
      CopySource: `${bucket}/${key.split('/').map(encodeURIComponent).join('/')}`,
      MetadataDirective: 'REPLACE',
      CacheControl: CACHE_CONTROL,
      ...preserved,
    })
  );

  return {
    action: 'updated',
    before: head.CacheControl || null,
    contentType: preserved.ContentType,
    metadataKeys: Object.keys(preserved.Metadata).length,
  };
}

/** Bounded-concurrency worker pool with per-object retry. */
async function runPool(items, worker, concurrency, onProgress) {
  const results = new Array(items.length);
  let next = 0;
  let done = 0;

  async function drain() {
    while (next < items.length) {
      const i = next++;
      try {
        results[i] = await worker(items[i]);
      } catch (e) {
        results[i] = { action: 'failed', reason: `${e.name || 'Error'}: ${e.message}` };
      }
      onProgress(++done, items.length);
    }
  }

  await Promise.all(Array.from({ length: Math.min(concurrency, items.length) }, drain));
  return results;
}

async function main() {
  const started = Date.now();
  const cfg = loadR2();
  const sum = publicSummary();
  const client = createR2Client(cfg);

  console.log(`R2 cache-header migration`);
  console.log(`  bucket : ${sum.bucket}`);
  console.log(`  public : ${sum.publicUrl}`);
  console.log(`  policy : ${CACHE_CONTROL}`);
  console.log(`  mode   : ${COMMIT ? 'COMMIT (writes)' : 'DRY RUN (no writes)'}`);
  if (PREFIX) console.log(`  prefix : ${PREFIX}`);
  if (LIMIT) console.log(`  limit  : ${LIMIT}`);
  console.log('');

  let objects = await listAll(client, cfg.bucket, PREFIX);
  if (LIMIT) objects = objects.slice(0, LIMIT);
  console.log(`  processing ${objects.length} objects at concurrency ${CONCURRENCY}\n`);

  const results = await runPool(
    objects,
    async (o) => ({ key: o.key, size: o.size, ...(await migrateOne(client, cfg.bucket, o.key)) }),
    CONCURRENCY,
    (n, total) => {
      if (n % 50 === 0 || n === total) {
        process.stdout.write(`\r  ${n}/${total} processed…`);
      }
    }
  );
  process.stdout.write('\n');

  // ── tally ──────────────────────────────────────────────────────────────────
  const elapsedMs = Date.now() - started;
  const counts = { updated: 0, 'would-update': 0, skipped: 0, failed: 0 };
  const byPrefix = {};
  const failures = [];

  results.forEach((r, i) => {
    const key = r.key || objects[i].key;
    const g = groupOf(key);
    byPrefix[g] = byPrefix[g] || { total: 0, updated: 0, 'would-update': 0, skipped: 0, failed: 0 };
    byPrefix[g].total++;
    byPrefix[g][r.action]++;
    counts[r.action]++;
    if (r.action === 'failed') failures.push({ key, reason: r.reason });
  });

  const summary = {
    generatedAt: new Date().toISOString(),
    mode: COMMIT ? 'commit' : 'dry-run',
    bucket: sum.bucket,
    publicUrl: sum.publicUrl,
    policy: CACHE_CONTROL,
    prefixFilter: PREFIX || null,
    totalObjects: objects.length,
    updated: counts.updated,
    wouldUpdate: counts['would-update'],
    skipped: counts.skipped,
    failed: counts.failed,
    elapsedMs,
    elapsedHuman: `${(elapsedMs / 1000).toFixed(1)}s`,
    byPrefix,
    failures: failures.slice(0, 100),
  };

  // Keep the dry-run preview from clobbering the record of a real migration.
  const outFile = COMMIT ? OUT : OUT.replace(/\.json$/, '.dryrun.json');
  fs.mkdirSync(path.dirname(outFile), { recursive: true });
  fs.writeFileSync(outFile, JSON.stringify(summary, null, 2));

  console.log('');
  console.log(`  total       : ${summary.totalObjects}`);
  console.log(`  ${COMMIT ? 'updated     ' : 'would update'}: ${COMMIT ? counts.updated : counts['would-update']}`);
  console.log(`  skipped     : ${counts.skipped} (already correct)`);
  console.log(`  failed      : ${counts.failed}`);
  console.log(`  elapsed     : ${summary.elapsedHuman}`);
  console.log('');
  console.log('  by prefix:');
  for (const [p, v] of Object.entries(byPrefix)) {
    const changed = COMMIT ? v.updated : v['would-update'];
    console.log(`    ${p.padEnd(10)} total=${String(v.total).padEnd(6)} changed=${String(changed).padEnd(6)} skipped=${String(v.skipped).padEnd(6)} failed=${v.failed}`);
  }
  if (failures.length) {
    console.log('\n  first failures:');
    failures.slice(0, 10).forEach((f) => console.log(`    ! ${f.key}: ${f.reason}`));
  }
  console.log(`\n  wrote ${path.relative(path.dirname(__dirname), outFile)}`);
  if (!COMMIT) console.log('\n  DRY RUN — nothing was written to R2. Re-run with --commit to apply.');

  if (counts.failed) process.exitCode = 2;
}

main().catch((e) => {
  console.error('\nmigration failed:', e.message);
  process.exit(1);
});
