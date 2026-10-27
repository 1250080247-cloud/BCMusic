import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';

test('LRC parses timestamps, repeated timestamps and metadata without turning lyrics into markup', async () => {
  const { parseLrc, activeLineAt } = await loadModule('src/lib/lyrics.js');
  const lines = parseLrc('[ar:Test]\n[00:02.50]Second\n[00:01.00][00:04.00]First <script>text</script>\n[99:99]invalid');
  assert.deepEqual(Array.from(lines, line => ({ time: line.time, text: line.text })), [
    { time: 1, text: 'First <script>text</script>' },
    { time: 2.5, text: 'Second' },
    { time: 4, text: 'First <script>text</script>' },
  ]);
  assert.equal(activeLineAt(lines, 0.99), -1);
  assert.equal(activeLineAt(lines, 2.5), 1);
  assert.equal(activeLineAt(lines, 999), 2);
});

test('lyric metadata removes video presentation labels while preserving different recording versions', async () => {
  const { lyricsMetadata } = await loadModule('src/lib/lyrics.js');
  const metadata = lyricsMetadata({ title: 'Artist - Song (Official Music Video)', artist: 'ArtistVEVO' }, 180);
  assert.equal(metadata.title, 'Song');
  assert.equal(metadata.artist, 'Artist');
  assert.equal(metadata.duration, 180);
  assert.equal(lyricsMetadata({ title: 'Artist - Song (Official Video) (4K Remaster)', artist: 'Artist' }, 180).title, 'Song');
  assert.equal(lyricsMetadata({ title: 'Artist - Song (Live Remix)', artist: 'Artist - Topic' }, 190).title, 'Song (Live Remix)');
});

test('lyrics matching rejects a different artist, recording version, and malformed upstream data', async () => {
  const { selectLyrics } = await loadModule('src/lib/lyrics.js');
  const metadata = { title: 'Song', artist: 'Artist', duration: 180 };
  const track = { trackName: 'Song', artistName: 'Artist', duration: 180, plainLyrics: 'A test line', syncedLyrics: '[00:01.00]A test line' };
  assert.equal(selectLyrics([{ ...track, artistName: 'Someone else' }], metadata).status, 'unavailable');
  assert.equal(selectLyrics([{ ...track, trackName: 'Song (Cover)' }], metadata).status, 'unavailable');
  assert.equal(selectLyrics([null, { ...track, plainLyrics: {} }], metadata).status, 'unavailable');
  assert.equal(selectLyrics([track], metadata).status, 'synced');
});

test('lyrics only synchronize matching durations; unknown/different durations fall back to plain text', async () => {
  const { selectLyrics } = await loadModule('src/lib/lyrics.js');
  const track = { trackName: 'Song', artistName: 'Artist', duration: 180, syncedLyrics: '[00:01.00]A test line' };
  for (const duration of [0, 200]) {
    const result = selectLyrics([track], { title: 'Song', artist: 'Artist', duration });
    assert.equal(result.status, 'plain');
    assert.equal(result.plainLyrics, 'A test line');
    assert.equal(result.lines.length, 0);
  }
  assert.equal(selectLyrics([{ ...track, instrumental: true }], { title: 'Song', artist: 'Artist', duration: 180 }).status, 'instrumental');
});

test('matching prefers complete timed lyrics over a one-line placeholder for the same recording', async () => {
  const { selectLyrics } = await loadModule('src/lib/lyrics.js');
  const record = { trackName: 'Song', artistName: 'Artist', duration: 180 };
  const result = selectLyrics([
    { ...record, syncedLyrics: '[00:00.00]test' },
    { ...record, syncedLyrics: '[00:01.00]Original first line\n[00:04.00]Original second line' },
  ], { title: 'Song', artist: 'Artist', duration: 180 });
  assert.equal(result.lines.length, 2);
});

test('lyrics API rejects invalid metadata before any external lookup and contains upstream failures', async () => {
  let calls = 0;
  const { GET } = await loadModule('src/app/api/lyrics/route.js', {
    '@/lib/lyrics-provider': { lookupLyrics: async () => { calls++; throw new Error('private upstream detail'); } },
    'next/server': { NextResponse: { json: (data, options) => Response.json(data, options) } },
  });
  for (const query of ['title=&artist=Artist', 'title=Song&artist=Artist&duration=-1', `title=${'a'.repeat(251)}&artist=Artist`]) {
    assert.equal((await GET(new Request(`http://localhost/api/lyrics?${query}`))).status, 400);
  }
  assert.equal(calls, 0);
  const result = await GET(new Request('http://localhost/api/lyrics?title=Song&artist=Artist&duration=180'));
  assert.equal(result.status, 503);
  assert.equal(JSON.stringify(await result.json()).includes('private upstream detail'), false);
});

test('LRCLIB requests use the fixed HTTPS provider, exact metadata and bounded cancellation', async () => {
  const requests = [];
  const record = { trackName: 'Song', artistName: 'Artist', duration: 180, syncedLyrics: '[00:01.00]Original first line\n[00:04.00]Original second line' };
  const { lookupLyrics } = await loadModule('src/lib/lyrics-provider.js', {}, {
    fetch: async (url, options) => {
      requests.push({ url: new URL(url), options });
      return Response.json(record);
    },
  });
  assert.equal((await lookupLyrics({ title: 'Song', artist: 'Artist', duration: 180 })).status, 'synced');
  assert.equal(requests.length, 1);
  assert.equal(requests[0].url.origin, 'https://lrclib.net');
  assert.equal(requests[0].url.pathname, '/api/get');
  assert.equal(requests[0].url.searchParams.get('duration'), '180');
  assert.equal(requests[0].options.redirect, 'error');
  assert.ok(requests[0].options.signal instanceof AbortSignal);
});

test('LRCLIB search fallback rejects unrelated recordings and upstream HTTP errors', async () => {
  let calls = 0;
  const record = { trackName: 'Song', artistName: 'Artist', duration: 180, plainLyrics: 'Original test text' };
  const { lookupLyrics } = await loadModule('src/lib/lyrics-provider.js', {}, {
    fetch: async () => ++calls === 1 ? new Response(null, { status: 404 }) : Response.json([{ ...record, artistName: 'Someone else' }, record]),
  });
  const result = await lookupLyrics({ title: 'Song', artist: 'Artist', duration: 180 });
  assert.equal(calls, 2);
  assert.equal(result.status, 'plain');
  const failed = await loadModule('src/lib/lyrics-provider.js', {}, { fetch: async () => new Response(null, { status: 429 }) });
  await assert.rejects(failed.lookupLyrics({ title: 'Song', artist: 'Artist', duration: 180 }));
});
