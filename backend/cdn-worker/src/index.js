import { createRemoteJWKSet, jwtVerify } from 'jose';

import {
  cacheControlFor,
  contentRangeHeader,
  CORS_HEADERS,
  extractToken,
  isProtectedKey,
  objectKeyFromPath,
  parsePrefixes,
} from './lib.js';

// Google's public keys for Firebase Auth ID tokens (cached by jose).
const FIREBASE_JWKS = createRemoteJWKSet(
  new URL(
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
  ),
);

function textResponse(status, message) {
  return new Response(message, {
    status,
    headers: { 'Content-Type': 'text/plain', ...CORS_HEADERS },
  });
}

async function verifyFirebaseToken(token, env) {
  const projectId = env.FIREBASE_PROJECT_ID;
  const { payload } = await jwtVerify(token, FIREBASE_JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
    algorithms: ['RS256'],
    clockTolerance: Number(env.TOKEN_GRACE_SECONDS || 0),
  });
  if (!payload.sub) throw new Error('token has no subject');
  return payload;
}

export default {
  async fetch(request, env, ctx) {
    const method = request.method;
    if (method === 'OPTIONS') {
      return new Response(null, { status: 204, headers: CORS_HEADERS });
    }
    if (method !== 'GET' && method !== 'HEAD') {
      return textResponse(405, 'Method not allowed');
    }

    const url = new URL(request.url);
    const key = objectKeyFromPath(url.pathname);
    if (!key) return textResponse(404, 'Not found');

    const isProtected = isProtectedKey(key, parsePrefixes(env.PROTECTED_PREFIXES));
    if (isProtected && env.REQUIRE_AUTH === 'true') {
      const token = extractToken(request.headers, url.searchParams);
      if (!token) return textResponse(401, 'Sign in required');
      try {
        await verifyFirebaseToken(token, env);
      } catch {
        return textResponse(401, 'Invalid or expired token');
      }
    }

    // Public artwork: serve from the edge cache when we can. The cache key
    // drops the query string so `?t=` never fragments it.
    const cache = caches.default;
    const cacheKey = new Request(`${url.origin}${url.pathname}`, { method: 'GET' });
    const cacheable = !isProtected && method === 'GET' && !request.headers.has('range');
    if (cacheable) {
      const hit = await cache.match(cacheKey);
      if (hit) return hit;
    }

    const object =
      method === 'HEAD'
        ? await env.MEDIA.head(key)
        : await env.MEDIA.get(key, {
            range: request.headers,
            onlyIf: request.headers,
          });
    if (!object) return textResponse(404, 'Not found');

    const headers = new Headers(CORS_HEADERS);
    object.writeHttpMetadata(headers);
    headers.set('ETag', object.httpEtag);
    headers.set('Accept-Ranges', 'bytes');
    headers.set('Cache-Control', cacheControlFor(isProtected));

    // GET whose precondition failed: R2 returns metadata without a body.
    if (method === 'GET' && !('body' in object)) {
      const conditional =
        request.headers.has('if-none-match') || request.headers.has('if-modified-since');
      return new Response(null, { status: conditional ? 304 : 412, headers });
    }

    if (method === 'HEAD') {
      headers.set('Content-Length', String(object.size));
      return new Response(null, { status: 200, headers });
    }

    const contentRange = request.headers.has('range')
      ? contentRangeHeader(object.range, object.size)
      : null;
    if (contentRange) {
      headers.set('Content-Range', contentRange);
      const [, start, end] = contentRange.match(/bytes (\d+)-(\d+)/);
      headers.set('Content-Length', String(Number(end) - Number(start) + 1));
      return new Response(object.body, { status: 206, headers });
    }

    headers.set('Content-Length', String(object.size));
    const response = new Response(object.body, { status: 200, headers });
    if (cacheable) ctx.waitUntil(cache.put(cacheKey, response.clone()));
    return response;
  },
};
