import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';

const metadata = { title: 'Original Song', artist: 'Original Artist', duration: 180 };
const plain = 'Original lyrics written only for this test.\nA second original test line.';
const noPrimary = url => new URL(url).pathname === '/api/get' ? new Response(null, { status: 404 }) : Response.json([]);

test('missing LRCLIB lyrics fall back to lyrics.ovh plain text without synthetic timestamps', async () => {
  const requests = [];
  const { lookupLyrics } = await loadModule('src/lib/lyrics-provider.js', {}, {
    fetch: async (url, options) => {
      requests.push({ url: new URL(url), options });
      return new URL(url).hostname === 'lrclib.net' ? noPrimary(url) : Response.json({ lyrics: plain });
    },
  });
  const result = await lookupLyrics(metadata);
  assert.equal(result.source, 'lyrics.ovh');
  assert.equal(result.status, 'plain');
  assert.equal(result.plainLyrics, plain);
  assert.equal(result.lines.length, 0);
  assert.equal(requests.length, 3);
  assert.equal(requests[2].url.origin, 'https://api.lyrics.ovh');
  assert.equal(requests[2].options.redirect, 'error');
  assert.ok(requests[2].options.signal instanceof AbortSignal);
});

test('LRCLIB rate limiting stops LRCLIB calls but permits the independent backup', async () => {
  let primaryCalls = 0;
  const { lookupLyrics } = await loadModule('src/lib/lyrics-provider.js', {}, {
    fetch: async url => new URL(url).hostname === 'lrclib.net'
      ? (primaryCalls++, new Response(null, { status: 429 })) : Response.json({ lyrics: plain }),
  });
  assert.equal((await lookupLyrics(metadata)).source, 'lyrics.ovh');
  assert.equal(primaryCalls, 1);
});

test('a timed-out primary can recover through a separately bounded backup request', async () => {
  const { lookupLyrics } = await loadModule('src/lib/lyrics-provider.js', {}, {
    fetch: async url => {
      if (new URL(url).hostname === 'lrclib.net') throw new DOMException('Test timeout', 'TimeoutError');
      return Response.json({ lyrics: plain });
    },
  });
  assert.equal((await lookupLyrics(metadata)).status, 'plain');
});

test('usable LRCLIB synced, plain and instrumental results never call the backup', async () => {
  for (const record of [
    { syncedLyrics: '[00:01.00]First original test line\n[00:04.00]Second original test line' },
    { plainLyrics: plain }, { instrumental: true },
  ]) {
    const { lookupLyrics } = await loadModule('src/lib/lyrics-provider.js', {}, {
      fetch: async url => {
        assert.equal(new URL(url).hostname, 'lrclib.net');
        return new URL(url).pathname === '/api/get' ? Response.json({ trackName: metadata.title, artistName: metadata.artist, duration: 180, ...record }) : Response.json([]);
      },
    });
    assert.equal((await lookupLyrics(metadata)).source, 'LRCLIB');
  }
});

test('backup paths preserve all collaboration credits and version names as encoded segments', async () => {
  let backup;
  const { lookupLyrics } = await loadModule('src/lib/lyrics-provider.js', {}, {
    fetch: async url => {
      if (new URL(url).hostname === 'lrclib.net') return noPrimary(url);
      backup = new URL(url);
      return Response.json({ lyrics: plain });
    },
  });
  await lookupLyrics({ title: 'Song (Live / Remix) #1?', artist: 'Artist & Guest / Duo', duration: 180 });
  assert.equal(backup.origin, 'https://api.lyrics.ovh');
  const parts = backup.pathname.split('/');
  assert.equal(parts.length, 4);
  assert.equal(decodeURIComponent(parts[2]), 'Artist & Guest / Duo');
  assert.equal(decodeURIComponent(parts[3]), 'Song (Live / Remix) #1?');
  assert.equal(backup.search, '');
  assert.equal(backup.hash, '');
});

test('both providers missing lyrics remains unavailable; a failing backup remains retryable', async () => {
  const absent = await loadModule('src/lib/lyrics-provider.js', {}, {
    fetch: async url => new URL(url).hostname === 'lrclib.net' ? noPrimary(url) : new Response(null, { status: 404 }),
  });
  assert.equal((await absent.lookupLyrics(metadata)).status, 'unavailable');
  const failed = await loadModule('src/lib/lyrics-provider.js', {}, {
    fetch: async url => new URL(url).hostname === 'lrclib.net' ? noPrimary(url) : new Response(null, { status: 503 }),
  });
  await assert.rejects(failed.lookupLyrics(metadata));
});

test('malformed, empty or oversized backup content never becomes displayed lyrics', async () => {
  for (const payload of [{ lyrics: {} }, { lyrics: '   ' }, { lyrics: 'x'.repeat(80001) }, { error: 'Not found' }]) {
    const { lookupLyrics } = await loadModule('src/lib/lyrics-provider.js', {}, {
      fetch: async url => new URL(url).hostname === 'lrclib.net' ? noPrimary(url) : Response.json(payload),
    });
    await assert.rejects(lookupLyrics(metadata));
  }
});
