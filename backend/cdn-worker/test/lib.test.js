import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  cacheControlFor,
  contentRangeHeader,
  extractToken,
  isProtectedKey,
  objectKeyFromPath,
  parsePrefixes,
} from '../src/lib.js';

test('objectKeyFromPath decodes keys and rejects traversal/dirs', () => {
  assert.equal(objectKeyFromPath('/audio/main-pahadan.mp3'), 'audio/main-pahadan.mp3');
  assert.equal(objectKeyFromPath('/artwork/a%20b.png'), 'artwork/a b.png');
  for (const bad of ['/', '', '/audio/', '/audio/../secret', '/a\\b', '/%E0%A4%A']) {
    assert.equal(objectKeyFromPath(bad), null, bad);
  }
});

test('audio is protected, artwork is not', () => {
  const prefixes = parsePrefixes(' audio/ ,');
  assert.deepEqual(prefixes, ['audio/']);
  assert.equal(isProtectedKey('audio/x.mp3', prefixes), true);
  assert.equal(isProtectedKey('artwork/x.png', prefixes), false);
});

test('extractToken prefers the Authorization header', () => {
  const h = new Headers({ Authorization: 'Bearer abc.def' });
  assert.equal(extractToken(h, new URLSearchParams('t=zzz')), 'abc.def');
  assert.equal(extractToken(new Headers(), new URLSearchParams('t=zzz')), 'zzz');
  assert.equal(extractToken(new Headers(), new URLSearchParams()), null);
  assert.equal(extractToken(new Headers({ Authorization: 'Basic x' }), new URLSearchParams()), null);
});

test('contentRangeHeader handles offset, open-ended and suffix ranges', () => {
  assert.equal(contentRangeHeader({ offset: 0, length: 100 }, 1000), 'bytes 0-99/1000');
  assert.equal(contentRangeHeader({ offset: 900 }, 1000), 'bytes 900-999/1000');
  assert.equal(contentRangeHeader({ offset: 900, length: 500 }, 1000), 'bytes 900-999/1000');
  assert.equal(contentRangeHeader({ suffix: 200 }, 1000), 'bytes 800-999/1000');
  assert.equal(contentRangeHeader({ suffix: 5000 }, 1000), 'bytes 0-999/1000');
  assert.equal(contentRangeHeader(undefined, 1000), null);
});

test('audio is never shared-cached', () => {
  assert.match(cacheControlFor(true), /^private/);
  assert.match(cacheControlFor(false), /^public/);
});
