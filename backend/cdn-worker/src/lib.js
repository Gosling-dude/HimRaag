// Pure helpers for the CDN Worker — no Workers runtime APIs, so they can be
// unit-tested with `node --test`.

/** Request path → R2 object key, or null for paths we never serve. */
export function objectKeyFromPath(pathname) {
  let key;
  try {
    key = decodeURIComponent(pathname.replace(/^\/+/, ''));
  } catch {
    return null;
  }
  if (!key || key.endsWith('/') || key.includes('..') || key.includes('\\')) {
    return null;
  }
  return key;
}

export function parsePrefixes(raw) {
  return String(raw || '')
    .split(',')
    .map((p) => p.trim())
    .filter(Boolean);
}

export function isProtectedKey(key, prefixes) {
  return prefixes.some((p) => key.startsWith(p));
}

/**
 * Firebase ID token from `Authorization: Bearer …` or the `t` query param.
 * The query form exists because media players can't always set headers.
 */
export function extractToken(headers, searchParams) {
  const auth = headers.get('authorization') || '';
  const match = auth.match(/^Bearer\s+(.+)$/i);
  if (match) return match[1].trim();
  const t = searchParams.get('t');
  return t ? t.trim() : null;
}

/**
 * Builds the `Content-Range` header for an R2 range response.
 * R2 reports either `{ offset, length }` or `{ suffix }`.
 */
export function contentRangeHeader(range, size) {
  if (!range) return null;
  let start;
  let end;
  if (typeof range.suffix === 'number') {
    const len = Math.min(range.suffix, size);
    start = size - len;
    end = size - 1;
  } else {
    start = range.offset ?? 0;
    const length = range.length ?? size - start;
    end = Math.min(start + length, size) - 1;
  }
  return `bytes ${start}-${end}/${size}`;
}

export function cacheControlFor(isProtected) {
  // Audio responses depend on a per-user token: never shared-cache them.
  // Artwork keys are stable slugs that can be regenerated in place, so cache
  // for a day rather than forever.
  return isProtected
    ? 'private, max-age=3600'
    : 'public, max-age=86400, stale-while-revalidate=604800';
}

export const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Range, If-None-Match',
  'Access-Control-Expose-Headers':
    'Content-Length, Content-Range, Accept-Ranges, ETag',
  'Access-Control-Max-Age': '86400',
};
