import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  approxSizeBytes,
  buildHomeFeed,
  byNumberDesc,
  FEED_SIZE_BUDGET_BYTES,
  FEED_VERSION,
  pickFeaturedArtists,
} from './feed';

const song = (id: string, extra: Record<string, unknown> = {}) => ({
  id,
  data: { title: id, titleLowercase: id, updatedAt: 'x', playCount: 1, ...extra },
});

test('buildHomeFeed dedupes songs across rows and keeps row order', () => {
  const feed = buildHomeFeed({
    featured: [song('a'), song('b')],
    trending: [song('b'), song('c')],
    newReleases: [song('c'), song('a')],
    regions: { Garhwali: [song('a'), song('d')], Kinnauri: [] },
    albums: [],
    artists: [],
  });
  assert.equal(feed.version, FEED_VERSION);
  assert.deepEqual(Object.keys(feed.songs).sort(), ['a', 'b', 'c', 'd']);
  assert.deepEqual(feed.featuredSongIds, ['a', 'b']);
  assert.deepEqual(feed.trendingSongIds, ['b', 'c']);
  assert.deepEqual(feed.newReleaseIds, ['c', 'a']);
  // Empty regions are omitted so Home never renders a blank row.
  assert.deepEqual(feed.regionSongIds, { Garhwali: ['a', 'd'] });
});

test('buildHomeFeed strips search/audit fields', () => {
  const feed = buildHomeFeed({
    featured: [song('a')],
    trending: [],
    newReleases: [],
    regions: {},
    albums: [{ id: 'al', data: { title: 'Album', titleLowercase: 'album' } }],
    artists: [{ id: 'ar', data: { name: 'N', nameLowercase: 'n' } }],
  });
  assert.deepEqual(feed.songs.a, { title: 'a', playCount: 1 });
  assert.deepEqual(feed.albums, [{ id: 'al', title: 'Album' }]);
  assert.deepEqual(feed.artists, [{ id: 'ar', name: 'N' }]);
});

test('buildHomeFeed drops lyrics only when over the size budget', () => {
  const small = buildHomeFeed({
    featured: [song('a', { lyrics: 'short' })],
    trending: [], newReleases: [], regions: {}, albums: [], artists: [],
  });
  assert.equal(small.songs.a.lyrics, 'short');

  const huge = 'x'.repeat(10_000);
  const many = Array.from({ length: 100 }, (_, i) => song(`s${i}`, { lyrics: huge }));
  const big = buildHomeFeed({
    featured: many, trending: [], newReleases: [], regions: {}, albums: [], artists: [],
  });
  assert.equal(big.songs.s0.lyrics, undefined);
  assert.ok(approxSizeBytes(big) < FEED_SIZE_BUDGET_BYTES);
});

test('byNumberDesc sorts and treats missing as 0', () => {
  const rows = [song('a', { releaseYear: 2001 }), song('b'), song('c', { releaseYear: 2024 })];
  assert.deepEqual(rows.sort(byNumberDesc('releaseYear')).map((r) => r.id), ['c', 'a', 'b']);
});

test('pickFeaturedArtists puts artists with a photo first, then by song count', () => {
  const artist = (id: string, imageUrl: string, songCount: number) => ({ id, data: { imageUrl, songCount } });
  const picked = pickFeaturedArtists([
    artist('no-photo-big', '', 30),
    artist('photo-small', 'https://cdn/x.jpg', 2),
    artist('photo-big', 'https://cdn/y.jpg', 9),
    artist('no-photo-small', '  ', 1),
  ], 3);
  assert.deepEqual(picked.map((r) => r.id), ['photo-big', 'photo-small', 'no-photo-big']);
});
