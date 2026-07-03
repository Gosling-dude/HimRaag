/**
 * Shared Pahadi artist & region knowledge for import + rebalance.
 *
 * KNOWN_ARTISTS maps a lowercase artist token (as it appears in filenames,
 * underscores→spaces) to their primary region. Only artists whose region is
 * confidently known are listed — either from public knowledge of the
 * Uttarakhandi/Himachali folk scene or from consistent explicit region tokens
 * co-occurring with the artist across this corpus (e.g. every "Ravita Shah"
 * file also says "Jaunsari"). Ambiguous artists are deliberately absent so
 * their songs go to the admin review queue instead of a wrong bucket.
 *
 * No audio is ever downloaded; this is public metadata only.
 */
'use strict';

const KNOWN_ARTISTS = {
  // ── Garhwali (Uttarakhand — Garhwal) ──────────────────────────────────────
  'narendra singh negi': 'Garhwali',
  'pritam bharatwan': 'Garhwali',
  'preetam bharatwan': 'Garhwali',
  'meena rana': 'Garhwali',
  'kishan mahipal': 'Garhwali',
  'darshan farswan': 'Garhwali',
  'anisha ranghar': 'Garhwali',
  'hema negi karasi': 'Garhwali',
  'rohit chauhan': 'Garhwali',
  'saurav maithani': 'Garhwali',
  'akash negi': 'Garhwali',
  'gunjan dangwal': 'Garhwali',
  'ruhaan bhardwaj': 'Garhwali',
  'ajay solanki': 'Garhwali',
  'divya negi': 'Garhwali',
  'sangeeta raj': 'Garhwali',
  'pankaj raaj': 'Garhwali',
  'pankaj raj': 'Garhwali',
  'sanju silodi': 'Garhwali',
  'raj tiger': 'Garhwali',
  'reeta dhyani': 'Garhwali',
  'natasha shah': 'Garhwali',
  'pareema rana': 'Garhwali',
  'karishma shah': 'Garhwali',
  'priyanka meher': 'Garhwali',
  'amardeep negi': 'Garhwali',
  'gajender rana': 'Garhwali',
  'kalpana chauhan': 'Garhwali',
  'chander singh rahi': 'Garhwali',
  'keshar panwar': 'Garhwali',
  'pannu gusain': 'Garhwali',
  'diksha badoni': 'Garhwali',
  'kishan mahipaal': 'Garhwali',
  'anand xetri': 'Garhwali',
  'vinod bijalwan': 'Garhwali',
  'amit saagar': 'Garhwali',

  // ── Kumaoni (Uttarakhand — Kumaon) ────────────────────────────────────────
  'pappu karki': 'Kumaoni',
  'papu karki': 'Kumaoni',
  'inder arya': 'Kumaoni',
  'jitendra tomkyal': 'Kumaoni',
  'lalit mohan joshi': 'Kumaoni',
  'gopal babu goswami': 'Kumaoni',
  'mohan upreti': 'Kumaoni',
  'maya upadhyay': 'Kumaoni',
  'mamta arya': 'Kumaoni',
  'manoj arya': 'Kumaoni',
  'aarti tamta': 'Kumaoni',
  'arti tamta': 'Kumaoni',
  'shweta mahara': 'Kumaoni',
  'diksha dhoundiyal': 'Kumaoni',
  'diksha dhaundiyal': 'Kumaoni',
  'pooja dhaundiyal': 'Kumaoni',
  'rakesh khanwal': 'Kumaoni',
  'kamal joshi': 'Kumaoni',
  'prahlad mehra': 'Kumaoni',
  'bk samant': 'Kumaoni',
  'b k samant': 'Kumaoni',
  'kavita mehra': 'Kumaoni',

  // ── Himachali (Himachal Pradesh) ──────────────────────────────────────────
  'mohan singh chauhan': 'Himachali',
  'surinder sharma': 'Himachali',
  'thakur dass rathi': 'Himachali',
  'thakur das rathi': 'Himachali',
  'sanjay sharma': 'Himachali',
  'kuldeep sharma': 'Himachali',
  'karnail rana': 'Himachali',
  'vicky chauhan': 'Himachali',
  'novin joshi': 'Himachali',
  'rajender diwan': 'Himachali',
  'rakesh dogra': 'Himachali',
  'rohini dogra': 'Himachali',
  'yogi chauhan': 'Himachali',
  'pankaj thakur': 'Himachali',
  'kuldev kaushal': 'Himachali',
  'surender negi': 'Himachali',
  'vimal negi': 'Himachali',
  'shyam thakur': 'Himachali',
  'ac bhardwaj': 'Himachali',
  'a c bhardwaj': 'Himachali',
  'zorawar hunk': 'Himachali',
  'sardar singh sharma': 'Himachali',
  'ruhaan bharadwaj': 'Garhwali',

  // ── Jaunsari (Uttarakhand — Jaunsar-Bawar) ────────────────────────────────
  'attar shah': 'Jaunsari',
  'ravita shah': 'Jaunsari',
  'amar singh': 'Jaunsari',
  'prashaant g': 'Jaunsari',

  // ── Kinnauri (Himachal — Kinnaur) ─────────────────────────────────────────
  'golu kinnaura': 'Kinnauri',
  'kl singta': 'Kinnauri',
  'k l singta': 'Kinnauri',
};

// Surnames common in the Pahadi music scene — used ONLY to recognize that a
// capitalized filename segment is an artist name (attribution), never to guess
// a region (many surnames span regions).
const SURNAMES = new Set([
  'negi', 'rana', 'karki', 'arya', 'chauhan', 'sharma', 'thakur', 'mehra',
  'bisht', 'rawat', 'panwar', 'farswan', 'gusain', 'dhoundiyal', 'dhaundiyal',
  'tomkyal', 'mahipal', 'dogra', 'kaushal', 'joshi', 'upreti', 'upadhyay',
  'goswami', 'solanki', 'dangwal', 'maithani', 'silodi', 'dhyani', 'meher',
  'mahara', 'tamta', 'samant', 'bharatwan', 'bhardwaj', 'badoni', 'bhatt',
  'uniyal', 'nautiyal', 'bhandari', 'martolia', 'bora', 'pandey', 'shah',
  'ranghar', 'khanwal', 'rathi', 'diwan', 'kinnaura', 'singta', 'mahra',
  'bagdwal', 'chamoli', 'raturi', 'sundriyal', 'kathait', 'kandari',
]);

// Region keywords — Latin + Devanagari. Order matters: specific before the
// broad Himachali bucket ("pahari"/"nati" are Himachali idioms).
const REGION_KEYWORDS = [
  [/kinnaur|kinnauri|किन्नौर/iu, 'Kinnauri'],
  [/sirmaur|sirmauri|सिरमौर/iu, 'Sirmauri'],
  [/jaunsar|jaunsari|jonsari|harul|जौनसार/iu, 'Jaunsari'],
  [/garhwal|garhwali|gadwali|ghadwali|gharwali|गढ़वाल|गढवाल|गढ़वळ/iu, 'Garhwali'],
  [/kumaon|kumaun|kumaoni|kumauni|कुमाऊ|कुमाउ|कुमांऊ/iu, 'Kumaoni'],
  [/himachal|himachali|\bnati\b|\bnatti\b|हिमाचल/iu, 'Himachali'],
];

const LANGUAGE_FOR_REGION = {
  Garhwali: 'Garhwali',
  Kumaoni: 'Kumaoni',
  Himachali: 'Himachali',
  Jaunsari: 'Jaunsari',
  Kinnauri: 'Kinnauri',
  Sirmauri: 'Sirmauri',
};

/** filename → normalized lowercase text for matching. */
function normText(s) {
  return String(s || '')
    .replace(/\.[^.]+$/, '')
    .replace(/[_]+/g, ' ')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

/**
 * Known artist appearing in the filename → {name, region}. When several known
 * artists appear (duets, "feat" credits), the EARLIEST occurrence wins — the
 * main credit conventionally comes first; ties prefer the longer token.
 */
function matchKnownArtist(filename) {
  const hay = normText(filename);
  let best = null;
  for (const [token, region] of Object.entries(KNOWN_ARTISTS)) {
    const at = hay.indexOf(token);
    if (at === -1) continue;
    if (!best || at < best.at || (at === best.at && token.length > best.token.length)) {
      best = { token, region, at };
    }
  }
  if (!best) return null;
  const name = best.token.replace(/\b\w/g, (c) => c.toUpperCase());
  return { name, region: best.region };
}

/**
 * Generic artist-name extraction: a 2–4 word capitalized segment whose last
 * word is a known Pahadi surname. Attribution only (no region inference).
 */
function extractArtistName(filename) {
  const base = String(filename || '').replace(/\.[^.]+$/, '').replace(/\(\d+k?\)/gi, '');
  const segs = base.split(/_{2,}|\s-\s|__+/).map((x) => x.replace(/[_]+/g, ' ').trim());
  for (const seg of segs) {
    const cleaned = seg.replace(/^(feat|ft|singer|by|swar)\.?\s+/i, '').trim();
    const words = cleaned.split(/\s+/);
    if (words.length < 2 || words.length > 4) continue;
    if (words.some((w) => /\d/.test(w))) continue;
    if (!words.every((w) => /^[A-Za-z.]+$/.test(w))) continue;
    const last = words[words.length - 1].toLowerCase().replace(/\./g, '');
    if (!SURNAMES.has(last)) continue;
    const name = words
      .map((w) => w.toLowerCase())
      .join(' ')
      .replace(/\b\w/g, (c) => c.toUpperCase());
    return name;
  }
  return null;
}

/** Explicit region token in filename (Latin or Devanagari). */
function regionFromKeywords(filename) {
  const hay = String(filename || '');
  for (const [re, region] of REGION_KEYWORDS) if (re.test(hay)) return region;
  return null;
}

/**
 * Full region inference for a file/title/artist combo.
 * Returns {region, source, conf} or null when genuinely uncertain.
 * Priority: explicit keyword (0.9) → known-artist mapping (0.8).
 */
function inferRegion({ filename = '', title = '', artistName = '' }) {
  const kw = regionFromKeywords(filename) || regionFromKeywords(title);
  if (kw) return { region: kw, source: 'filename', conf: 0.9 };
  const known =
    matchKnownArtist(filename) ||
    matchKnownArtist(artistName) ||
    matchKnownArtist(title);
  if (known) return { region: known.region, source: 'web', conf: 0.8 };
  return null;
}

module.exports = {
  KNOWN_ARTISTS,
  SURNAMES,
  REGION_KEYWORDS,
  LANGUAGE_FOR_REGION,
  matchKnownArtist,
  extractArtistName,
  regionFromKeywords,
  inferRegion,
};
