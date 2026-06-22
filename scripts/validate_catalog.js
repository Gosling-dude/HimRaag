/**
 * HimRaag catalog health check.
 *
 * Scans the live Firestore catalog and reports data-quality problems:
 *   - missing artwork / missing lyrics
 *   - broken audio/artwork URLs (reachability)
 *   - duplicate songs (same title+artist)
 *   - songs referencing a missing artist or album
 *   - tracks with rights issues (uncleared license but published)
 *
 * This is the same report the admin dashboard surfaces (data-quality view).
 *
 * Usage:
 *   GOOGLE_APPLICATION_CREDENTIALS=/path/sa.json node scripts/validate_catalog.js [--no-network]
 */

'use strict';

const fs = require('fs');
const { checkUrlReachable, slugify } = require('./lib/validator');
const { PROJECT_ID, COLLECTIONS, LICENSES } = require('./lib/constants');

async function main() {
  const network = !process.argv.includes('--no-network');
  const saPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!saPath) {
    console.error('ERROR: set GOOGLE_APPLICATION_CREDENTIALS to your service-account JSON.');
    process.exit(1);
  }

  const { initializeApp, cert } = require('firebase-admin/app');
  const { getFirestore } = require('firebase-admin/firestore');
  initializeApp({ credential: cert(JSON.parse(fs.readFileSync(saPath, 'utf8'))), projectId: PROJECT_ID });
  const db = getFirestore();

  console.log('\n🔎 Scanning HimRaag catalog...\n');

  const [songsSnap, albumsSnap, artistsSnap] = await Promise.all([
    db.collection(COLLECTIONS.songs).get(),
    db.collection(COLLECTIONS.albums).get(),
    db.collection(COLLECTIONS.artists).get(),
  ]);

  const albumIds = new Set(albumsSnap.docs.map((d) => d.id));
  const artistIds = new Set(artistsSnap.docs.map((d) => d.id));
  const songs = songsSnap.docs.map((d) => ({ id: d.id, ...d.data() }));

  const report = {
    missingArtwork: [],
    missingLyrics: [],
    brokenAudio: [],
    brokenArtwork: [],
    duplicates: [],
    orphanArtist: [],
    orphanAlbum: [],
    rightsIssues: [],
    zeroDuration: [],
  };

  const byKey = new Map();
  for (const s of songs) {
    if (!s.artworkUrl) report.missingArtwork.push(s.id);
    if (!s.lyrics) report.missingLyrics.push(s.id);
    if (!s.durationMs || s.durationMs <= 0) report.zeroDuration.push(s.id);
    if (s.artistId && !artistIds.has(s.artistId)) report.orphanArtist.push(s.id);
    if (s.albumId && !albumIds.has(s.albumId)) report.orphanAlbum.push(s.id);

    const lic = LICENSES[s.license];
    if (s.isPublished && (!lic || !lic.cleared)) report.rightsIssues.push(s.id);

    const key = `${slugify(s.artistName)}|${slugify(s.title)}`;
    if (byKey.has(key)) report.duplicates.push(`${s.id} ↔ ${byKey.get(key)}`);
    else byKey.set(key, s.id);
  }

  if (network) {
    console.log('🔗 Checking links (use --no-network to skip)...');
    const checked = new Map();
    for (const s of songs) {
      if (s.audioUrl && !checked.has(s.audioUrl)) {
        checked.set(s.audioUrl, (await checkUrlReachable(s.audioUrl, 'audio')).ok);
      }
      if (s.audioUrl && checked.get(s.audioUrl) === false) report.brokenAudio.push(s.id);
      if (s.artworkUrl && !checked.has(s.artworkUrl)) {
        checked.set(s.artworkUrl, (await checkUrlReachable(s.artworkUrl, 'image')).ok);
      }
      if (s.artworkUrl && checked.get(s.artworkUrl) === false) report.brokenArtwork.push(s.id);
    }
  }

  const line = (label, arr) =>
    console.log(`  ${arr.length === 0 ? '✓' : '⚠️ '} ${label}: ${arr.length}` +
      (arr.length && arr.length <= 10 ? ` — ${arr.join(', ')}` : ''));

  console.log(`\nCatalog: ${songs.length} songs, ${albumsSnap.size} albums, ${artistsSnap.size} artists\n`);
  line('missing artwork', report.missingArtwork);
  line('missing lyrics', report.missingLyrics);
  line('zero duration', report.zeroDuration);
  line('broken audio URLs', report.brokenAudio);
  line('broken artwork URLs', report.brokenArtwork);
  line('duplicate songs', report.duplicates);
  line('orphan artist refs', report.orphanArtist);
  line('orphan album refs', report.orphanAlbum);
  line('rights issues (published but uncleared)', report.rightsIssues);

  const problems =
    report.brokenAudio.length +
    report.brokenArtwork.length +
    report.duplicates.length +
    report.orphanArtist.length +
    report.orphanAlbum.length +
    report.rightsIssues.length +
    report.zeroDuration.length;
  console.log(`\n${problems === 0 ? '✅ No blocking issues.' : `⚠️  ${problems} blocking issue(s) found.`}`);
  process.exit(problems === 0 ? 0 : 2);
}

main().catch((err) => {
  console.error('Scan failed:', err);
  process.exit(1);
});
