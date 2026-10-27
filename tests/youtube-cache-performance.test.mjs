import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';

const song = { id: 'NORMAL00001', title: 'Original test song', durationSeconds: 120 };

async function fixture({ cached = null, writeFails = false, searchFails = false, empty = false } = {}) {
  const requests = [];
  const writes = [];
  const { getYouTubeSongs } = await loadModule('src/lib/youtube.js', {
    '@/lib/mongodb': { default: async () => {} },
    '@/models/SongCache': { default: {
      findOne: () => ({ lean: async () => cached }),
      findOneAndUpdate: async (...args) => { writes.push(args); if (writeFails) throw new Error('Cache write unavailable'); },
    } },
  }, {
    process: { env: { YOUTUBE_API_KEY: 'public-test-key' } },
    fetch: async (input, options) => {
      const url = new URL(input);
      requests.push({ url, options });
      if (url.pathname.endsWith('/search')) return searchFails ? Response.json({ error: { message: 'Test outage' } }, { status: 503 })
        : Response.json({ items: empty ? [] : [{ id: { videoId: song.id }, snippet: { title: song.title, channelTitle: 'Artist', thumbnails: { high: { url: 'https://i.ytimg.com/test.jpg' } } } }], nextPageToken: 'next' });
      if (url.pathname.endsWith('/videos')) return Response.json({ items: [{ id: song.id, statistics: { viewCount: '50' }, contentDetails: { duration: 'PT2M' } }] });
      return new Response(null, { status: 303, headers: { location: `https://www.youtube.com/watch?v=${song.id}` } });
    },
  });
  return { getYouTubeSongs, requests, writes };
}

test('a fresh filtered cache answers without YouTube API calls or Shorts probes', async () => {
  const cached = { cachedAt: new Date(), shortsFiltered: true, songs: [song], nextPageToken: 'cached-next' };
  const f = await fixture({ cached });
  const result = await f.getYouTubeSongs('music');
  assert.equal(result.items[0].id, song.id);
  assert.equal(result.nextPageToken, 'cached-next');
  assert.equal(f.requests.length, 0);
  assert.equal(f.writes.length, 0);
});

test('a legacy cache is filtered once and upgraded without extending its original TTL', async () => {
  const cached = { cachedAt: new Date(Date.now() - 60000), songs: [song] };
  const original = JSON.stringify(cached);
  const f = await fixture({ cached });
  const result = await f.getYouTubeSongs('music');
  assert.equal(result.items.length, 1);
  assert.equal(JSON.stringify(cached), original);
  assert.equal(f.writes.length, 1);
  assert.equal(f.writes[0][1].$set.shortsFiltered, true);
  assert.equal('cachedAt' in f.writes[0][1].$set, false);
  assert.equal(f.writes[0][2]?.upsert, undefined);
});

test('simultaneous identical cache misses share one YouTube request pipeline', async () => {
  const f = await fixture();
  const results = await Promise.all(Array.from({ length: 6 }, () => f.getYouTubeSongs('music')));
  assert.ok(results.every(result => result.items[0].id === song.id));
  assert.equal(f.requests.filter(r => r.url.pathname.endsWith('/search')).length, 1);
  assert.equal(f.writes.length, 1);
});

test('a cache write failure returns fetched songs without repeating the YouTube search', async () => {
  const f = await fixture({ writeFails: true });
  assert.equal((await f.getYouTubeSongs('music')).items[0].id, song.id);
  assert.equal(f.requests.filter(r => r.url.pathname.endsWith('/search')).length, 1);
});

test('successful empty results are cached, while API failures are not', async () => {
  const empty = await fixture({ empty: true });
  assert.equal((await empty.getYouTubeSongs('music')).items.length, 0);
  assert.equal(empty.writes.length, 1);
  assert.equal(empty.writes[0][1].shortsFiltered, true);
  const failed = await fixture({ searchFails: true });
  assert.equal((await failed.getYouTubeSongs('music')).items.length, 0);
  assert.equal(failed.writes.length, 0);
});

test('YouTube search and statistics have explicit request deadlines', async () => {
  const f = await fixture();
  await f.getYouTubeSongs('music');
  assert.ok(f.requests.filter(r => r.url.hostname === 'www.googleapis.com').every(r => r.options.signal instanceof AbortSignal));
});

test('the cache schema preserves optional duration and Shorts filtering metadata', async () => {
  const { default: SongCache } = await loadModule('src/models/SongCache.js');
  const document = new SongCache({ cacheKey: 'test', query: 'test', order: 'relevance', songs: [song], shortsFiltered: true }).toObject();
  assert.equal(document.songs[0].durationSeconds, 120);
  assert.equal(document.shortsFiltered, true);
});
