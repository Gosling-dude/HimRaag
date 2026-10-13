/**
 * Import hand-curated MP3s into the live catalog.
 *
 * Reads a manifest (default scripts/seed_data/new_songs_2026_10.json) whose
 * entries name a file under the source folder plus title, lead singer, full
 * credit, region, genre, mood, year and an optional featuredRank. For each:
 *   - duration from ffprobe; the embedded cover art becomes the artwork
 *     (600px) and thumbnail (400px) — songs keep their real covers;
 *   - audio + art uploaded to R2 (wrangler login);
 *   - songs/<id> written approved + published, linked to the lead singer's
 *     artist doc (created when missing, with no image — the app shows
 *     initials) and that artist's "Singles" album (created when missing);
 *   - song/album counts recomputed for every touched artist and album.
 * A song already live (same normalized title and duration within 2 s, or the
 * same doc id) is skipped, so re-running is safe.
 *
 * Usage:
 *   node scripts/import_new_songs.js [manifest.json] [--source <dir>]          # dry run
 *   node scripts/import_new_songs.js [manifest.json] [--source <dir>] --apply  # upload + write
 */
'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync, spawnSync } = require('child_process');
const { PROJECT_ID } = require('./lib/constants');
const { loginHeaders, docWrite, commit } = require('./lib/firebase_rest');
const { upload } = require('./lib/r2_wrangler');

const argv = process.argv.slice(2);
const APPLY = argv.includes('--apply');
const sourceArg = argv.indexOf('--source');
const repoRoot = path.dirname(__dirname);
const SOURCE = sourceArg >= 0 ? argv[sourceArg + 1] : path.join(repoRoot, 'New songs to add');
const MANIFEST = argv.find((a, i) => !a.startsWith('--') && argv[i - 1] !== '--source')
  || path.join(__dirname, 'seed_data', 'new_songs_2026_10.json');

const FOLK_ARTIST_ID = 'artist_unknown_artist';
const FOLK_ALBUM_ID = 'album_unknown_artist__imported_recordings';
const FOLK_ALBUM = 'Pahadi Folk Collection';
const ART_VER = 'v1';

const norm = (v) => String(v || '').normalize('NFKD').replace(/[̀-ͯ]/g, '')
  .toLowerCase().replace(/[^a-z0-9ऀ-ॿ\s]/g, ' ').replace(/\s+/g, ' ').trim();
const key = (v) => norm(v).replace(/\s+/g, '_');
const slug = (v) => norm(v).replace(/\s+/g, '-');
const terms = (...parts) => {
  const set = new Set();
  for (const p of parts) { const n = norm(p); if (!n) continue; set.add(n); for (const t of n.split(' ')) if (t.length > 1) set.add(t); }
  return [...set];
};

async function list(collection) {
  const base = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${collection}?pageSize=300`;
  const out = [];
  let token;
  do {
    const body = await (await fetch(base + (token ? `&pageToken=${encodeURIComponent(token)}` : ''))).json();
    if (body.error) throw new Error(`${collection}: ${body.error.message}`);
    for (const d of body.documents || []) {
      const f = d.fields || {};
      const v = (k) => f[k] && Object.values(f[k])[0];
      out.push({
        id: d.name.split('/').pop(), name: v('name'), title: v('title'), artistId: v('artistId'),
        albumId: v('albumId'), isApproved: v('isApproved'), durationMs: Number(v('durationMs') || 0),
      });
    }
    token = body.nextPageToken;
  } while (token);
  return out;
}

function durationMs(file) {
  const out = execFileSync('ffprobe', ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', file]);
  return Math.round(parseFloat(out.toString()) * 1000);
}

/** Embedded cover → square JPEG of [size]px in a temp file. Covers are often
 * 16:9 video thumbnails letterboxed into a square, so the black bars are
 * detected and cut first, then the picture is centre-cropped to a square. */
function cover(file, size, tag) {
  // cropdetect reports on stderr.
  const detect = spawnSync('ffmpeg', ['-loglevel', 'info', '-i', file, '-an', '-frames:v', '1',
    '-vf', 'cropdetect=limit=24:round=2:reset=0:skip=0', '-f', 'null', '-']);
  const box = /crop=(\d+:\d+:\d+:\d+)/.exec(detect.stderr.toString()) || [];
  const out = path.join(os.tmpdir(), `himraag-cover-${tag}-${size}.jpg`);
  const filters = [box[1] ? `crop=${box[1]}` : null,
    `scale=${size}:${size}:force_original_aspect_ratio=increase`, `crop=${size}:${size}`].filter(Boolean);
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', '-i', file, '-an', '-frames:v', '1', '-vf',
    filters.join(','), '-q:v', '3', out]);
  return out;
}

async function main() {
  const manifest = JSON.parse(fs.readFileSync(MANIFEST, 'utf8'));
  const [songs, artists, albums] = await Promise.all([list('songs'), list('artists'), list('albums')]);
  const songIds = new Set(songs.map((s) => s.id));
  const artistByName = new Map(artists.map((a) => [norm(a.name), a]));
  const newArtists = new Map();
  const newAlbums = new Map();
  const plan = [];
  const skipped = [];

  for (const e of manifest.songs) {
    const file = path.join(SOURCE, e.file);
    if (!fs.existsSync(file)) throw new Error(`missing file: ${e.file}`);
    const ms = durationMs(file);

    let artistId = FOLK_ARTIST_ID;
    let albumId = FOLK_ALBUM_ID;
    let albumTitle = FOLK_ALBUM;
    if (e.lead) {
      let artist = artistByName.get(norm(e.lead));
      if (!artist) {
        artist = { id: `artist_${key(e.lead)}`, name: e.lead, region: e.region, genre: e.genre };
        artistByName.set(norm(e.lead), artist);
        newArtists.set(artist.id, artist);
      }
      artistId = artist.id;
      const own = albums.filter((a) => a.artistId === artistId);
      const album = own.find((a) => /singles$/i.test(a.title || '')) || own[0] || newAlbums.get(`album_${key(e.lead)}__${key(e.lead)}_singles`);
      if (album) {
        albumId = album.id; albumTitle = album.title;
      } else {
        albumId = `album_${key(e.lead)}__${key(e.lead)}_singles`;
        albumTitle = `${e.lead} — Singles`;
        newAlbums.set(albumId, { id: albumId, title: albumTitle, artistId, artistName: e.lead, region: e.region, genre: e.genre, year: e.year });
      }
    }

    const id = `song_${artistId.replace(/^artist_/, '')}__${key(e.title)}`;
    const dupe = songIds.has(id) ? id : songs.find((s) => norm(s.title) === norm(e.title) && Math.abs(s.durationMs - ms) <= 2000)?.id;
    if (dupe) { skipped.push(`${e.title} (already live as ${dupe})`); continue; }
    plan.push({ e, file, id, ms, artistId, albumId, albumTitle, slug: slug(`${e.title} ${e.credit}`) });
  }

  console.log(`manifest=${manifest.songs.length} import=${plan.length} skipped=${skipped.length} newArtists=${newArtists.size} newAlbums=${newAlbums.size}`);
  for (const s of skipped) console.log(`  skip: ${s}`);
  for (const p of plan) {
    console.log(`  + ${p.e.title} — ${p.e.credit} [${p.e.region}/${p.e.genre}] ${Math.round(p.ms / 1000)}s → ${p.artistId}`
      + `${p.e.featuredRank ? ` (banner #${p.e.featuredRank})` : ''}`);
  }
  for (const a of newArtists.values()) console.log(`  new artist: ${a.name} (${a.id})`);
  if (!APPLY) { console.log('dry run — nothing uploaded or written. Re-run with --apply.'); return; }

  const writes = [];
  for (const [i, p] of plan.entries()) {
    const audioUrl = upload(p.file, `audio/${p.slug}.mp3`, 'audio/mpeg');
    const artworkUrl = upload(cover(p.file, 600, i), `artwork/${p.slug}-${ART_VER}.jpg`, 'image/jpeg');
    const thumbnailUrl = upload(cover(p.file, 400, i), `artwork/${p.slug}-${ART_VER}-t400.jpg`, 'image/jpeg');
    const e = p.e;
    const language = e.region;
    writes.push(docWrite('songs', p.id, {
      title: e.title, titleLowercase: e.title.toLowerCase(), titleNormalized: norm(e.title), slug: p.slug,
      artistId: p.artistId, artistName: e.credit, artistNameLowercase: e.credit.toLowerCase(),
      albumId: p.albumId, albumTitle: p.albumTitle, albumTitleLowercase: p.albumTitle.toLowerCase(),
      audioUrl, artworkUrl, thumbnailUrl, durationMs: p.ms,
      region: e.region, language, genre: e.genre, mood: e.mood || null, tags: [norm(e.region), norm(e.genre), ...(e.tags || [])],
      ...(e.year ? { releaseYear: e.year } : {}),
      ...(e.featuredRank ? { featuredRank: e.featuredRank } : {}),
      playCount: 0, license: 'LICENSED', rightsCleared: true, isDownloadable: true,
      attribution: 'Supplied by the app owner. Audio streams from Cloudflare R2.',
      sourceFile: e.file, approvalStatus: 'approved', isApproved: true, isPublished: true, reviewRequired: false,
      searchKeywords: terms(e.title, e.credit, p.albumTitle, e.region, language, e.genre),
    }, false));
    process.stdout.write(`\r  uploaded ${i + 1}/${plan.length}`);
  }
  console.log();

  for (const a of newArtists.values()) {
    writes.unshift(docWrite('artists', a.id, {
      id: a.id, name: a.name, nameLowercase: a.name.toLowerCase(), nameNormalized: norm(a.name),
      searchKeywords: terms(a.name, a.region, a.genre), region: a.region, imageUrl: '', genres: [a.genre],
      songCount: 0, albumCount: 0, isVerified: true, isPublished: true, approvalStatus: 'approved',
      slug: slug(a.name), bio: '',
    }, false));
  }
  for (const a of newAlbums.values()) {
    const first = plan.find((p) => p.albumId === a.id);
    writes.unshift(docWrite('albums', a.id, {
      id: a.id, title: a.title, titleLowercase: a.title.toLowerCase(), titleNormalized: norm(a.title),
      searchKeywords: terms(a.title, a.artistName, a.region), artistId: a.artistId, artistName: a.artistName,
      artworkUrl: `${require('./lib/r2_wrangler').PUBLIC_BASE}/artwork/${first.slug}-${ART_VER}.jpg`,
      region: a.region, language: a.region, genre: a.genre, ...(a.year ? { releaseYear: a.year } : {}),
      license: 'LICENSED', isApproved: true, isPublished: true, approvalStatus: 'approved', rightsCleared: true,
      slug: slug(a.title),
    }, false));
  }

  // Recount every touched artist/album over the final approved catalog.
  const finalSongs = [...songs.filter((s) => s.isApproved === true),
    ...plan.map((p) => ({ artistId: p.artistId, albumId: p.albumId, durationMs: p.ms }))];
  const allAlbums = [...albums, ...newAlbums.values()];
  for (const id of new Set(plan.map((p) => p.artistId))) {
    const mine = finalSongs.filter((s) => s.artistId === id);
    const albumCount = allAlbums.filter((a) => a.artistId === id && finalSongs.some((s) => s.albumId === a.id)).length;
    writes.push(docWrite('artists', id, { songCount: mine.length, albumCount }, false));
  }
  for (const id of new Set(plan.map((p) => p.albumId))) {
    const tracks = finalSongs.filter((s) => s.albumId === id);
    writes.push(docWrite('albums', id, {
      songCount: tracks.length, totalDurationMs: tracks.reduce((m, s) => m + s.durationMs, 0),
    }, false));
  }

  await commit(writes, await loginHeaders());
  console.log(`committed ${writes.length} writes: ${plan.length} songs, ${newArtists.size} artists, ${newAlbums.size} albums + counts`);
}

main().then(() => process.exit(0)).catch((e) => { console.error('FAILED:', e.message); process.exit(1); });
