/**
 * HimRaag — local-audio → catalog generator.
 *
 * Turns the output of `scan_audio.js` (scripts/seed_data/scan_result.json) into
 * an import-ready catalog and bundles the audio for the Flutter app:
 *
 *   1. Copies every scanned audio file into  assets/audio/<slug>.<ext>
 *      (sanitized ASCII names so they are valid Flutter asset keys).
 *   2. Emits  scripts/seed_data/imported_catalog.json  with songs + derived
 *      artists/albums, ready for:
 *        node scripts/import.js --json scripts/seed_data/imported_catalog.json --no-network
 *      …or pasting the `songs` array into the Admin Dashboard → Import.
 *
 * Placeholder policy (files have NO usable embedded tags):
 *   - title            = cleaned filename (underscores → spaces, "(256k)" removed)
 *   - artistName       = "Unknown Artist"
 *   - albumTitle       = "Imported Recordings"
 *   - region/language  = "Needs Review"  (sentinel — assign in dashboard)
 *   - genre            = "Folk"          (safe default; review-flagged)
 *   - audioUrl         = asset:///assets/audio/<slug>.<ext>
 *   - artworkUrl       = deterministic picsum placeholder
 *   - durationMs       = real decoded duration from the scan (never 0)
 *   - license          = LICENSED, rightsCleared = true
 *   - approvalStatus   = approved, isApproved/isPublished = true  → visible
 *   - tags             = ['imported', 'needs-metadata-review']    → review queue
 *
 * Deterministic: re-running yields identical ids/asset names (safe to re-run).
 *
 * Usage:  node scripts/generate_import_catalog.js
 */

'use strict';

const fs = require('fs');
const path = require('path');
const { slugify, songId, artistId, albumId } = require('./lib/validator');
const { NEEDS_REVIEW } = require('./lib/constants');

const ROOT = path.resolve(__dirname, '..');
const SCAN = path.join(__dirname, 'seed_data', 'scan_result.json');
const ASSET_DIR = path.join(ROOT, 'assets', 'audio');
const ASSET_KEY_PREFIX = 'assets/audio';
const OUT = path.join(__dirname, 'seed_data', 'imported_catalog.json');
// Bundled-asset copy the Flutter app loads at runtime (LocalCatalogDatasource),
// so imported songs reach Home/Search/Album/Artist without a Firestore write.
const ASSET_CATALOG_DIR = path.join(ROOT, 'assets', 'catalog');
const ASSET_CATALOG = path.join(ASSET_CATALOG_DIR, 'imported_catalog.json');

const PLACEHOLDER_ARTIST = 'Unknown Artist';
const PLACEHOLDER_ALBUM = 'Imported Recordings';
const DEFAULT_GENRE = 'Folk';
const REVIEW_TAG = 'needs-metadata-review';
const LICENSE = 'LICENSED';
const YEAR = new Date().getFullYear();

const ATTRIBUTION =
  'Locally-imported recording supplied by the app owner. Embedded metadata was ' +
  'absent; title derived from filename. Region, language, artist and album are ' +
  'placeholders pending metadata review in the Admin Dashboard.';

/** Human-readable title from a filename (no extension). */
function cleanTitle(filename) {
  let t = filename.replace(/\.[^.]+$/, ''); // strip extension
  t = t.replace(/\(?\d{2,3}k\)?/gi, ''); // strip "(256k)" / "256k"
  t = t.replace(/[_]+/g, ' '); // underscores → spaces
  t = t.replace(/\s{2,}/g, ' ').trim(); // collapse whitespace
  // Keep it readable but bounded.
  if (t.length > 90) t = t.slice(0, 90).trim();
  return t || filename;
}

/** Sanitized, unique, ASCII asset filename for a record. */
function assetNameFor(record, used) {
  const base = slugify(record.filename.replace(/\.[^.]+$/, '')) || 'track';
  let name = `${base}${record.ext}`;
  let i = 2;
  while (used.has(name)) {
    name = `${base}-${i++}${record.ext}`;
  }
  used.add(name);
  return name;
}

function artImg(seed) {
  return `https://picsum.photos/seed/${seed}/600/600`;
}

function main() {
  if (!fs.existsSync(SCAN)) {
    console.error(`Missing ${SCAN}. Run: node scripts/scan_audio.js "<music folder>"`);
    process.exit(1);
  }
  const scan = JSON.parse(fs.readFileSync(SCAN, 'utf8'));
  const records = scan.records || [];
  if (!records.length) {
    console.error('No scanned records found.');
    process.exit(1);
  }

  fs.mkdirSync(ASSET_DIR, { recursive: true });

  const usedNames = new Set();
  const songs = [];
  let copied = 0;

  for (const r of records) {
    if (r.parseError) {
      console.warn(`  ⚠️  skipping unparseable file: ${r.filename} (${r.parseError})`);
      continue;
    }
    const durationMs = Math.round((r.durationSec || 0) * 1000);
    if (durationMs <= 0) {
      console.warn(`  ⚠️  skipping zero-duration file: ${r.filename}`);
      continue;
    }

    const assetName = assetNameFor(r, usedNames);
    const dest = path.join(ASSET_DIR, assetName);
    fs.copyFileSync(r.fullPath, dest);
    copied++;

    const title = cleanTitle(r.filename);
    const artworkUrl = artImg(`himraag_${slugify(title)}`);
    const id = songId(PLACEHOLDER_ARTIST, title);

    songs.push({
      id,
      title,
      slug: slugify(title),
      artistId: artistId(PLACEHOLDER_ARTIST),
      artistName: PLACEHOLDER_ARTIST,
      albumId: albumId(PLACEHOLDER_ARTIST, PLACEHOLDER_ALBUM),
      albumTitle: PLACEHOLDER_ALBUM,
      audioUrl: `asset:///${ASSET_KEY_PREFIX}/${assetName}`,
      artworkUrl,
      durationMs,
      region: NEEDS_REVIEW,
      language: NEEDS_REVIEW,
      genre: DEFAULT_GENRE,
      releaseYear: Number.isFinite(r.year) ? r.year : YEAR,
      playCount: 0,
      tags: ['imported', REVIEW_TAG],
      license: LICENSE,
      attribution: ATTRIBUTION,
      approvalStatus: 'approved',
      isPublished: true,
      rightsCleared: true,
      isDownloadable: true,
      // Provenance — kept for traceability / future re-imports.
      sourceFile: r.fullPath,
      assetPath: `${ASSET_KEY_PREFIX}/${assetName}`,
    });
  }

  // ── Derived placeholder artist + album (single bucket for all imports) ──────
  const artists = [
    {
      id: artistId(PLACEHOLDER_ARTIST),
      name: PLACEHOLDER_ARTIST,
      imageUrl: artImg('himraag_unknown_artist'),
      region: NEEDS_REVIEW,
      bio: 'Placeholder profile for locally-imported recordings whose artist is '
        + 'not yet identified. Reassign tracks to real artists in the dashboard.',
      songCount: songs.length,
      albumCount: 1,
      genres: [DEFAULT_GENRE],
      monthlyListeners: 0,
      isVerified: false,
      socialLinks: {},
      slug: slugify(PLACEHOLDER_ARTIST),
      approvalStatus: 'approved',
      isPublished: true,
      rightsNote: 'Imported placeholder — reassign before public release.',
    },
  ];

  const totalDurationMs = songs.reduce((s, x) => s + x.durationMs, 0);
  const albums = [
    {
      id: albumId(PLACEHOLDER_ARTIST, PLACEHOLDER_ALBUM),
      title: PLACEHOLDER_ALBUM,
      artistId: artistId(PLACEHOLDER_ARTIST),
      artistName: PLACEHOLDER_ARTIST,
      artworkUrl: artImg('himraag_imported_recordings'),
      region: NEEDS_REVIEW,
      language: NEEDS_REVIEW,
      genre: DEFAULT_GENRE,
      releaseYear: YEAR,
      songCount: songs.length,
      totalDurationMs,
      description: 'Auto-created bucket for locally-imported audio pending '
        + 'metadata review. Move tracks to real albums in the dashboard.',
      tags: ['imported', REVIEW_TAG],
      slug: slugify(PLACEHOLDER_ALBUM),
      license: LICENSE,
      attribution: ATTRIBUTION,
      approvalStatus: 'approved',
      isPublished: true,
      rightsCleared: true,
    },
  ];

  const catalog = {
    _meta: {
      generatedAt: new Date().toISOString(),
      source: scan.folder,
      note: 'Locally-imported audio. Bundled as Flutter assets under '
        + 'assets/audio/. Visible in-app (approved) and flagged '
        + `"${REVIEW_TAG}" for metadata review.`,
      songCount: songs.length,
      albumCount: albums.length,
      artistCount: artists.length,
    },
    artists,
    albums,
    songs,
  };

  const json = JSON.stringify(catalog, null, 2);
  fs.writeFileSync(OUT, json);
  fs.mkdirSync(ASSET_CATALOG_DIR, { recursive: true });
  fs.writeFileSync(ASSET_CATALOG, json);

  console.log(`✅ Copied ${copied} audio file(s) → ${path.relative(ROOT, ASSET_DIR)}/`);
  console.log(`✅ Wrote ${path.relative(ROOT, OUT)}`);
  console.log(`✅ Wrote ${path.relative(ROOT, ASSET_CATALOG)} (bundled for the app)`);
  console.log(`   ${songs.length} songs · ${albums.length} album · ${artists.length} artist`);
  console.log('   Validate:  node scripts/import.js --json scripts/seed_data/imported_catalog.json --no-network');
}

main();
