/**
 * Clean song titles + artists that still carry raw-filename noise.
 *
 * Titles: strips copy suffixes "(0)(1)", underscores, hashtags, emoji,
 * "Latest … Song 2023", "By/Singer/Lyrics …", "[Garhwali Song]", " II " splits,
 * and SHOUTING CASE. A few titles no rule can rescue are fixed by OVERRIDES.
 *
 * Artists: songs on artist_unknown_artist ("Unknown Artist" / "Pahadi Folk")
 * are matched to an EXISTING artist only when that artist's name (or a known
 * alias) appears in the song's original filename (`sourceFile`). No match →
 * the repo's curatorial fallback "Pahadi Folk" (see polish_catalog.js).
 * Nothing is guessed beyond what the filename says.
 *
 * Re-derives titleLowercase / titleNormalized / artistNameLowercase /
 * albumTitleLowercase / searchKeywords so search keeps working. Ids, slugs,
 * audio/artwork URLs and publish state are never touched.
 *
 * Usage:
 *   node scripts/clean_metadata.js            # dry run → scripts/seed_data/metadata_cleanup_report.md
 *   node scripts/clean_metadata.js --apply    # writes (uses your `firebase login` session)
 *
 * Dry run reads Firestore through the public REST API (songs/artists/albums
 * are world-readable), so it needs no credentials. --apply first saves every
 * touched song's original fields to scripts/seed_data/metadata_cleanup_backup.json.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { PROJECT_ID } = require('./lib/constants');
const { loginHeaders, docWrite, commit } = require('./lib/firebase_rest');

const APPLY = process.argv.includes('--apply');
// Public web API key from lib/firebase_options.dart (not a secret).
const WEB_API_KEY = process.env.HIMRAAG_WEB_API_KEY || '';
const OUT_DIR = path.join(__dirname, 'seed_data');
const REPORT = path.join(OUT_DIR, 'metadata_cleanup_report.md');
const BACKUP = path.join(OUT_DIR, 'metadata_cleanup_backup.json');

const UNKNOWN_ID = 'artist_unknown_artist';
const FOLK_ARTIST = 'Pahadi Folk';
const FOLK_ALBUM_ID = 'album_unknown_artist__imported_recordings';
const FOLK_ALBUM = 'Pahadi Folk Collection';

// Misspellings seen in filenames → canonical artist name already in Firestore.
const ARTIST_ALIASES = {
  'atar shah': 'Attar Shah',
  'mohan sing chauhan': 'Mohan Singh Chauhan',
  'papu karki': 'Pappu Karki',
};

// Titles no rule can recover, keyed by doc id. Each comes from the song's own
// filename (often the Devanagari or hashtag part), transliterated where needed.
const OVERRIDES = {
  song_attar_shah__jamerya_butu_ki_jaunsari_old_dj_song_by_attar_shah: 'Jamerya Butu Ki',
  song_attar_shah__samar_films_present_s_song_dhyani_anita_singer_attar_shah_lyrics_devendra_rawat: 'Dhyani Anita',
  song_golu_kinnaura__all_himachal_latest_hindi_kinnaur_dancing_song_2024: 'All Himachal',
  song_mohan_singh_chauhan__avseq02_noori_artist_mohan_singh_chauhan: 'Noori',
  song_mohan_singh_chauhan__latest_pahari_song: 'Wadiyan Nonstop Natiyan',        // वादियां नाॅनस्टाप नाटीयां
  song_mohan_singh_chauhan__latest_phari_song_2023_by_mohan_singh_chauhan: 'Bragi Ram Ki Nati', // ब्रागी राम की नाटी
  song_mohan_singh_chauhan__original_track_swar_samrat_music_presents_by_mohan_singh_chauhan_traditional_son: 'Lota Ki Nati', // लोता की नाटी
  song_unknown_artist__dhalta_vol_0_1: 'Dhalta Vol. 1',
  song_unknown_artist__fyonladiya_kishan_mahipal: 'Fyonladiya',
  song_unknown_artist__jai_hatkoti_himachali_pahari_nati_mohan_singh_mp3: 'Jai Hatkoti',
  song_unknown_artist__latest_himachali_jaunsari_songs_2021: 'Himachali Jaunsari Songs 2021',
  song_unknown_artist__latest_kumauni_song_2021: 'Lal Botal Saraba',               // लाल बोतल शराबा
  song_unknown_artist__official: 'Huliya',
  song_unknown_artist__papu_karki_latest_kumaoni_songs_0: 'Bhainsi Ladhi Ho Maya', // भैंसी लढी हो माया
  song_unknown_artist__new_latest_video_song_anisha_ranghar_raj_tiger_sanju_silodi_reeta_dhyani_0: 'Main Chhon Noni Pauri Ki', // मैं छों नोनी पौड़ी कि
  song_unknown_artist__superhit_chomasa_new_jonsari_song_singer_atar_shah_rudransh_entertainment: 'Chomasa',
  song_yogi_chauhan__tabadtod_dj_nattiya: 'Tabadtod DJ Nattiya',
};

const norm = (v) => String(v || '').normalize('NFKD').replace(/[̀-ͯ]/g, '')
  .toLowerCase().replace(/[^a-z0-9ऀ-ॿ\s]/g, ' ').replace(/\s+/g, ' ').trim();
const terms = (...parts) => {
  const set = new Set();
  for (const p of parts) { const n = norm(p); if (!n) continue; set.add(n); for (const t of n.split(' ')) if (t.length > 1) set.add(t); }
  return [...set];
};

// Singers named outright in the filename ("SINGER_MICKY_DHALTA", "feat._Rongpaz",
// "___Pramod_Gazta___") but absent from the artists collection. Keyed by doc id.
const ARTIST_OVERRIDES = {
  song_unknown_artist__bodi_ka_thumka: 'Vijay Prakash',
  song_unknown_artist__dance_mantra: 'Shubham Verma',
  song_unknown_artist__dhalta_vol_0_1: 'Micky Dhalta',
  song_unknown_artist__ghumai_de_garhwali_song: 'Rongpaz',
  song_unknown_artist__helicopter_shot: 'Pramod Gazta',
  song_unknown_artist__khushi_ram_khush_mijaj_harul: 'Tripan Singh',
  song_unknown_artist__latest_kumauni_song_2021: 'Prakash Kahala',
  song_unknown_artist__mala_express: 'Narender Ranjan',
  song_unknown_artist__nati_online: 'Sandeep Sandy',
  song_unknown_artist__nati_shot_2_0: 'Happy Sehgal',
  song_unknown_artist__ramdai_ka_hotel_ii_chandani_enterprises_ii_kumaoni_song_ii_satendra_gangola_ii_l: 'Satendra Gangola',
  song_unknown_artist__rana_bhaine: 'Sunil & Prajul',
  song_unknown_artist__shiv_bhramkhada_by_dikshu_sharma: 'Dikshu Sharma',
};

// ── Title cleaning ──────────────────────────────────────────────────────────
const REGIONS = 'garhwali|ghadwali|kumaoni|kumauni|himachali|pahari|pahadi|phadi|jaunsari|jounsari|jonsari|kinnauri|uttarakhandi|uttrakhandi|hindi';
const LATEST = '(?:latest|lettest|leatest|latast)';
const NOISE_TAIL = new RegExp(
  '\\s+(?:' +
  `${LATEST}|(?:new|super ?hit|original track)\\b` +
  `|(?:(?:${REGIONS})\\s+)+(?:(?:hit|folk|dj|audio|video)\\s+)*songs?\\b` +
  '|(?:by|singer|lyrics)\\b' +
  '|songs?\\s+by\\b' +
  ').*$', 'i');
const NOISE_HEAD = new RegExp(
  `^(?:(?:${LATEST}|new|super ?hit)\\s+)*(?:(?:${REGIONS})\\s+)+(?:(?:hit|folk|dj|audio|video)\\s+)*songs?\\s*-?\\s*`, 'i');
const KEEP_CAPS = new Set(['DJ', 'AK', 'UK', 'NJ', 'II', 'PKC', 'EDM']);

function titleCase(w) {
  if (KEEP_CAPS.has(w) || /\d/.test(w)) return w;
  return w[0] + w.slice(1).toLowerCase();
}

/**
 * `isArtist(text)` lets a " - Singer Name" suffix be dropped while a real
 * subtitle ("Driver Horon Bajade Ho - Seema Raniye") is kept.
 */
function cleanTitle(raw, isArtist = () => false) {
  let t = String(raw || '');
  t = t.replace(/(?:\(\d+\))+\s*$/, '');                       // (0)(1) copy suffixes
  t = t.replace(/\.mp3$/i, '');
  t = t.replace(/[☀-➿\u{1F300}-\u{1FAFF}!]/gu, ' ');  // emoji, "!"
  t = t.replace(/#\S*/g, ' ');                                 // hashtags
  t = t.replace(/【\s*】/g, ' | ').replace(/\[[^\]]*\]/g, ' ');   // 【 】 and [Garhwali Song]
  if (t.includes('_')) {
    // Filename style: words joined by "_", fields separated by "__"+.
    const segs = t.split(/_{2,}/).map((s) => s.replace(/_/g, ' ').trim()).filter(Boolean);
    const latin = segs.filter((s) => /[a-z]/i.test(s));
    t = (latin.length ? latin : segs).join(' | ');
  }
  t = t.replace(/\s+I{1,2}\s+/g, ' | ');                       // " II " / " I " separators

  const strip = (s) => s.replace(NOISE_HEAD, '').replace(NOISE_TAIL, '').replace(/\s+(?:19|20)\d{2}\s*$/, '').trim();
  const isNoise = (s) => strip(s).length < 2 || new RegExp(`^${LATEST}`, 'i').test(strip(s));
  // Hard separators split independent fields: take the first one with real words.
  const fields = t.split(/\s*\|\s*/).map((s) => s.trim()).filter(Boolean);
  t = fields.find((s) => !isNoise(s)) || fields[0] || '';

  // " - " joins title parts; stop at the first part that is noise or a singer.
  const parts = t.split(/\s+-\s+/);
  while (parts.length > 1 && isNoise(parts[0])) parts.shift();  // "Pahari Song - O Beta Kewalaram"
  const kept = [];
  for (const part of parts) {
    if (kept.length && /^\d+$/.test(part.trim())) { kept.push(part.trim()); continue; } // "Meri AK47 - 2"
    if (kept.length && (isNoise(part) || NOISE_HEAD.test(part) || isArtist(part))) break;
    const clean = strip(part);
    kept.push(clean.length >= 2 ? clean : part.trim());
    if (clean !== part.trim()) break;                            // noise was cut off mid-part
  }
  t = kept.join(' - ');
  t = t.replace(/^[\s\-.,]+|[\s\-.,]+$/g, '').replace(/\s+/g, ' ');
  t = t.split(' ').map((w) => (/^[A-Z]{2,}$/.test(w) ? titleCase(w) : w)).join(' ');
  return t;
}

// ── Artist matching ─────────────────────────────────────────────────────────
function buildArtistMatcher(artists) {
  const byName = new Map(artists.map((a) => [a.name, a]));
  const cands = artists
    .filter((a) => a.id !== UNKNOWN_ID && a.name && a.name !== FOLK_ARTIST)
    .map((a) => ({ key: norm(a.name), artist: a }))
    .filter((c) => c.key.includes(' '));                       // single words match too loosely
  for (const [alias, name] of Object.entries(ARTIST_ALIASES)) {
    if (byName.has(name)) cands.push({ key: alias, artist: byName.get(name) });
  }
  cands.sort((a, b) => b.key.length - a.key.length);           // duet name beats solo name
  return (text) => {
    const hay = ` ${norm(text)} `;
    const hit = cands.find((c) => hay.includes(` ${c.key} `));
    return hit ? hit.artist : null;
  };
}

// ── Firestore access ────────────────────────────────────────────────────────
function decode(v) {
  if (!v) return v;
  if ('stringValue' in v) return v.stringValue;
  if ('integerValue' in v) return Number(v.integerValue);
  if ('doubleValue' in v) return v.doubleValue;
  if ('booleanValue' in v) return v.booleanValue;
  if ('nullValue' in v) return null;
  if ('timestampValue' in v) return v.timestampValue;
  if ('arrayValue' in v) return (v.arrayValue.values || []).map(decode);
  if ('mapValue' in v) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k, x]) => [k, decode(x)]));
  return undefined;
}

async function restList(collection) {
  const base = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}?pageSize=300&key=${WEB_API_KEY}`;
  const out = [];
  let token;
  do {
    const res = await fetch(base + (token ? `&pageToken=${encodeURIComponent(token)}` : ''));
    if (!res.ok) throw new Error(`${collection}: HTTP ${res.status}`);
    const body = await res.json();
    for (const d of body.documents || []) {
      out.push({ id: d.name.split('/').pop(), ...Object.fromEntries(Object.entries(d.fields || {}).map(([k, v]) => [k, decode(v)])) });
    }
    token = body.nextPageToken;
  } while (token);
  return out;
}

// ── Plan ────────────────────────────────────────────────────────────────────
function plan(songs, artists, albums) {
  const matchArtist = buildArtistMatcher(artists);
  const artistKeys = new Set([...artists.map((a) => norm(a.name)), ...Object.keys(ARTIST_ALIASES)]);
  const isArtist = (text) => artistKeys.has(norm(text));
  const artistsByKey = new Map(artists.map((a) => [norm(a.name), a]));
  const albumsByArtist = new Map();
  for (const a of albums) {
    if (!albumsByArtist.has(a.artistId)) albumsByArtist.set(a.artistId, []);
    albumsByArtist.get(a.artistId).push(a);
  }
  const newArtists = new Map();
  const newAlbums = new Map();
  const changes = [];

  const artistNamed = (name, from) => {
    const key = norm(name);
    if (artistsByKey.has(key)) return artistsByKey.get(key);
    const a = { id: `artist_${key.replace(/\s+/g, '_')}`, name, from };
    artistsByKey.set(key, a);
    newArtists.set(a.id, a);
    return a;
  };

  for (const s of songs) {
    const title = OVERRIDES[s.id] || cleanTitle(s.title, isArtist);
    let { artistId, artistName, albumId, albumTitle } = s;

    if (artistId === UNKNOWN_ID) {
      const hit = ARTIST_OVERRIDES[s.id]
        ? artistNamed(ARTIST_OVERRIDES[s.id], s)
        : matchArtist(`${s.sourceFile || ''} ${s.title || ''}`);
      if (hit) {
        artistId = hit.id;
        artistName = hit.name;
        const own = albumsByArtist.get(hit.id) || [];
        const album = own.find((a) => /singles$/i.test(a.title || '')) || own[0];
        if (album) {
          albumId = album.id; albumTitle = album.title;
        } else {
          const key = hit.id.replace(/^artist_/, '');
          albumId = `album_${key}__${key}_singles`;
          albumTitle = `${hit.name} — Singles`;
          const created = { id: albumId, title: albumTitle, artistId: hit.id, artist: hit, from: s };
          newAlbums.set(albumId, created);
          albumsByArtist.set(hit.id, [created]);
        }
      } else {
        artistName = FOLK_ARTIST;
        if (albumId === FOLK_ALBUM_ID) albumTitle = FOLK_ALBUM;
      }
    }

    const update = {};
    if (title && title !== s.title) update.title = title;
    if (artistId !== s.artistId) update.artistId = artistId;
    if (artistName !== s.artistName) update.artistName = artistName;
    if (albumId !== s.albumId) update.albumId = albumId;
    if (albumTitle !== s.albumTitle) update.albumTitle = albumTitle;
    if (!Object.keys(update).length) continue;

    const t = update.title || s.title;
    Object.assign(update, {
      titleLowercase: t.toLowerCase(),
      titleNormalized: norm(t),
      artistNameLowercase: (artistName || '').toLowerCase(),
      albumTitleLowercase: (albumTitle || '').toLowerCase(),
      searchKeywords: terms(t, artistName, albumTitle, s.region, s.language, s.genre),
    });
    changes.push({ song: s, update });
  }

  // Recount songs/albums for every artist and album a song moved between,
  // counting approved songs only (same rule as purge_pending_songs.js).
  const moved = changes.filter((c) => c.update.artistId || c.update.albumId);
  const touchedArtists = new Set(moved.flatMap((c) => [c.song.artistId, c.update.artistId || c.song.artistId]));
  const touchedAlbums = new Set(moved.flatMap((c) => [c.song.albumId, c.update.albumId || c.song.albumId]));
  const finalSongs = songs.map((s) => ({ ...s, ...(changes.find((c) => c.song.id === s.id)?.update || {}) }))
    .filter((s) => s.isApproved === true);
  const allAlbums = [...albums, ...newAlbums.values()];
  const counts = {
    artists: [...touchedArtists].map((id) => ({
      id,
      songCount: finalSongs.filter((s) => s.artistId === id).length,
      albumCount: allAlbums.filter((a) => a.artistId === id && finalSongs.some((s) => s.albumId === a.id)).length,
    })),
    albums: [...touchedAlbums].map((id) => {
      const tracks = finalSongs.filter((s) => s.albumId === id);
      return { id, songCount: tracks.length, totalDurationMs: tracks.reduce((m, s) => m + Number(s.durationMs || 0), 0) };
    }),
  };
  return { changes, newArtists: [...newArtists.values()], newAlbums: [...newAlbums.values()], counts };
}

function writeReport({ changes, newArtists, newAlbums }, total) {
  const esc = (v) => String(v ?? '').replace(/\|/g, '\\|');
  const titled = changes.filter((c) => c.update.title);
  const reartisted = changes.filter((c) => c.update.artistId);
  const folk = changes.filter((c) => c.update.artistName === FOLK_ARTIST);

  let md = `# Metadata cleanup — ${APPLY ? 'APPLIED' : 'dry run'} ${new Date().toISOString()}\n\n`;
  md += `Songs scanned: ${total} · songs changed: ${changes.length}\n\n`;
  md += `- Titles cleaned: ${titled.length}\n- Credited to a real artist (named in filename): ${reartisted.length}\n`;
  md += `- "Unknown Artist" → "${FOLK_ARTIST}" (no artist in filename): ${folk.length}\n`;
  md += `- New artists: ${newArtists.length} · new "Singles" albums: ${newAlbums.length}\n\n`;
  md += `## Title changes\n\n| # | Before | After | Doc id |\n|---|---|---|---|\n`;
  titled.forEach((c, i) => { md += `| ${i + 1} | ${esc(c.song.title)} | **${esc(c.update.title)}** | \`${c.song.id}\` |\n`; });
  md += `\n## Artist credits\n\n| # | Song | Before | After | Source file |\n|---|---|---|---|---|\n`;
  reartisted.forEach((c, i) => {
    md += `| ${i + 1} | ${esc(c.update.title || c.song.title)} | ${esc(c.song.artistName)} | **${esc(c.update.artistName)}** | ${esc(path.basename(String(c.song.sourceFile || '').replace(/\\/g, '/')))} |\n`;
  });
  md += `\n## New artists\n\n${newArtists.map((a) => `- ${a.name} (\`${a.id}\`)`).join('\n') || '_none_'}\n`;
  md += `\n## New albums\n\n${newAlbums.map((a) => `- ${a.title} (\`${a.id}\`)`).join('\n') || '_none_'}\n`;
  fs.writeFileSync(REPORT, md);
}

// ── Apply ───────────────────────────────────────────────────────────────────
async function apply({ changes, newArtists, newAlbums, counts }) {
  const headers = await loginHeaders();

  const backup = changes.map(({ song, update }) => ({
    id: song.id, fields: Object.fromEntries(Object.keys(update).map((k) => [k, song[k] ?? null])),
  }));
  fs.writeFileSync(BACKUP, JSON.stringify(backup, null, 1));
  console.log(`backup of original fields → ${path.relative(process.cwd(), BACKUP)}`);

  const writes = [
    ...newArtists.map((a) => docWrite('artists', a.id, {
      id: a.id, name: a.name, nameLowercase: a.name.toLowerCase(), nameNormalized: norm(a.name),
      searchKeywords: terms(a.name, a.from.region, a.from.genre), region: a.from.region, imageUrl: a.from.artworkUrl,
      genres: [a.from.genre], songCount: 0, albumCount: 0, isVerified: true, isPublished: true,
      approvalStatus: 'approved', slug: norm(a.name).replace(/\s+/g, '-'), bio: `${a.name} — imported.`,
    }, false)),
    ...newAlbums.map((a) => docWrite('albums', a.id, {
      id: a.id, title: a.title, titleLowercase: a.title.toLowerCase(), titleNormalized: norm(a.title),
      searchKeywords: terms(a.title, a.artist.name, a.from.region), artistId: a.artist.id, artistName: a.artist.name,
      artworkUrl: a.from.artworkUrl, region: a.from.region, language: a.from.language, genre: a.from.genre,
      releaseYear: a.from.releaseYear, license: a.from.license, isApproved: true, isPublished: true,
      approvalStatus: 'approved', rightsCleared: true, slug: norm(a.title).replace(/\s+/g, '-'),
    }, false)),
    ...changes.map(({ song, update }) => docWrite('songs', song.id, update, true)),
    // New docs are created earlier in this same commit, so skip the exists check for them.
    ...counts.artists.map(({ id, ...n }) => docWrite('artists', id, n, !newArtists.some((a) => a.id === id))),
    ...counts.albums.map(({ id, ...n }) => docWrite('albums', id, n, !newAlbums.some((a) => a.id === id))),
  ];
  await commit(writes, headers);
  console.log(`committed ${writes.length} writes (${newArtists.length} new artists, ${newAlbums.length} new albums, ${changes.length} songs, ${counts.artists.length + counts.albums.length} count fixes)`);
}

async function main() {
  const [songs, artists, albums] = await Promise.all([restList('songs'), restList('artists'), restList('albums')]);
  const result = plan(songs, artists, albums);
  writeReport(result, songs.length);
  console.log(`songs=${songs.length} changed=${result.changes.length} newArtists=${result.newArtists.length} newAlbums=${result.newAlbums.length}`);
  console.log(`report → ${path.relative(process.cwd(), REPORT)}`);
  if (APPLY) await apply(result);
  else console.log('dry run — nothing written. Re-run with --apply to write.');
}

if (require.main === module) {
  main().then(() => process.exit(0)).catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
}

module.exports = { cleanTitle };
