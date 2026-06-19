/**
 * Additive catalog merge — combine the preserved ORIGINAL bundled catalog (the
 * 19 already-live songs, with curated artwork) with the NEW import batch, then
 * recompute all derived counts. Strictly additive: existing song/album/artist
 * records win on field conflicts (their curated art/bio is never overwritten);
 * new records are appended; shared collective records (Pahadi Folk / Pahadi Folk
 * Collection) keep the curated fields but get recomputed counts.
 *
 * Usage:
 *   node scripts/merge_catalog.js <original.json> <new.json> <out.json>
 */
'use strict';
const fs = require('fs');

function load(p) { return JSON.parse(fs.readFileSync(p, 'utf8')); }

function mergeArrays(orig, neu, idKey, preferOriginal = true) {
  const byId = new Map();
  // Original first so it wins on field conflicts when preferOriginal.
  for (const r of orig) byId.set(r[idKey], { ...r });
  for (const r of neu) {
    if (byId.has(r[idKey])) {
      if (!preferOriginal) byId.set(r[idKey], { ...byId.get(r[idKey]), ...r });
      // else keep original record as-is (curated art/bio/desc preserved)
    } else {
      byId.set(r[idKey], { ...r });
    }
  }
  return byId;
}

function main() {
  const [origPath, newPath, outPath] = process.argv.slice(2);
  if (!origPath || !newPath || !outPath) {
    console.error('usage: merge_catalog.js <original> <new> <out>');
    process.exit(1);
  }
  const o = load(origPath);
  const n = load(newPath);

  // Songs: union by id (distinct songs across both batches).
  const songs = mergeArrays(o.songs || [], n.songs || [], 'id', true);
  const artists = mergeArrays(o.artists || [], n.artists || [], 'id', true);
  const albums = mergeArrays(o.albums || [], n.albums || [], 'id', true);

  const songList = [...songs.values()];

  // Recompute album counts/durations from actual songs.
  for (const al of albums.values()) {
    const mine = songList.filter((s) => s.albumId === al.id);
    al.songCount = mine.length;
    al.totalDurationMs = mine.reduce((a, s) => a + (s.durationMs || 0), 0);
  }
  // Recompute artist counts from actual songs/albums.
  for (const ar of artists.values()) {
    const mine = songList.filter((s) => s.artistId === ar.id);
    ar.songCount = mine.length;
    ar.albumCount = new Set(mine.map((s) => s.albumId)).size;
    // Union genres seen across this artist's songs (keep curated order first).
    const g = new Set(ar.genres || []);
    for (const s of mine) if (s.genre) g.add(s.genre);
    ar.genres = [...g];
  }

  const out = {
    _meta: {
      ...(o._meta || {}),
      generatedAt: o._meta?.generatedAt,
      mergedAt: new Date().toISOString(),
      source: 'merge_catalog.js (original 19 + new import batch)',
      note: 'Pahadi catalog. Audio/artwork on Cloudflare R2 (no bundled MP3s).',
      songCount: songList.length,
      albumCount: albums.size,
      artistCount: artists.size,
    },
    artists: [...artists.values()],
    albums: [...albums.values()],
    songs: songList,
  };

  fs.writeFileSync(outPath, JSON.stringify(out, null, 2));
  console.log(`Merged catalog → ${outPath}`);
  console.log(`  songs=${out.songs.length} albums=${out.albums.length} artists=${out.artists.length}`);
}
main();
