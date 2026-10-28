import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';

const lines = '[00:01.00]Original first test line\n[00:04.00]Original second test line';

test('YouTube titles separate presentation labels and featured credits from the track name', async () => {
  const { lyricsMetadata } = await loadModule('src/lib/lyrics.js');
  const result = lyricsMetadata({ title: 'Hngle - Tìm em ft. Bảo Anh | Official Music Video', artist: 'HNGLE / hưng lê' }, 272);
  assert.equal(result.title, 'Tìm em');
  assert.equal(result.artist, 'Hngle, Bảo Anh');
  assert.equal(result.duration, 272);
  const bracketed = lyricsMetadata({ title: 'Artist - Song (feat. Guest) [Official Audio]', artist: 'Channel' }, 180);
  assert.equal(bracketed.title, 'Song');
  assert.equal(bracketed.artist, 'Artist, Guest');
  assert.equal(lyricsMetadata({ title: 'Artist - Song | Live', artist: 'Artist' }, 180).title, 'Song | Live');
});

test('collaboration matching accepts the same complete credits in the title or artist field', async () => {
  const { selectLyrics } = await loadModule('src/lib/lyrics.js');
  const metadata = { title: 'Tìm em', artist: 'Hngle, Bảo Anh', duration: 272 };
  for (const credits of [
    { trackName: 'Tìm Em', artistName: 'Hngle & Bảo Anh' },
    { trackName: 'Tìm Em (feat. Bảo Anh)', artistName: 'Hngle' },
    { trackName: 'Tìm Em', artistName: 'Bảo Anh, Hngle' },
  ]) {
    const result = selectLyrics([{ ...credits, duration: 274, syncedLyrics: lines }], metadata);
    assert.equal(result.status, 'synced');
    assert.equal(result.lines.length, 2);
  }
  for (const credits of [
    { trackName: 'Tìm Em', artistName: 'Hngle' },
    { trackName: 'Tìm Em', artistName: 'Hngle, Someone Else' },
    { trackName: 'Tìm Em (Remix)', artistName: 'Hngle, Bảo Anh' },
  ]) assert.equal(selectLyrics([{ ...credits, duration: 274, syncedLyrics: lines }], metadata).status, 'unavailable');
});

test('a transient direct lookup failure still uses search and matches the full collaboration', async () => {
  const requests = [];
  const { lookupLyrics } = await loadModule('src/lib/lyrics-provider.js', {}, {
    fetch: async url => {
      requests.push(new URL(url));
      if (new URL(url).pathname === '/api/get') return Response.json({ name: 'ServerOverloaded' }, { status: 503 });
      return Response.json([{ trackName: 'Tìm Em (feat. Bảo Anh)', artistName: 'Hngle', duration: 274, syncedLyrics: lines }]);
    },
  });
  const result = await lookupLyrics({ title: 'Tìm em', artist: 'Hngle, Bảo Anh', duration: 272 });
  assert.equal(result.status, 'synced');
  assert.equal(requests.length, 2);
  assert.equal(requests[1].searchParams.get('track_name'), 'Tìm em');
  assert.equal(requests[1].searchParams.get('artist_name'), 'Hngle');
});

test('a completed direct result with plain lyrics still considers a synchronized search result', async () => {
  const { lookupLyrics } = await loadModule('src/lib/lyrics-provider.js', {}, {
    fetch: async url => new URL(url).pathname === '/api/get'
      ? Response.json({ trackName: 'Song', artistName: 'Artist', duration: 180, plainLyrics: 'Original plain test text '.repeat(5) })
      : Response.json([{ trackName: 'Song', artistName: 'Artist', duration: 180, syncedLyrics: lines }]),
  });
  assert.equal((await lookupLyrics({ title: 'Song', artist: 'Artist', duration: 180 })).status, 'synced');
});

test('a direct lookup timeout leaves a separate bounded search attempt available', async () => {
  const signals = [];
  const { lookupLyrics } = await loadModule('src/lib/lyrics-provider.js', {}, {
    fetch: async (url, options) => {
      signals.push(options.signal);
      if (new URL(url).pathname === '/api/get') throw new DOMException('Test timeout', 'TimeoutError');
      return Response.json([{ trackName: 'Song', artistName: 'Artist', duration: 180, syncedLyrics: lines }]);
    },
  });
  assert.equal((await lookupLyrics({ title: 'Song', artist: 'Artist', duration: 180 })).status, 'synced');
  assert.equal(signals.length, 2);
  assert.notEqual(signals[0], signals[1]);
});

test('rate limiting stops LRCLIB fan-out and a good result survives search failure', async () => {
  let calls = 0;
  const limited = await loadModule('src/lib/lyrics-provider.js', {}, { fetch: async url => { if (new URL(url).hostname === 'lrclib.net') calls++; return new Response(null, { status: 429 }); } });
  await assert.rejects(limited.lookupLyrics({ title: 'Song', artist: 'Artist', duration: 180 }));
  assert.equal(calls, 1);
  const fallback = await loadModule('src/lib/lyrics-provider.js', {}, {
    fetch: async url => new URL(url).pathname === '/api/get'
      ? Response.json({ trackName: 'Song', artistName: 'Artist', duration: 180, plainLyrics: 'Original test text' })
      : new Response(null, { status: 503 }),
  });
  const result = await fallback.lookupLyrics({ title: 'Song', artist: 'Artist', duration: 180 });
  assert.equal(result.status, 'plain');
  assert.equal(result.plainLyrics, 'Original test text');
});
