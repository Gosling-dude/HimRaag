import { test } from 'node:test';
import assert from 'node:assert/strict';

import { bearerToken, callMeBotUrl, formatMessage, parseRequest } from '../src/lib.js';

test('bearerToken reads the Authorization header', () => {
  assert.equal(bearerToken(new Headers({ Authorization: 'Bearer abc.def' })), 'abc.def');
  assert.equal(bearerToken(new Headers()), null);
});

test('parseRequest trims fields and requires a title', () => {
  assert.deepEqual(parseRequest({ songTitle: '  Bedu Pako ', link: 'https://youtu.be/x' }).value, {
    songTitle: 'Bedu Pako', artist: '', link: 'https://youtu.be/x', details: '', searchQuery: '',
  });
  assert.equal(parseRequest({ songTitle: '   ' }).error, 'songTitle is required');
  assert.equal(parseRequest(null).error, 'Expected a JSON object');
});

test('parseRequest enforces the same limits as the Firestore rules', () => {
  assert.equal(parseRequest({ songTitle: 'x'.repeat(151) }).error, 'songTitle is too long');
  assert.equal(parseRequest({ songTitle: 'ok', details: 5 }).error, 'details must be a string');
});

test('formatMessage includes only the fields that were filled in', () => {
  const text = formatMessage(
    { songTitle: 'Bedu Pako', artist: '', link: 'https://youtu.be/x', details: '', searchQuery: 'bedu' },
    { uid: 'u1', name: 'Asha', email: 'asha@example.com' },
  );
  assert.match(text, /Song: Bedu Pako/);
  assert.match(text, /Link: https:\/\/youtu.be\/x/);
  assert.match(text, /Searched for: "bedu"/);
  assert.match(text, /From: Asha · asha@example.com/);
  assert.doesNotMatch(text, /Singer:|Details:/);
});

test('callMeBotUrl encodes the message', () => {
  const url = new URL(callMeBotUrl('919800000000', 'k3y', 'Song: a & b'));
  assert.equal(url.searchParams.get('text'), 'Song: a & b');
  assert.equal(url.searchParams.get('phone'), '919800000000');
});
