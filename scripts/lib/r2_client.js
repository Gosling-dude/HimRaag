/**
 * Single source of truth for Cloudflare R2 writes.
 *
 * WHY THIS EXISTS
 * ---------------
 * Objects uploaded without `Cache-Control` are revalidated by every client on
 * every view: slow thumbnails, wasted bandwidth, extra Cloudflare Class-B
 * operations. Rather than repeating the header at each call site (and forgetting
 * it on the next script), every upload in this repo goes through `putObject()`
 * below, which applies the caching policy automatically.
 *
 * THE POLICY
 * ----------
 *   Cache-Control: public, max-age=31536000, immutable
 *
 * `immutable` is only safe when a key's bytes never change. Image keys are
 * content-versioned (`-v5`, `-t400`) so a new render means a new key. Audio keys
 * (`audio/<slug>.mp3`) are NOT versioned — replacing an MP3 in place would not
 * reach clients that already cached it. Publish replacement audio under a new
 * key (e.g. `-v2`) instead of overwriting.
 *
 * NOTE ON ACLs: R2 has no per-object ACLs. Public access is granted at the
 * bucket level (the `pub-*.r2.dev` domain), so there is no ACL to preserve or
 * set here; passing one would be rejected by the S3 API shim.
 *
 * USAGE
 *   const { createR2Client, putObject, CACHE_CONTROL } = require('./lib/r2_client');
 *   const client = createR2Client(cfg);
 *   await putObject(client, cfg.bucket, key, body, 'image/jpeg');
 */
'use strict';

const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');

/** The caching policy applied to every object this repo writes to R2. */
const CACHE_CONTROL = 'public, max-age=31536000, immutable';

/** Build an S3 client pointed at R2 from a `loadR2()` config. */
function createR2Client(cfg) {
  return new S3Client({
    region: 'auto',
    endpoint: cfg.endpoint,
    credentials: {
      accessKeyId: cfg.accessKeyId,
      secretAccessKey: cfg.secretAccessKey,
    },
  });
}

/**
 * Upload one object. Always sets the caching policy.
 *
 * @param {S3Client} client
 * @param {string} bucket
 * @param {string} key
 * @param {Buffer|Uint8Array|string} body
 * @param {string} contentType
 * @param {object} [extra] extra PutObject fields (Metadata, ContentDisposition…).
 *   `CacheControl` here is ignored — the policy is not overridable by callers.
 */
async function putObject(client, bucket, key, body, contentType, extra = {}) {
  const { CacheControl, ...rest } = extra; // eslint-disable-line no-unused-vars
  return client.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: body,
      ContentType: contentType,
      CacheControl: CACHE_CONTROL,
      ...rest,
    })
  );
}

/**
 * Curried helper for scripts that upload in a loop:
 *   const put = makePutter(client, cfg.bucket);
 *   await put(key, body, 'image/png');
 */
function makePutter(client, bucket) {
  return (key, body, contentType, extra) =>
    putObject(client, bucket, key, body, contentType, extra);
}

module.exports = { CACHE_CONTROL, createR2Client, putObject, makePutter };
