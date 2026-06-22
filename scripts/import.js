/**
 * HimRaag bulk import pipeline.
 *
 * Validates, normalizes, de-duplicates, and (optionally) commits catalog
 * content to Firestore. Dogfooded by the seed script.
 *
 * Usage:
 *   node scripts/import.js --json  <file.json>   [--commit] [--no-network]
 *   node scripts/import.js --csv   <file.csv>    [--commit] [--no-network]
 *   node scripts/import.js --folder <dir>        [--commit] [--no-network]
 *
 * Input shapes:
 *   --json   : { artists: [...], albums: [...], songs: [...] }  OR  a bare
 *              array of song records (artists/albums are then derived).
 *   --csv    : one song per row; headers match song fields. Artists/albums
 *              are derived from the rows.
 *   --folder : a directory of <track>/meta.json sidecar files (one song each).
 *              Audio tags are NOT read (keeps deps light) — metadata lives in
 *              meta.json. Documented in docs/CONTENT_SYSTEM.md.
 *
 * Flags:
 *   --commit     : write to Firestore (requires GOOGLE_APPLICATION_CREDENTIALS).
 *                  Without it, runs a dry-run validation report only.
 *   --no-network : skip URL reachability checks (offline validation).
 *
 * Exit code is non-zero if any record fails validation.
 */

'use strict';

const fs = require('fs');
const path = require('path');
const {
  validateTrack,
  checkLinks,
  findDuplicates,
  slugify,
  artistId: makeArtistId,
  albumId: makeAlbumId,
} = require('./lib/validator');
const { PROJECT_ID, COLLECTIONS } = require('./lib/constants');

// ─── Args ────────────────────────────────────────────────────────────────────

function parseArgs(argv) {
  const args = { commit: false, network: true, mode: null, input: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--commit') args.commit = true;
    else if (a === '--no-network') args.network = false;
    else if (a === '--json') { args.mode = 'json'; args.input = argv[++i]; }
    else if (a === '--csv') { args.mode = 'csv'; args.input = argv[++i]; }
    else if (a === '--folder') { args.mode = 'folder'; args.input = argv[++i]; }
  }
  return args;
}

// ─── Minimal CSV parser (no deps) ──────────────────────────────────────────────

function parseCsv(text) {
  const rows = [];
  let row = [];
  let field = '';
  let inQuotes = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQuotes) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') inQuotes = false;
      else field += c;
    } else if (c === '"') inQuotes = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\r') { /* ignore */ }
    else if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else field += c;
  }
  if (field.length > 0 || row.length > 0) { row.push(field); rows.push(row); }
  if (rows.length === 0) return [];
  const headers = rows[0].map((h) => h.trim());
  return rows.slice(1)
    .filter((r) => r.some((c) => c.trim() !== ''))
    .map((r) => {
      const obj = {};
      headers.forEach((h, idx) => { obj[h] = (r[idx] ?? '').trim(); });
      return obj;
    });
}

// ─── Load raw song records by mode ─────────────────────────────────────────────

function loadInput(args) {
  if (!args.input || !fs.existsSync(args.input)) {
    throw new Error(`input not found: ${args.input}`);
  }
  if (args.mode === 'json') {
    const data = JSON.parse(fs.readFileSync(args.input, 'utf8'));
    if (Array.isArray(data)) return { songs: data, artists: [], albums: [] };
    return {
      songs: data.songs || [],
      artists: data.artists || [],
      albums: data.albums || [],
    };
  }
  if (args.mode === 'csv') {
    return { songs: parseCsv(fs.readFileSync(args.input, 'utf8')), artists: [], albums: [] };
  }
  if (args.mode === 'folder') {
    const dir = args.input;
    const songs = [];
    for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
      const metaPath = entry.isDirectory()
        ? path.join(dir, entry.name, 'meta.json')
        : entry.name === 'meta.json'
        ? path.join(dir, entry.name)
        : null;
      if (metaPath && fs.existsSync(metaPath)) {
        songs.push(JSON.parse(fs.readFileSync(metaPath, 'utf8')));
      }
    }
    return { songs, artists: [], albums: [] };
  }
  throw new Error('specify one of --json | --csv | --folder');
}

// ─── Derive artists/albums from validated songs when not supplied ──────────────

function deriveEntities(songs, providedArtists, providedAlbums) {
  const artists = new Map(providedArtists.map((a) => [a.id || makeArtistId(a.name), a]));
  const albums = new Map(providedAlbums.map((a) => [a.id, a]));

  for (const s of songs) {
    if (!artists.has(s.artistId)) {
      artists.set(s.artistId, {
        id: s.artistId,
        name: s.artistName,
        imageUrl: s.artworkUrl,
        region: s.region,
        bio: `${s.artistName} — ${s.region} artist.`,
        songCount: 0,
        albumCount: 0,
        genres: [s.genre],
        monthlyListeners: 0,
        isVerified: false,
        socialLinks: {},
        slug: slugify(s.artistName),
        approvalStatus: s.approvalStatus,
        isPublished: s.isPublished,
        rightsNote: s.attribution || '',
      });
    }
    const a = artists.get(s.artistId);
    a.songCount = (a.songCount || 0) + 1;
    if (s.genre && !a.genres.includes(s.genre)) a.genres.push(s.genre);

    if (s.albumId && !albums.has(s.albumId)) {
      albums.set(s.albumId, {
        id: s.albumId,
        title: s.albumTitle,
        artistId: s.artistId,
        artistName: s.artistName,
        artworkUrl: s.artworkUrl,
        region: s.region,
        language: s.language,
        genre: s.genre,
        releaseYear: s.releaseYear || new Date().getFullYear(),
        songCount: 0,
        totalDurationMs: 0,
        description: `${s.albumTitle} by ${s.artistName}.`,
        tags: s.tags || [],
        slug: slugify(s.albumTitle),
        license: s.license,
        attribution: s.attribution || '',
        approvalStatus: s.approvalStatus,
        isPublished: s.isPublished,
        rightsCleared: !!s.rightsCleared,
      });
    }
    if (s.albumId) {
      const al = albums.get(s.albumId);
      al.songCount = (al.songCount || 0) + 1;
      al.totalDurationMs = (al.totalDurationMs || 0) + (s.durationMs || 0);
    }
  }

  // Recompute album counts per artist.
  for (const al of albums.values()) {
    const a = artists.get(al.artistId);
    if (a) a.albumCount = (a.albumCount || 0) + 1;
  }
  return { artists: [...artists.values()], albums: [...albums.values()] };
}

// ─── Firestore write helpers ───────────────────────────────────────────────────

/** Lowercase, strip diacritics + punctuation → a normalized comparable string. */
function normalize(value) {
  return String(value || '')
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '') // combining marks
    .toLowerCase()
    .replace(/[^a-z0-9ऀ-ॿ\s]/g, ' ') // keep latin + devanagari
    .replace(/\s+/g, ' ')
    .trim();
}

/** Build a deduped keyword array for prefix/substring search in Firestore. */
function searchTerms(...parts) {
  const set = new Set();
  for (const p of parts) {
    const norm = normalize(p);
    if (!norm) continue;
    set.add(norm);
    for (const tok of norm.split(' ')) if (tok.length > 1) set.add(tok);
  }
  return [...set];
}

function songToFirestore(s) {
  return {
    title: s.title,
    titleLowercase: s.title.toLowerCase(),
    titleNormalized: normalize(s.title),
    artistId: s.artistId,
    artistName: s.artistName,
    albumId: s.albumId || '',
    albumTitle: s.albumTitle || '',
    audioUrl: s.audioUrl,
    artworkUrl: s.artworkUrl,
    durationMs: s.durationMs,
    region: s.region,
    language: s.language,
    genre: s.genre,
    releaseYear: s.releaseYear || new Date().getFullYear(),
    playCount: s.playCount || 0,
    tags: s.tags || [],
    isApproved: s.approvalStatus === 'approved',
    // Imported content defaults to a pending-review state; the admin dashboard's
    // Metadata Review queue surfaces every doc with reviewRequired=true.
    reviewRequired: s.reviewRequired === true,
    isDownloadable: s.isDownloadable !== false,
    slug: s.slug,
    license: s.license,
    attribution: s.attribution || '',
    approvalStatus: s.approvalStatus,
    isPublished: !!s.isPublished,
    rightsCleared: !!s.rightsCleared,
    searchKeywords: searchTerms(s.title, s.artistName, s.albumTitle, s.region, s.language, s.genre),
    ...(s.lyrics ? { lyrics: s.lyrics } : {}),
    ...(s.mood ? { mood: s.mood } : {}),
    ...(s.licenseUrl ? { licenseUrl: s.licenseUrl } : {}),
    ...(s.sourceUrl ? { sourceUrl: s.sourceUrl } : {}),
    ...(s.submittedBy ? { submittedBy: s.submittedBy } : {}),
    ...(s.sourceFile ? { sourceFile: s.sourceFile } : {}),
  };
}

// ─── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  const args = parseArgs(process.argv.slice(2));
  console.log(`\n📥 HimRaag import — mode=${args.mode} commit=${args.commit} network=${args.network}\n`);

  const { songs: rawSongs, artists: rawArtists, albums: rawAlbums } = loadInput(args);
  console.log(`Loaded ${rawSongs.length} song record(s).`);

  // 1. Validate + normalize each track.
  const valid = [];
  let errorCount = 0;
  let warnCount = 0;
  for (let i = 0; i < rawSongs.length; i++) {
    const { ok, errors, warnings, normalized } = validateTrack(rawSongs[i]);
    const label = rawSongs[i].title || `row ${i + 1}`;
    if (warnings.length) {
      warnCount += warnings.length;
      warnings.forEach((w) => console.log(`  ⚠️  [${label}] ${w}`));
    }
    if (!ok) {
      errorCount += errors.length;
      errors.forEach((e) => console.log(`  ❌ [${label}] ${e}`));
    } else {
      valid.push(normalized);
    }
  }

  // 2. Duplicate detection.
  const dups = findDuplicates(valid);
  for (const d of dups) {
    errorCount++;
    console.log(`  ❌ [${valid[d.index].title}] ${d.reason} (collides with #${d.with + 1})`);
  }

  // 3. Network reachability (optional).
  if (args.network) {
    console.log('\n🔗 Checking audio/artwork links (use --no-network to skip)...');
    const seen = new Set();
    for (const t of valid) {
      // Avoid hammering the same URL repeatedly (demo pool reuses URLs).
      const key = `${t.audioUrl}|${t.artworkUrl}`;
      if (seen.has(key)) continue;
      seen.add(key);
      const issues = await checkLinks(t);
      issues.forEach((iss) => {
        errorCount++;
        console.log(`  ❌ [${t.title}] ${iss}`);
      });
    }
  }

  console.log(
    `\nSummary: ${valid.length - dups.length}/${rawSongs.length} valid, ` +
    `${errorCount} error(s), ${warnCount} warning(s).`
  );

  if (errorCount > 0) {
    console.log('\n⛔ Validation failed — nothing written. Fix errors and re-run.');
    process.exit(1);
  }

  // 4. Commit (optional).
  if (!args.commit) {
    console.log('\n✅ Dry-run OK. Re-run with --commit (and GOOGLE_APPLICATION_CREDENTIALS) to write.');
    return;
  }

  const { initializeApp, cert } = require('firebase-admin/app');
  const { getFirestore, FieldValue } = require('firebase-admin/firestore');
  const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!saPath) {
    console.error('ERROR: set GOOGLE_APPLICATION_CREDENTIALS to your service-account JSON.');
    process.exit(1);
  }
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();

  const { artists, albums } = deriveEntities(valid, rawArtists, rawAlbums);

  async function commitBatch(collection, items, mapFn) {
    let batch = db.batch();
    let n = 0;
    for (const item of items) {
      const { id, ...rest } = mapFn(item);
      const ref = db.collection(collection).doc(id);
      batch.set(ref, { ...rest, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
      if (++n % 400 === 0) { await batch.commit(); batch = db.batch(); }
    }
    await batch.commit();
    console.log(`  ✓ ${collection}: ${items.length} doc(s)`);
  }

  console.log('\n📝 Committing to Firestore...');
  await commitBatch(COLLECTIONS.artists, artists, (a) => {
    const { id, ...rest } = a;
    return {
      id,
      ...rest,
      nameLowercase: (a.name || '').toLowerCase(),
      nameNormalized: normalize(a.name),
      searchKeywords: searchTerms(a.name, a.region, ...(a.genres || [])),
    };
  });
  await commitBatch(COLLECTIONS.albums, albums, (a) => {
    const { id, ...rest } = a;
    return {
      id,
      ...rest,
      titleLowercase: (a.title || '').toLowerCase(),
      titleNormalized: normalize(a.title),
      searchKeywords: searchTerms(a.title, a.artistName, a.region, a.language, a.genre),
    };
  });
  await commitBatch(COLLECTIONS.songs, valid, (s) => ({ id: s.id, ...songToFirestore(s) }));

  // 5. Audit log.
  await db.collection(COLLECTIONS.auditLogs).add({
    action: 'bulk_import',
    source: `${args.mode}:${path.basename(args.input)}`,
    songCount: valid.length,
    albumCount: albums.length,
    artistCount: artists.length,
    actor: 'import-script',
    createdAt: FieldValue.serverTimestamp(),
  });

  console.log(`\n✅ Imported ${valid.length} songs, ${albums.length} albums, ${artists.length} artists.`);
}

main().catch((err) => {
  console.error('Import failed:', err);
  process.exit(1);
});
