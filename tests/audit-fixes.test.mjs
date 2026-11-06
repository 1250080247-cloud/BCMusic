import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';

test('stored embed URLs must be https SoundCloud widget URLs', async () => {
  const { safeEmbedUrl } = await loadModule('src/lib/url-policy.js');
  assert.equal(safeEmbedUrl('https://w.soundcloud.com/player/?url=example'), 'https://w.soundcloud.com/player/?url=example');
  for (const value of ['javascript:alert(1)', 'http://w.soundcloud.com/player/', 'https://evil.example/player', 'https://u:p@w.soundcloud.com/x', '', undefined, 42]) {
    assert.equal(safeEmbedUrl(value), null, String(value));
  }
});

test('stored source links allow only SoundCloud and YouTube pages and drop unsafe values on write', async () => {
  const { safeSourceUrl, cleanTrackUrls } = await loadModule('src/lib/url-policy.js');
  assert.equal(safeSourceUrl('https://soundcloud.com/artist/track'), 'https://soundcloud.com/artist/track');
  assert.equal(safeSourceUrl('https://youtu.be/abc'), 'https://youtu.be/abc');
  assert.equal(safeSourceUrl('https://evil.example/'), null);
  assert.equal(safeSourceUrl('javascript:alert(1)'), null);
  const cleaned = cleanTrackUrls({ embedUrl: 'javascript:alert(1)', sourceUrl: 'https://soundcloud.com/a/b' });
  assert.equal(cleaned.embedUrl, undefined);
  assert.equal(cleaned.sourceUrl, 'https://soundcloud.com/a/b');
});

test('JSON bodies are read only when the client declares application/json', async () => {
  const { readJsonBody } = await loadModule('src/lib/input.js');
  const json = await readJsonBody(new Request('http://localhost/api', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{"name":"x"}',
  }));
  assert.deepEqual(json, { name: 'x' });
  assert.equal(await readJsonBody(new Request('http://localhost/api', { method: 'POST', body: '{"name":"x"}' })), undefined);
  assert.equal(await readJsonBody(new Request('http://localhost/api', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{bad',
  })), null);
});

test('text and integer helpers bound caller input', async () => {
  const { boundedText, clampInteger, optionalText, isObjectIdString } = await loadModule('src/lib/input.js');
  assert.equal(boundedText('  hi  ', 5), 'hi');
  assert.equal(boundedText('   ', 5), undefined);
  assert.equal(boundedText('toolong', 3), undefined);
  assert.equal(boundedText(5, 9), undefined);
  assert.equal(optionalText('abcdef', 3), 'abc');
  assert.equal(optionalText({}, 3), undefined);
  assert.equal(clampInteger('500', 1, 50, 10), 50);
  assert.equal(clampInteger('0', 1, 50, 10), 1);
  assert.equal(clampInteger('x', 1, 50, 10), 10);
  assert.equal(clampInteger(null, 1, 200, 50), 50);
  assert.equal(isObjectIdString('507f1f77bcf86cd799439011'), true);
  assert.equal(isObjectIdString('not-an-id'), false);
});

test('recommendations rank artists, skip placeholders, and exclude songs already heard', async () => {
  const { rankArtists, excludeHeard, mergeUnique } = await loadModule('src/lib/recommendations.js');
  // Arrays built inside the loaded module come from its VM realm, so copy them before comparing.
  assert.deepEqual(Array.from(rankArtists([
    { artist: 'A' }, { artist: 'B' }, { artist: 'A' }, { artist: 'Unknown artist' }, { artist: '' }, { artist: 'C' },
  ], 2)), ['A', 'B']);
  assert.deepEqual(Array.from(excludeHeard([{ id: '1' }, { id: '2' }, null], new Set(['1'])), (song) => song.id), ['2']);
  assert.deepEqual(Array.from(mergeUnique([[{ id: 'a' }, { id: 'b' }], [{ id: 'a' }, { id: 'c' }]], 3), (song) => song.id), ['a', 'b', 'c']);
});
