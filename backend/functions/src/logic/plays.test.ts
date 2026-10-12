import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  applyDailyQuota,
  istDayKey,
  MAX_PLAYS_PER_SONG_PER_CALL,
  MAX_SONGS_PER_CALL,
  mergeCounts,
  PlayPayloadError,
  rankTrending,
  recentDayKeys,
  validatePlays,
} from './plays';

test('validatePlays accepts a well-formed map', () => {
  assert.deepEqual(validatePlays({ 'bedu-pako': 2, raniban_1: 1 }), {
    'bedu-pako': 2,
    raniban_1: 1,
  });
});

test('validatePlays clamps oversized counts', () => {
  assert.deepEqual(validatePlays({ a: 999 }), {
    a: MAX_PLAYS_PER_SONG_PER_CALL,
  });
});

test('validatePlays rejects bad shapes and ids', () => {
  for (const bad of [
    null,
    undefined,
    [],
    'x',
    {},
    { 'has space': 1 },
    { 'a.b': 1 },
    { 'a/b': 1 },
    { a: 0 },
    { a: -1 },
    { a: 1.5 },
    { a: '3' },
  ]) {
    assert.throws(() => validatePlays(bad), PlayPayloadError, String(bad));
  }
});

test('validatePlays rejects too many songs', () => {
  const many: Record<string, number> = {};
  for (let i = 0; i <= MAX_SONGS_PER_CALL; i++) many[`s${i}`] = 1;
  assert.throws(() => validatePlays(many), PlayPayloadError);
});

test('applyDailyQuota admits everything under the cap', () => {
  const r = applyDailyQuota({ a: 3, b: 2 }, 10, 100);
  assert.deepEqual(r, { accepted: { a: 3, b: 2 }, acceptedTotal: 5, dropped: 0 });
});

test('applyDailyQuota trims at the cap', () => {
  const r = applyDailyQuota({ a: 3, b: 4 }, 95, 100);
  assert.deepEqual(r, { accepted: { a: 3, b: 2 }, acceptedTotal: 5, dropped: 2 });
});

test('applyDailyQuota drops everything once the cap is used', () => {
  const r = applyDailyQuota({ a: 3 }, 100, 100);
  assert.deepEqual(r, { accepted: {}, acceptedTotal: 0, dropped: 3 });
});

test('mergeCounts sums overlapping songs', () => {
  assert.deepEqual(mergeCounts({ a: 1, b: 2 }, { b: 3, c: 4 }), {
    a: 1,
    b: 5,
    c: 4,
  });
});

test('istDayKey rolls over at IST midnight, not UTC', () => {
  // 18:29 UTC = 23:59 IST same day; 18:30 UTC = 00:00 IST next day.
  assert.equal(istDayKey(new Date('2026-10-13T18:29:00Z')), '2026-10-13');
  assert.equal(istDayKey(new Date('2026-10-13T18:30:00Z')), '2026-10-14');
});

test('recentDayKeys lists newest first', () => {
  assert.deepEqual(recentDayKeys(new Date('2026-10-13T06:00:00Z'), 3), [
    '2026-10-13',
    '2026-10-12',
    '2026-10-11',
  ]);
});

test('rankTrending favours recent plays', () => {
  // `old` had more plays, but 3 days ago; `fresh` wins on recency.
  const ranked = rankTrending([{ fresh: 10 }, {}, {}, { old: 25 }], 0.7);
  assert.deepEqual(ranked, ['fresh', 'old']);
});

test('rankTrending sums across days', () => {
  const ranked = rankTrending([{ a: 5, b: 6 }, { a: 5 }]);
  assert.deepEqual(ranked, ['a', 'b']);
});
