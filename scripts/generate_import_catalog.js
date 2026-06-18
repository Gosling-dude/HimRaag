/**
 * HimRaag — catalog generator (R2 + Firestore architecture).
 *
 * Merges Phase 2 enrichment (scripts/seed_data/enriched.json) with the Phase 3
 * R2 upload manifest (scripts/seed_data/r2_manifest.json) into:
 *
 *   1. assets/catalog/imported_catalog.json     (bundled, app runtime source)
 *      scripts/seed_data/imported_catalog.json  (same content, for reference)
 *        → audioUrl/artworkUrl point at Cloudflare R2 (NO bundled MP3s)
 *        → license LICENSED, approved + published  → visible in-app immediately
 *        → reviewRequired=true, tagged needs-metadata-review
 *
 *   2. scripts/seed_data/firestore_import.json   (Firestore seed, Phase 4)
 *        → same records, but approvalStatus=pending, isApproved=false,
 *          isPublished=false, reviewRequired=true  → Metadata Review queue
 *
 * Audio streams from R2; this generator NO LONGER copies MP3s into assets/audio.
 *
 * Usage:  node scripts/generate_import_catalog.js
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { slugify, songId, artistId, albumId } = require('./lib/validator');
const { NEEDS_REVIEW } = require('./lib/constants');

const ROOT = path.resolve(__dirname, '..');
const ENRICHED = path.join(__dirname, 'seed_data', 'enriched.json');
const MANIFEST = path.join(__dirname, 'seed_data', 'r2_manifest.json');
const OUT_SEED = path.join(__dirname, 'seed_data', 'imported_catalog.json');
const OUT_FS = path.join(__dirname, 'seed_data', 'firestore_import.json');
const ASSET_CATALOG_DIR = path.join(ROOT, 'assets', 'catalog');
const ASSET_CATALOG = path.join(ASSET_CATALOG_DIR, 'imported_catalog.json');

const PLACEHOLDER_ARTIST = 'Unknown Artist';
const PLACEHOLDER_ALBUM = 'Imported Recordings';
const LICENSE = 'LICENSED';
const REVIEW_TAG = 'needs-metadata-review';
const YEAR = new Date().getFullYear();

const ATTRIBUTION =
  'Locally-imported recording supplied by the app owner. Audio streams from ' +
  'Cloudflare R2. Metadata derived from filename + public sources during import; ' +
  'pending owner review in the Admin Dashboard.';

function load(file, label) {
  if (!fs.existsSync(file)) {
    console.error(`Missing ${label}: ${file}`);
    process.exit(1);
  }
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function albumFor(artistName) {
  return artistName === PLACEHOLDER_ARTIST
    ? PLACEHOLDER_ALBUM
    : `${artistName} — Singles`;
}

function main() {
  const enriched = load(ENRICHED, 'enriched.json').tracks;
  const manifest = load(MANIFEST, 'r2_manifest.json');
  const urlByFile = new Map(manifest.objects.map((o) => [o.sourceFile, o]));

  const songs = [];
  for (const t of enriched) {
    const obj = urlByFile.get(t.sourceFile);
    if (!obj) {
      console.warn(`  ⚠️  no R2 object for ${t.filename} — skipped`);
      continue;
    }
    const albumTitle = albumFor(t.artistName);
    const tags = ['imported', REVIEW_TAG];
    if (t.region === NEEDS_REVIEW) tags.push('needs-region');
    songs.push({
      id: songId(t.artistName, t.title),
      title: t.title,
      slug: slugify(t.title),
      artistId: artistId(t.artistName),
      artistName: t.artistName,
      albumId: albumId(t.artistName, albumTitle),
      albumTitle,
      audioUrl: obj.audioUrl, // Cloudflare R2
      artworkUrl: obj.artworkUrl, // Cloudflare R2
      durationMs: t.durationMs,
      region: t.region,
      language: t.language,
      genre: t.genre,
      releaseYear: Number.isFinite(t.releaseYear) ? t.releaseYear : YEAR,
      playCount: 0,
      tags,
      license: LICENSE,
      attribution: ATTRIBUTION,
      rightsCleared: true,
      isDownloadable: true,
      reviewRequired: true,
      // Provenance.
      sourceFile: t.sourceFile,
      enrichmentConfidence: t.overallConfidence,
    });
  }

  // ── Derive artists (dedup by id) ────────────────────────────────────────
  const artistMap = new Map();
  for (const s of songs) {
    if (!artistMap.has(s.artistId)) {
      artistMap.set(s.artistId, {
        id: s.artistId,
        name: s.artistName,
        imageUrl: s.artworkUrl,
        region: s.region,
        bio: s.artistName === PLACEHOLDER_ARTIST
          ? 'Placeholder profile for imported recordings whose artist is not yet '
            + 'identified. Reassign tracks to real artists in the dashboard.'
          : `${s.artistName} — ${s.region} Pahadi artist (imported catalog).`,
        songCount: 0,
        albumCount: 0,
        genres: [],
        monthlyListeners: 0,
        isVerified: false,
        socialLinks: {},
        slug: slugify(s.artistName),
        rightsNote: 'Imported — pending review.',
      });
    }
    const a = artistMap.get(s.artistId);
    a.songCount += 1;
    if (!a.genres.includes(s.genre)) a.genres.push(s.genre);
  }

  // ── Derive albums (dedup by id) ─────────────────────────────────────────
  const albumMap = new Map();
  for (const s of songs) {
    if (!albumMap.has(s.albumId)) {
      albumMap.set(s.albumId, {
        id: s.albumId,
        title: s.albumTitle,
        artistId: s.artistId,
        artistName: s.artistName,
        artworkUrl: s.artworkUrl,
        region: s.region,
        language: s.language,
        genre: s.genre,
        releaseYear: s.releaseYear,
        songCount: 0,
        totalDurationMs: 0,
        description: `${s.albumTitle} — imported recordings pending review.`,
        tags: ['imported', REVIEW_TAG],
        slug: slugify(s.albumTitle),
        license: LICENSE,
        attribution: ATTRIBUTION,
        rightsCleared: true,
      });
    }
    const al = albumMap.get(s.albumId);
    al.songCount += 1;
    al.totalDurationMs += s.durationMs;
  }
  for (const al of albumMap.values()) {
    const a = artistMap.get(al.artistId);
    if (a) a.albumCount += 1;
  }

  const artists = [...artistMap.values()];
  const albums = [...albumMap.values()];

  // ── Two visibility profiles ─────────────────────────────────────────────
  // App catalog: approved + published → visible to consumers immediately.
  const appProfile = { approvalStatus: 'approved', isApproved: true, isPublished: true };
  // Firestore: pending review → Metadata Review queue (not a public source).
  const fsProfile = { approvalStatus: 'pending', isApproved: false, isPublished: false };

  const withProfile = (arr, p) => arr.map((x) => ({ ...x, ...p }));

  const meta = (note) => ({
    generatedAt: new Date().toISOString(),
    source: 'enriched.json + r2_manifest.json',
    audioHost: manifest.publicUrl,
    note,
    songCount: songs.length,
    albumCount: albums.length,
    artistCount: artists.length,
  });

  const appCatalog = {
    _meta: meta('Imported Pahadi catalog. Audio/artwork on Cloudflare R2 (no '
      + `bundled MP3s). Visible in-app (LICENSED) and flagged "${REVIEW_TAG}".`),
    artists: withProfile(artists, appProfile),
    albums: withProfile(albums, appProfile),
    songs: withProfile(songs, appProfile),
  };

  const fsImport = {
    _meta: meta('Firestore seed — imported content defaults to PENDING REVIEW.'),
    artists: withProfile(artists, fsProfile),
    albums: withProfile(albums, fsProfile),
    songs: withProfile(songs, fsProfile),
  };

  fs.mkdirSync(ASSET_CATALOG_DIR, { recursive: true });
  const appJson = JSON.stringify(appCatalog, null, 2);
  fs.writeFileSync(ASSET_CATALOG, appJson);
  fs.writeFileSync(OUT_SEED, appJson);
  fs.writeFileSync(OUT_FS, JSON.stringify(fsImport, null, 2));

  console.log(`✅ ${songs.length} songs · ${albums.length} albums · ${artists.length} artists`);
  console.log(`✅ App catalog  → ${path.relative(ROOT, ASSET_CATALOG)} (R2 URLs, visible)`);
  console.log(`✅ Firestore in → ${path.relative(ROOT, OUT_FS)} (pending review)`);
  console.log(`   Audio host: ${manifest.publicUrl}`);
  console.log('   Seed Firestore:  GOOGLE_APPLICATION_CREDENTIALS=<sa.json> \\');
  console.log('     node scripts/import.js --json scripts/seed_data/firestore_import.json --commit');
}

main();
