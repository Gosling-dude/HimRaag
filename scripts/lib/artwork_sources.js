/**
 * Real-artwork resolvers for the HimRaag catalog.
 *
 * Replaces the old branded/AI poster generator (`cover_art.js`) which baked
 * title/artist/region/HimRaag text into every cover. Per the production art
 * direction, covers must be natural imagery only — NO text, NO logos, NO
 * generated posters — exactly like Spotify / YouTube Music / Apple Music.
 *
 * Two sources, in priority order:
 *   1. Real official cover art via the public JioSaavn search API, accepted
 *      only when a STRICT title+artist+language match passes (a wrong Bollywood
 *      cover is worse than a clean photo, so ambiguous matches are rejected).
 *   2. License-clean regional photographs via the Wikimedia Commons API
 *      (Public domain / CC0 preferred, CC BY-SA accepted with attribution),
 *      mapped per Pahadi region (Garhwal/Kumaon/Jaunsar/Himachal/Kinnaur/Sirmaur).
 *
 * Pure Node + https, no native deps. Callers should throttle Wikimedia calls.
 */
'use strict';

const https = require('https');

// ── HTTP ─────────────────────────────────────────────────────────────────────
function httpGet(url, { json = false, binary = false } = {}) {
  return new Promise((resolve) => {
    const req = https.get(
      url,
      { headers: { 'User-Agent': 'HimRaag-Artwork/1.0 (Pahadi music app)', Accept: json ? 'application/json' : '*/*' } },
      (res) => {
        // Follow one level of redirects (Wikimedia/iTunes sometimes 30x).
        if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
          res.resume();
          return resolve(httpGet(res.headers.location, { json, binary }));
        }
        const chunks = [];
        res.on('data', (c) => chunks.push(c));
        res.on('end', () => {
          const buf = Buffer.concat(chunks);
          if (binary) return resolve({ status: res.statusCode, buf, contentType: res.headers['content-type'] || '' });
          const body = buf.toString('utf8');
          if (json) { try { return resolve({ status: res.statusCode, data: JSON.parse(body) }); } catch { return resolve({ status: res.statusCode, data: null }); } }
          resolve({ status: res.statusCode, body });
        });
      }
    );
    req.on('error', () => resolve({ status: 0, data: null, body: '', buf: Buffer.alloc(0) }));
    req.setTimeout(20000, () => { req.destroy(); resolve({ status: 0, data: null, body: '', buf: Buffer.alloc(0) }); });
  });
}

async function downloadImage(url) {
  const r = await httpGet(url, { binary: true });
  if (r.status !== 200 || !r.buf || r.buf.length < 1024) return null;
  return { buf: r.buf, contentType: r.contentType };
}

// ── Text helpers ─────────────────────────────────────────────────────────────
function decodeEntities(s) {
  return String(s || '')
    .replace(/&amp;/g, '&').replace(/&quot;/g, '"').replace(/&#0?39;/g, "'")
    .replace(/&#x27;/g, "'").replace(/&lt;/g, '<').replace(/&gt;/g, '>');
}
function stripParens(s) { return String(s || '').replace(/\(.*?\)/g, ' ').replace(/\[.*?\]/g, ' ').replace(/\bfeat\.?.*$/i, ' '); }
function norm(s) {
  return decodeEntities(s).toLowerCase().normalize('NFKD').replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, ' ').trim();
}
const STOP = new Set(['the', 'and', 'a', 'an', 'of', 'to', 'in', 'on', 'ka', 'ki', 'ke', 'ko', 'ho', 'hai', 're', 'ri', 'o', 'me', 'mein', 'se', 'na', 'ne', 'de', 'da', 'di', 'le', 'la', 'ye', 'yo', 'wo', 'ka', 'version', 'duet', 'soundtrack', 'remix', 'title', 'track', 'original']);
// Surnames/words too common to use as an artist-match signal.
const COMMON_ARTIST = new Set(['singh', 'kumar', 'sharma', 'devi', 'lal', 'ram', 'pahadi', 'folk', 'records', 'music', 'official', 'records', 'prod']);

function tokens(s, minLen) {
  return norm(s).split(' ').filter((t) => t.length >= minLen && !STOP.has(t));
}
function distinctive(title) { return [...new Set(tokens(title, 3))]; }

// ── Language buckets ─────────────────────────────────────────────────────────
const REGIONAL_LANGS = new Set(['himachali', 'pahadi', 'pahari', 'kumaoni', 'garhwali', 'jaunsari', 'kinnauri', 'sirmauri', 'uttrakhandi', 'uttarakhandi', 'dogri']);
const REJECT_LANGS = new Set(['punjabi', 'tamil', 'telugu', 'gujarati', 'assamese', 'bengali', 'marathi', 'kannada', 'malayalam', 'odia', 'bhojpuri', 'rajasthani']);
const BOLLYWOOD = ['udit narayan', 'alka yagnik', 'sonu nigam', 'kishore kumar', 'lata mangeshkar', 'asha bhosle', 'arijit singh', 'shreya ghoshal', 'honey singh', 'yo yo', 'neha kakkar', 'atif aslam', 'sunidhi chauhan', 'mohit chauhan', 'rahat fateh', 'badshah', 'diljit dosanjh', 'guru randhawa', 'b praak', 'kk', 'vishal', 'shankar', 'pritam', 'amaal mallik'];

// ── JioSaavn ─────────────────────────────────────────────────────────────────
const SAAVN = 'https://www.jiosaavn.com/api.php';
function saavnUrl(call, params) {
  const qs = Object.entries({ __call: call, _format: 'json', _marker: '0', ctx: 'web6dot0', ...params })
    .map(([k, v]) => `${k}=${encodeURIComponent(v)}`).join('&');
  return `${SAAVN}?${qs}`;
}
function upscale(img) { return String(img || '').replace(/-?\d{2,4}x\d{2,4}\.(jpg|png|webp)/i, '-500x500.$1'); }

async function saavnSearchSongs(query) {
  const r = await httpGet(saavnUrl('search.getResults', { q: query, n: 6 }), { json: true });
  return (r.data && r.data.results) || [];
}

/**
 * Score a JioSaavn candidate against our song. Returns a numeric score or null
 * (reject). Higher is better. The thresholds are deliberately conservative.
 */
function scoreCandidate(song, cand) {
  const ours = distinctive(song.title);
  if (!ours.length) return null;
  const candTitleTokens = new Set(tokens(stripParens(cand.song || cand.title || ''), 2));
  const overlap = ours.filter((t) => candTitleTokens.has(t));
  if (!overlap.length) return null;
  const ratio = overlap.length / ours.length;
  const exact = norm(stripParens(song.title)) === norm(stripParens(cand.song || cand.title || ''));
  const longest = Math.max(...ours.map((t) => t.length));

  const lang = norm(cand.language);
  const artistStr = norm(`${cand.primary_artists || ''} ${cand.singers || ''} ${cand.featured_artists || ''}`);
  const artistTokensSet = new Set(artistStr.split(' '));
  const ourArtistTokens = tokens(song.artistName, 4).filter((t) => !COMMON_ARTIST.has(t));
  const artistMatch = ourArtistTokens.some((t) => artistTokensSet.has(t));
  const isBollywood = BOLLYWOOD.some((b) => artistStr.includes(b));

  if (REJECT_LANGS.has(lang) && !artistMatch) return null;
  if (isBollywood && !artistMatch) return null;

  // strong title = exact, or (>=2 distinctive tokens and >=60% overlap)
  const strong = exact || (ours.length >= 2 && ratio >= 0.6);

  if (artistMatch && ratio >= 0.5) return 100 + (REGIONAL_LANGS.has(lang) ? 5 : 0);
  if (REGIONAL_LANGS.has(lang) && strong) return 90;
  // exact, non-bollywood, on a generic/hindi tag: only trust multi-token or a
  // rare single token (>=5 chars) — blocks short generic collisions like "Aaja".
  if (exact && !isBollywood && !REJECT_LANGS.has(lang) && (ours.length >= 2 || longest >= 5)) return 75;
  // 3+ distinctive tokens matching at >=66% is an unmistakable phrase even on a
  // mis-tagged "hindi" entry (e.g. "...Rohru Ri Jatre") — collision risk is tiny.
  if (ours.length >= 3 && ratio >= 0.66 && !isBollywood && !REJECT_LANGS.has(lang)) return 70;
  return null;
}

/**
 * Resolve the best real official cover for a song. Returns
 * { url, source:'jiosaavn', score, match:{song,album,artist,language,year} } or null.
 */
async function findSongArtwork(song) {
  const queries = [song.title];
  const artistReal = song.artistName && !/pahadi folk/i.test(song.artistName);
  if (artistReal) queries.push(`${song.title} ${song.artistName}`);

  const seen = new Map(); // id -> candidate
  for (const q of queries) {
    for (const c of await saavnSearchSongs(q)) if (c && c.id && !seen.has(c.id)) seen.set(c.id, c);
  }

  let best = null;
  for (const c of seen.values()) {
    const score = scoreCandidate(song, c);
    if (score == null) continue;
    if (!best || score > best.score) best = { score, cand: c };
  }
  if (!best) return null;
  const c = best.cand;
  const url = upscale(c.image);
  if (!url || !/^https?:/.test(url)) return null;
  return {
    url,
    source: 'jiosaavn',
    score: best.score,
    match: {
      song: decodeEntities(c.song || c.title),
      album: decodeEntities((c.more_info && c.more_info.album) || c.album || ''),
      artist: decodeEntities(c.primary_artists || ''),
      language: c.language || '',
      year: c.year || '',
    },
  };
}

/**
 * Try a real artist photo via JioSaavn autocomplete. Conservative: only accept
 * a non-default saavncdn image whose artist title is an exact normalized match.
 * Returns { url, source:'jiosaavn-artist', match } or null (→ caller uses a
 * clean placeholder avatar; never an AI/generated face).
 */
async function findArtistImage(name) {
  if (!name || /pahadi folk/i.test(name)) return null;
  // Multi-name credits ("A, B") have no single portrait → placeholder.
  if (name.includes(',')) return null;
  const r = await httpGet(saavnUrl('autocomplete.get', { query: name }), { json: true });
  const arts = (r.data && r.data.artists && r.data.artists.data) || [];
  const want = norm(name);
  for (const a of arts) {
    const img = a.image || '';
    if (!/c\.saavncdn\.com/.test(img)) continue; // skip default placeholders
    if (/artist-default/.test(img)) continue;
    if (norm(a.title) !== want) continue; // exact name only — avoid wrong person
    const url = upscale(img);
    return { url, source: 'jiosaavn-artist', match: { name: decodeEntities(a.title) } };
  }
  return null;
}

// ── Wikimedia Commons (license-clean region photos) ──────────────────────────
const REGION_TERMS = {
  Garhwali: ['Kedarnath temple Uttarakhand', 'Garhwal Himalaya landscape', 'Uttarakhand mountain village'],
  Kumaoni: ['Nainital lake Uttarakhand', 'Kumaon hills landscape', 'Uttarakhand Himalaya forest'],
  Jaunsari: ['Jaunsar Bawar Uttarakhand', 'Uttarakhand village Himalaya', 'Himalaya terrace fields India'],
  Himachali: ['Himachal Pradesh mountains landscape', 'Spiti valley Himachal', 'Himachal Pradesh village snow'],
  Kinnauri: ['Kinnaur valley Himachal', 'Sangla valley Himachal', 'Kinnaur landscape mountains'],
  Sirmauri: ['Sirmaur Himachal landscape', 'Renuka lake Himachal', 'Himachal Pradesh temple mountains'],
  Pahadi: ['Nainital lake Uttarakhand', 'Spiti valley Himachal', 'Kedarnath temple Uttarakhand'],
};
function licenseRank(lic) {
  const l = (lic || '').toLowerCase();
  if (l.includes('public domain') || l.includes('cc0')) return 0;
  if (l.includes('cc by') && !l.includes('nc') && !l.includes('nd')) return 1; // CC BY / CC BY-SA
  return 9; // NC/ND or unknown → avoid
}
async function commonsSearch(term) {
  const url = 'https://commons.wikimedia.org/w/api.php?action=query&format=json&generator=search'
    + `&gsrsearch=${encodeURIComponent('filetype:bitmap ' + term)}&gsrnamespace=6&gsrlimit=8`
    + '&prop=imageinfo&iiprop=url|extmetadata|size&iiurlwidth=1000';
  const r = await httpGet(url, { json: true });
  const pages = (r.data && r.data.query && r.data.query.pages) || {};
  return Object.values(pages).map((p) => {
    const ii = (p.imageinfo && p.imageinfo[0]) || {};
    const md = ii.extmetadata || {};
    const lic = (md.LicenseShortName && md.LicenseShortName.value) || '';
    const artist = (md.Artist && md.Artist.value) || '';
    // Author credit can be a paragraph; reduce to a short, clean attribution.
    let attribution = artist.replace(/<[^>]+>/g, ' ').replace(/&amp;/g, '&').replace(/\s+/g, ' ').trim();
    const longNote = /contact me|commercial use|non[- ]?commercial|do not upload/i.test(attribution);
    if (attribution.length > 60) attribution = attribution.slice(0, 57).trim() + '…';
    return {
      title: (p.title || '').replace(/^File:/, ''),
      thumb: ii.thumburl,
      sourceUrl: ii.url || '',
      width: ii.thumbwidth || ii.width || 0,
      height: ii.thumbheight || ii.height || 0,
      license: lic,
      attribution,
      restricted: longNote, // author asks to be contacted before (commercial) use
    };
  });
}
// Reject non-photographic or restricted files (maps, diagrams, satellite scans,
// logos, vector/raw formats) so covers are always beautiful real photographs.
const NON_PHOTO = /\b(map|maps|satellite|diagram|chart|locator|plan|logo|flag|coat of arms|seal|poster|sign|signboard|graph|infographic)\b/i;
// Historical artwork / non-photographic media — must be a real modern photograph.
const NOT_A_PHOTO = /\b(painting|paintings|aquatint|engraving|lithograph|drawing|etching|illustration|woodcut|sketch|scenery|watercolou?r|British Library|fresco|mural|stamp|banknote|coin|manuscript)\b/i;
// Wildlife / fauna close-ups are real photos but make poor music-cover imagery.
const WILDLIFE = /\b(bird|chough|sparrow|eagle|vulture|pheasant|butterfly|moth|insect|beetle|dragonfly|langur|macaque|leopard|deer|monkey|cattle|goat|sheep|dog|cat|fish|snake|lizard|spider)s?\b/i;
function isUsablePhoto(c) {
  if (!c.thumb || c.width < 800 || c.width < c.height) return false;
  if (c.restricted) return false;
  if (NON_PHOTO.test(c.title) || NOT_A_PHOTO.test(c.title) || WILDLIFE.test(c.title)) return false;
  if (/\.(tiff?|svg|pdf|gif)$/i.test(c.sourceUrl || c.title)) return false;
  // Exclude pre-photographic / historical works (colonial aquatints etc.).
  if (/\b(1[5-9]\d{2})\b/.test(c.title) || /century/i.test(c.title)) return false;
  if (/daniell|colour aquatint|colored aquatint/i.test(c.attribution)) return false;
  return licenseRank(c.license) <= 1;
}

/**
 * Build a per-region pool of license-clean landscape photos. One network pass.
 * Returns { region: [ {title,thumb,license,attribution,width,height}, ... ] }.
 */
async function buildRegionPhotoPool(regions, { sleep = 350 } = {}) {
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  const pool = {};
  const all = [...new Set([...regions, 'Pahadi'])];
  for (const region of all) {
    const terms = REGION_TERMS[region] || REGION_TERMS.Pahadi;
    const collected = [];
    for (const term of terms) {
      const cands = (await commonsSearch(term))
        .filter(isUsablePhoto) // real landscape photos only — no maps/diagrams/satellite/art/restricted
        .sort((a, b) => b.width - a.width); // prefer higher-resolution photos
      collected.push(...cands);
      await wait(sleep);
      if (collected.length >= 5) break;
    }
    // de-dupe by title
    const byTitle = new Map();
    for (const c of collected) if (!byTitle.has(c.title)) byTitle.set(c.title, c);
    pool[region] = [...byTitle.values()];
  }
  return pool;
}

function hash(s) { let h = 5381; for (let i = 0; i < String(s).length; i++) h = ((h << 5) + h + String(s).charCodeAt(i)) >>> 0; return h; }

/** Deterministically pick a photo for a region+seed from a prebuilt pool. */
function pickRegionPhoto(pool, region, seed) {
  const list = (pool[region] && pool[region].length ? pool[region] : pool.Pahadi) || [];
  if (!list.length) return null;
  const c = list[hash(seed) % list.length];
  return {
    url: c.thumb,
    source: 'photograph',
    license: c.license,
    attribution: c.attribution,
    title: c.title,
  };
}

module.exports = {
  httpGet,
  downloadImage,
  findSongArtwork,
  findArtistImage,
  buildRegionPhotoPool,
  pickRegionPhoto,
};
