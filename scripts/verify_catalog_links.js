// One-off: verify link health + coverage of the generated demo catalog.
// Reads scripts/seed_data/catalog.json (no Firestore needed) and checks every
// unique audio/artwork URL for reachability. Emits a JSON summary on stdout.
'use strict';
const fs = require('fs');
const path = require('path');
const { checkUrlReachable } = require('./lib/validator');

(async () => {
  const cat = JSON.parse(fs.readFileSync(path.join(__dirname, 'seed_data', 'catalog.json'), 'utf8'));
  const audio = new Map(), art = new Map();
  for (const s of cat.songs) { audio.set(s.audioUrl, true); art.set(s.artworkUrl, true); }

  const brokenAudio = [], brokenArt = [];
  for (const u of audio.keys()) {
    const r = await checkUrlReachable(u, 'audio');
    if (!r.ok) brokenAudio.push({ url: u, reason: r.reason });
  }
  for (const u of art.keys()) {
    const r = await checkUrlReachable(u, 'image');
    if (!r.ok) brokenArt.push({ url: u, reason: r.reason });
  }

  // Per-region song counts.
  const byRegion = {};
  for (const s of cat.songs) byRegion[s.region] = (byRegion[s.region] || 0) + 1;

  const zeroDur = cat.songs.filter(s => !s.durationMs || s.durationMs <= 0).map(s => s.id);
  const noArtwork = cat.songs.filter(s => !s.artworkUrl).map(s => s.id);
  const withLyrics = cat.songs.filter(s => s.lyrics && s.lyrics.trim()).length;

  const out = {
    songs: cat.songs.length,
    albums: cat.albums.length,
    artists: cat.artists.length,
    uniqueAudioUrls: audio.size,
    uniqueArtworkUrls: art.size,
    byRegion,
    withLyrics,
    zeroDuration: zeroDur,
    missingArtwork: noArtwork,
    brokenAudio,
    brokenArtwork: brokenArt,
  };
  console.log(JSON.stringify(out, null, 2));
})().catch(e => { console.error(e); process.exit(1); });
