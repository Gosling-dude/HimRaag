import { createRemoteJWKSet, jwtVerify } from 'jose';

import {
  bearerToken,
  callMeBotUrl,
  CORS_HEADERS,
  formatMessage,
  parseRequest,
  telegramRequest,
} from './lib.js';

// Google's public keys for Firebase Auth ID tokens (cached by jose).
const FIREBASE_JWKS = createRemoteJWKSet(
  new URL(
    'https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com',
  ),
);

function json(status, body) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json', ...CORS_HEADERS },
  });
}

async function verifyFirebaseToken(token, env) {
  const projectId = env.FIREBASE_PROJECT_ID;
  const { payload } = await jwtVerify(token, FIREBASE_JWKS, {
    issuer: `https://securetoken.google.com/${projectId}`,
    audience: projectId,
    algorithms: ['RS256'],
  });
  if (!payload.sub) throw new Error('token has no subject');
  if (payload.firebase?.sign_in_provider === 'anonymous') throw new Error('anonymous user');
  return payload;
}

/**
 * Per-user hourly cap, kept in the edge cache. Approximate (per colo, not
 * atomic) — enough to stop one account flooding the owner's phone.
 */
async function overLimit(uid, env) {
  const max = Number(env.MAX_REQUESTS_PER_HOUR || 5);
  const hour = Math.floor(Date.now() / 3_600_000);
  const key = new Request(`https://himraag-notify.internal/limit/${uid}/${hour}`);
  const cache = caches.default;
  const hit = await cache.match(key);
  const count = hit ? Number(await hit.text()) : 0;
  if (count >= max) return true;
  await cache.put(key, new Response(String(count + 1), {
    headers: { 'Cache-Control': 'max-age=3600' },
  }));
  return false;
}

async function sendWhatsApp(text, env) {
  if (!env.CALLMEBOT_PHONE || !env.CALLMEBOT_APIKEY) return 'skipped';
  const res = await fetch(callMeBotUrl(env.CALLMEBOT_PHONE, env.CALLMEBOT_APIKEY, text));
  return res.ok ? 'sent' : `failed ${res.status}`;
}

async function sendTelegram(text, env) {
  if (!env.TELEGRAM_BOT_TOKEN || !env.TELEGRAM_CHAT_ID) return 'skipped';
  const { url, body } = telegramRequest(env.TELEGRAM_BOT_TOKEN, env.TELEGRAM_CHAT_ID, text);
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  return res.ok ? 'sent' : `failed ${res.status}`;
}

async function sendEmail(subject, text, env) {
  if (!env.RESEND_API_KEY || !env.NOTIFY_EMAIL) return 'skipped';
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${env.RESEND_API_KEY}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: 'HimRaag <onboarding@resend.dev>',
      to: [env.NOTIFY_EMAIL],
      subject,
      text,
    }),
  });
  return res.ok ? 'sent' : `failed ${res.status}`;
}

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS_HEADERS });
    const url = new URL(request.url);
    if (url.pathname !== '/song-request') return json(404, { error: 'Not found' });
    if (request.method !== 'POST') return json(405, { error: 'Method not allowed' });

    const token = bearerToken(request.headers);
    if (!token) return json(401, { error: 'Sign in required' });
    let user;
    try {
      user = await verifyFirebaseToken(token, env);
    } catch {
      return json(401, { error: 'Invalid or expired token' });
    }

    let body;
    try {
      body = await request.json();
    } catch {
      return json(400, { error: 'Invalid JSON' });
    }
    const parsed = parseRequest(body);
    if (parsed.error) return json(400, { error: parsed.error });
    if (await overLimit(user.sub, env)) return json(429, { error: 'Too many requests' });

    const req = parsed.value;
    const text = formatMessage(req, { uid: user.sub, name: user.name, email: user.email });
    const [whatsapp, telegram, email] = await Promise.all([
      sendWhatsApp(text, env).catch((e) => `failed ${e.message}`),
      sendTelegram(text, env).catch((e) => `failed ${e.message}`),
      sendEmail(`Song request: ${req.songTitle}`, text, env).catch((e) => `failed ${e.message}`),
    ]);
    console.log('song request', { uid: user.sub, whatsapp, telegram, email });
    return json(202, { whatsapp, telegram, email });
  },
};
