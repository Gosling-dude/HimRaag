import { test } from 'node:test';
import assert from 'node:assert/strict';

import { mediaKeyFromUrl, parseHostList } from './media';

const hosts = ['cdn.himraag.in', 'pub-abc.r2.dev'];

test('mediaKeyFromUrl maps media hosts to object keys', () => {
  assert.equal(
    mediaKeyFromUrl('https://pub-abc.r2.dev/audio/main-pahadan-1.mp3', hosts),
    'audio/main-pahadan-1.mp3',
  );
  assert.equal(
    mediaKeyFromUrl('https://cdn.himraag.in/artwork/x%20y.png?t=abc', hosts),
    'artwork/x y.png',
  );
});

test('mediaKeyFromUrl ignores foreign hosts, odd paths and junk', () => {
  for (const url of [
    'https://picsum.photos/artwork/a.png',
    'https://cdn.himraag.in/',
    'https://cdn.himraag.in/secrets/a',
    'https://cdn.himraag.in/audio/',
    'https://cdn.himraag.in/audio/../x',
    'not a url',
    '',
    undefined,
    42,
  ]) {
    assert.equal(mediaKeyFromUrl(url, hosts), null, String(url));
  }
});

test('parseHostList normalises entries', () => {
  assert.deepEqual(parseHostList(' https://cdn.himraag.in/ , pub-abc.r2.dev,, '), [
    'cdn.himraag.in',
    'pub-abc.r2.dev',
  ]);
});
