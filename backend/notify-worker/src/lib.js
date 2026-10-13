// Pure helpers for the notify Worker — no Workers runtime APIs, so they can
// be unit-tested with `node --test`.

export const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  'Access-Control-Max-Age': '86400',
};

/** Same limits as the Firestore rules on songRequests. */
const LIMITS = { songTitle: 150, artist: 150, link: 500, details: 1000, searchQuery: 200 };

export function bearerToken(headers) {
  const match = (headers.get('authorization') || '').match(/^Bearer\s+(.+)$/i);
  return match ? match[1].trim() : null;
}

/** Validated, trimmed request fields, or an error message. */
export function parseRequest(body) {
  if (!body || typeof body !== 'object') return { error: 'Expected a JSON object' };
  const out = {};
  for (const [field, max] of Object.entries(LIMITS)) {
    const v = body[field] ?? '';
    if (typeof v !== 'string') return { error: `${field} must be a string` };
    const t = v.trim();
    if (t.length > max) return { error: `${field} is too long` };
    out[field] = t;
  }
  if (!out.songTitle) return { error: 'songTitle is required' };
  return { value: out };
}

/** Plain-text message shared by WhatsApp and email. */
export function formatMessage(req, user) {
  const who = [user.name, user.email].filter(Boolean).join(' · ') || user.uid;
  return [
    '🎵 New HimRaag song request',
    '',
    `Song: ${req.songTitle}`,
    req.artist && `Singer: ${req.artist}`,
    req.link && `Link: ${req.link}`,
    req.details && `Details: ${req.details}`,
    req.searchQuery && req.searchQuery !== req.songTitle && `Searched for: "${req.searchQuery}"`,
    '',
    `From: ${who}`,
  ].filter((line) => line !== false && line !== undefined && line !== null).join('\n');
}

/** Telegram Bot API sendMessage call for [chatId]. */
export function telegramRequest(botToken, chatId, text) {
  return {
    url: `https://api.telegram.org/bot${botToken}/sendMessage`,
    body: { chat_id: chatId, text, disable_web_page_preview: true },
  };
}

export function callMeBotUrl(phone, apiKey, text) {
  const params = new URLSearchParams({ phone, text, apikey: apiKey });
  return `https://api.callmebot.com/whatsapp.php?${params}`;
}
