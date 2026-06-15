/**
 * Generate the HimRaag demo seed catalog → scripts/seed_data/catalog.json
 *
 * Produces 110+ DEMO-ONLY tracks spanning all four mandatory Pahadi regions
 * (Garhwali, Kumaoni, Jaunsari, Himachali) plus Kinnauri & Sirmauri.
 *
 * LEGAL SAFETY (per project content rules):
 *   - Every entry is license='DEMO_ONLY', approvalStatus='demo',
 *     isPublished=false, rightsCleared=false → never shippable publicly.
 *   - Song TITLES are traditional/public-domain Pahadi folk songs (not owned
 *     by anyone). Performers are "Traditional (<region>)" or clearly-fictional
 *     "(Demo)" ensembles — NO real living artists are represented.
 *   - AUDIO is a royalty-free CC pool (SoundHelix). ARTWORK is picsum.photos
 *     placeholder. The `attribution` field states this verbatim so nothing
 *     misrepresents an original recording.
 *
 * The output is ingested by the validating import pipeline:
 *   node scripts/import.js --json scripts/seed_data/catalog.json [--commit]
 *
 * Deterministic — re-running yields identical ids (safe to re-seed).
 */

'use strict';

const fs = require('fs');
const path = require('path');
const {
  slugify,
  songId,
  artistId,
  albumId,
} = require('./lib/validator');
const { MANDATORY_REGIONS } = require('./lib/constants');

// ─── Audio: royalty-free CC pool (placeholders, not original recordings) ───────
const AUDIO_POOL = Array.from(
  { length: 16 },
  (_, i) => `https://www.soundhelix.com/examples/mp3/SoundHelix-Song-${i + 1}.mp3`
);
const SOURCE_URL = 'https://www.soundhelix.com/audio-examples';
const LICENSE_URL = 'https://creativecommons.org/publicdomain/zero/1.0/';
const ATTRIBUTION =
  'Audio: SoundHelix royalty-free sample (soundhelix.com) — placeholder, NOT ' +
  'the original recording. Title is a traditional Pahadi folk song (public ' +
  'domain). Artwork: picsum.photos placeholder. DEMO ONLY — do not publish.';

function artImg(seed) {
  return `https://picsum.photos/seed/${seed}/600/600`;
}

// ─── Region → demo performers (no real living artists) ─────────────────────────
const PERFORMERS = {
  Garhwali: ['Traditional (Garhwali)', 'HimRaag Demo Ensemble'],
  Kumaoni: ['Traditional (Kumaoni)', 'Kumaoni Heritage Voices (Demo)'],
  Jaunsari: ['Traditional (Jaunsari)', 'Jaunsar Bawar Folk Group (Demo)'],
  Himachali: ['Traditional (Himachali)', 'Himachali Naati Collective (Demo)'],
  Kinnauri: ['Traditional (Kinnauri)', 'Kinnaur Demo Folk Group'],
  Sirmauri: ['Traditional (Sirmauri)', 'Sirmaur Folk Project (Demo)'],
};

// ─── Region → traditional folk titles (public-domain) with a genre + mood ──────
// Genres are drawn from AppConstants.pahadiGenres.
const G = {
  folk: 'Folk',
  dev: 'Devotional',
  fest: 'Festival',
  wed: 'Wedding',
  seas: 'Seasonal',
  inst: 'Instrumental',
  cont: 'Contemporary Folk',
};

const TITLES = {
  Garhwali: [
    ['Bedu Pako Baramasa', G.folk, 'joyful'],
    ['Ghughuti Ghuran Laagi', G.folk, 'nostalgic'],
    ['Phyonli', G.seas, 'peaceful'],
    ['Chaita Ki Chaitwali', G.seas, 'joyful'],
    ['Jhumailo', G.folk, 'celebratory'],
    ['Chaufla Nritya', G.fest, 'energetic'],
    ['Thadya Geet', G.fest, 'energetic'],
    ['Bajuband', G.folk, 'melancholic'],
    ['Mangal Geet', G.wed, 'joyful'],
    ['Nanda Raj Jaat', G.dev, 'devotional'],
    ['Khuded Geet', G.folk, 'melancholic'],
    ['Dholki Ki Thaap', G.inst, 'energetic'],
  ],
  Kumaoni: [
    ['Nyoli', G.folk, 'melancholic'],
    ['Jhoda', G.fest, 'celebratory'],
    ['Chanchari', G.fest, 'energetic'],
    ['Bair', G.folk, 'reflective'],
    ['Kumaoni Holi Geet', G.fest, 'celebratory'],
    ['Chhapeli', G.folk, 'joyful'],
    ['Bhgnaul', G.folk, 'reflective'],
    ['Malushahi', G.folk, 'romantic'],
    ['Hiljatra Geet', G.fest, 'energetic'],
    ['Nanda Devi Jagar', G.dev, 'devotional'],
    ['Suwa Re', G.wed, 'joyful'],
    ['Daanpur Ki Doli', G.wed, 'nostalgic'],
  ],
  Jaunsari: [
    ['Jaunsari Naati', G.folk, 'energetic'],
    ['Harul', G.folk, 'reflective'],
    ['Tandi Nritya', G.fest, 'energetic'],
    ['Rasau', G.fest, 'celebratory'],
    ['Jhenta', G.folk, 'joyful'],
    ['Barada Nati', G.folk, 'energetic'],
    ['Maroz Geet', G.fest, 'celebratory'],
    ['Pahari Bansuri', G.inst, 'peaceful'],
  ],
  Himachali: [
    ['Himachali Naati', G.folk, 'energetic'],
    ['Chamba Kunjri Malhar', G.folk, 'romantic'],
    ['Gaddi Geet', G.folk, 'peaceful'],
    ['Jhoori', G.folk, 'romantic'],
    ['Laman', G.folk, 'reflective'],
    ['Pahari Holi', G.fest, 'celebratory'],
    ['Karyala Geet', G.fest, 'energetic'],
    ['Mela Geet', G.fest, 'joyful'],
    ['Shivratri Jagran', G.dev, 'devotional'],
    ['Nati Dhun', G.inst, 'energetic'],
  ],
  Kinnauri: [
    ['Kayang', G.fest, 'energetic'],
    ['Burah', G.folk, 'reflective'],
    ['Bonyangchu', G.folk, 'peaceful'],
    ['Phulaich Geet', G.fest, 'celebratory'],
    ['Losar Geet', G.fest, 'joyful'],
    ['Kinnauri Bansuri', G.inst, 'peaceful'],
    ['Sangla Valley Geet', G.folk, 'nostalgic'],
    ['Chhang Geet', G.fest, 'celebratory'],
  ],
  Sirmauri: [
    ['Sirmauri Naati', G.folk, 'energetic'],
    ['Giripar Harul', G.folk, 'reflective'],
    ['Rihali Geet', G.fest, 'celebratory'],
    ['Bishu Mela Geet', G.fest, 'joyful'],
    ['Pahari Laman', G.folk, 'romantic'],
    ['Dhol Damau', G.inst, 'energetic'],
    ['Shilai Geet', G.folk, 'peaceful'],
    ['Renuka Geet', G.dev, 'devotional'],
  ],
};

// ─── Demo lyrics (subset, to exercise the lyrics view) ─────────────────────────
// Clearly marked as demo placeholders. The Bedu Pako refrain is a genuinely
// public-domain traditional Garhwali folk line; the rest are placeholders to be
// replaced with verified/licensed lyrics before any public release.
const DEMO_LYRICS = {
  'Bedu Pako Baramasa':
    'Bedu pako baara maasa, narendra! kaafal pako chaita\n' +
    'Bedu pako baara maasa, kaafal pako chaita, meri chhaila...\n\n' +
    '(Traditional Garhwali folk refrain — public domain. DEMO entry.)',
  Nyoli:
    '(DEMO placeholder lyrics for the traditional Kumaoni "Nyoli" form.\n' +
    'Replace with verified/licensed lyrics before publishing.)',
  'Jaunsari Naati':
    '(DEMO placeholder lyrics for a Jaunsari "Naati" dance song.\n' +
    'Replace with verified/licensed lyrics before publishing.)',
  'Himachali Naati':
    '(DEMO placeholder lyrics for a Himachali "Naati".\n' +
    'Replace with verified/licensed lyrics before publishing.)',
  Kayang:
    '(DEMO placeholder lyrics for the Kinnauri "Kayang" dance song.\n' +
    'Replace with verified/licensed lyrics before publishing.)',
  'Sirmauri Naati':
    '(DEMO placeholder lyrics for a Sirmauri "Naati".\n' +
    'Replace with verified/licensed lyrics before publishing.)',
};

// ─── Build ─────────────────────────────────────────────────────────────────────

let audioIdx = 0;
let yearSeed = 0;
const songs = [];
const artistsMap = new Map();
const albumsMap = new Map();

function ensureArtist(name, region, genre) {
  const id = artistId(name);
  if (!artistsMap.has(id)) {
    const isTraditional = name.startsWith('Traditional');
    artistsMap.set(id, {
      id,
      name,
      imageUrl: artImg(`artist_${slugify(name)}`),
      region,
      bio: isTraditional
        ? `Traditional ${region} folk repertoire performed for HimRaag's demo ` +
          `catalog. Placeholder profile — not a real artist.`
        : `${name} is a fictional demo ensemble used to populate HimRaag's ` +
          `${region} test catalog. Placeholder profile — not a real artist.`,
      songCount: 0,
      albumCount: 0,
      genres: [genre],
      monthlyListeners: 0,
      isVerified: false,
      socialLinks: {},
      slug: slugify(name),
      approvalStatus: 'demo',
      isPublished: false,
      rightsNote: 'Demo placeholder — no rights granted. Not a real artist.',
    });
  }
  const a = artistsMap.get(id);
  a.songCount += 1;
  if (!a.genres.includes(genre)) a.genres.push(genre);
  return a;
}

function ensureAlbum(title, artistName, region, language, genre, year, artSeed) {
  const id = albumId(artistName, title);
  if (!albumsMap.has(id)) {
    albumsMap.set(id, {
      id,
      title,
      artistId: artistId(artistName),
      artistName,
      artworkUrl: artImg(artSeed),
      region,
      language,
      genre,
      releaseYear: year,
      songCount: 0,
      totalDurationMs: 0,
      description: `${title} — a HimRaag demo album of traditional ${region} ` +
        `folk songs. DEMO ONLY, not for public release.`,
      tags: [region.toLowerCase(), genre.toLowerCase(), 'demo'],
      slug: slugify(title),
      license: 'DEMO_ONLY',
      attribution: ATTRIBUTION,
      approvalStatus: 'demo',
      isPublished: false,
      rightsCleared: false,
    });
    artistsMap.get(artistId(artistName)).albumCount += 1;
  }
  return albumsMap.get(id);
}

for (const region of Object.keys(TITLES)) {
  const performers = PERFORMERS[region];
  const titles = TITLES[region];
  titles.forEach(([title, genre, mood], ti) => {
    // Each traditional title is "covered" by both demo performers of the region.
    performers.forEach((performer, pi) => {
      const language = region; // language mirrors region for these folk songs
      const year = 2018 + ((yearSeed++) % 7); // 2018..2024
      const albumTitle = `${region} Folk Treasures (Demo) Vol. ${pi + 1}`;
      const artSeed = `album_${slugify(performer)}_${pi + 1}`;
      const artist = ensureArtist(performer, region, genre);
      const album = ensureAlbum(albumTitle, performer, region, language, genre, year, artSeed);

      const durationMs = (165 + ((ti * 17 + pi * 31) % 230)) * 1000; // 2:45 .. 6:35
      const audioUrl = AUDIO_POOL[audioIdx++ % AUDIO_POOL.length];
      const id = songId(performer, title);
      const playCount = ((ti + 1) * 137 + pi * 53) % 9000;

      const song = {
        id,
        title,
        slug: slugify(title),
        artistId: artist.id,
        artistName: performer,
        albumId: album.id,
        albumTitle,
        audioUrl,
        artworkUrl: album.artworkUrl,
        durationMs,
        region,
        language,
        genre,
        releaseYear: year,
        playCount,
        tags: [region.toLowerCase(), genre.toLowerCase(), mood, 'demo'],
        mood,
        license: 'DEMO_ONLY',
        attribution: ATTRIBUTION,
        licenseUrl: LICENSE_URL,
        sourceUrl: SOURCE_URL,
        approvalStatus: 'demo',
        isPublished: false,
        rightsCleared: false,
        isDownloadable: true,
      };
      if (DEMO_LYRICS[title]) song.lyrics = DEMO_LYRICS[title];
      songs.push(song);
      album.songCount += 1;
      album.totalDurationMs += durationMs;
    });
  });
}

const catalog = {
  _meta: {
    generatedAt: new Date().toISOString(),
    note: 'DEMO-ONLY catalog. All entries license=DEMO_ONLY, isPublished=false. ' +
      'Never ship publicly. Replace with licensed content before release.',
    songCount: songs.length,
    albumCount: albumsMap.size,
    artistCount: artistsMap.size,
  },
  artists: [...artistsMap.values()],
  albums: [...albumsMap.values()],
  songs,
};

// ─── Coverage assertions ───────────────────────────────────────────────────────
const regionsCovered = new Set(songs.map((s) => s.region));
const missing = MANDATORY_REGIONS.filter((r) => !regionsCovered.has(r));
if (missing.length) {
  console.error(`ERROR: missing mandatory region(s): ${missing.join(', ')}`);
  process.exit(1);
}
if (songs.length < 100) {
  console.error(`ERROR: only ${songs.length} songs generated (need >= 100).`);
  process.exit(1);
}

const outDir = path.join(__dirname, 'seed_data');
fs.mkdirSync(outDir, { recursive: true });
const outPath = path.join(outDir, 'catalog.json');
fs.writeFileSync(outPath, JSON.stringify(catalog, null, 2));

console.log(`✅ Generated demo catalog → ${path.relative(process.cwd(), outPath)}`);
console.log(`   ${songs.length} songs · ${albumsMap.size} albums · ${artistsMap.size} artists`);
console.log(`   Regions: ${[...regionsCovered].join(', ')}`);
console.log('   All DEMO_ONLY / isPublished=false. Validate with:');
console.log('     node scripts/import.js --json scripts/seed_data/catalog.json --no-network');
