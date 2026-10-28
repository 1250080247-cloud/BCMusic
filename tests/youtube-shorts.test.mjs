import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';
import { createHookHarness, deferredFetch, find, findAll, settle, textContent } from './ui-harness.mjs';

const shortId = 'SHORT000001';
const normalId = 'NORMAL00001';
const longId = 'LONG0000001';
const unknownId = 'UNKNOWN0001';
const mainCsp = 'default-src https:; report-uri https://csp.withgoogle.com/csp/youtube_main';
const shortPage = () => new Response(null, { headers: { 'content-type': 'text/html; charset=utf-8', 'content-length': '0', 'content-security-policy': mainCsp } });
const regularPage = id => new Response(null, { status: 303, headers: { location: `https://www.youtube.com/watch?v=${id}` } });

async function youtubeFixture({ ids = [normalId, shortId, longId, unknownId], cached = null, probe, globals = {}, durationOverrides = {}, statsResponse } = {}) {
  const requests = [];
  const writes = [];
  const durations = { [normalId]: 'PT2M', [shortId]: 'PT45S', [longId]: 'PT45M', [unknownId]: 'PT2M45S', ...durationOverrides };
  const { getYouTubeSongs } = await loadModule('src/lib/youtube.js', {
    '@/lib/mongodb': { default: async () => {} },
    '@/models/SongCache': { default: {
      findOne: () => ({ lean: async () => cached }),
      findOneAndUpdate: async (...args) => { writes.push(args); },
    } },
  }, {
    process: { env: { YOUTUBE_API_KEY: 'fake-test-api-key' } },
    fetch: async (input, options = {}) => {
      const url = new URL(input);
      requests.push({ url, options });
      if (url.hostname === 'www.googleapis.com' && url.pathname.endsWith('/search')) {
        return Response.json({ items: ids.map(id => ({ id: { videoId: id }, snippet: {
          title: `Song ${id}`, channelTitle: 'Artist', thumbnails: { high: { url: 'https://i.ytimg.com/test.jpg' } }, publishedAt: '2026-01-01',
        } })), nextPageToken: 'next-real-token', prevPageToken: 'previous-real-token' });
      }
      if (url.hostname === 'www.googleapis.com' && url.pathname.endsWith('/videos')) {
        if (statsResponse) return statsResponse();
        return Response.json({ items: ids.map(id => ({ id, statistics: { viewCount: '123' }, contentDetails: { duration: Object.hasOwn(durations, id) ? durations[id] : 'PT2M' } })) });
      }
      assert.equal(url.hostname, 'www.youtube.com', 'probe cannot contact a caller-controlled host');
      assert.equal(options.method, 'HEAD');
      assert.equal(options.redirect, 'manual', 'probe never follows redirects to another service');
      assert.ok(options.signal, 'probe has a bounded timeout');
      if (probe) return probe(url.pathname.split('/').at(-1), options);
      if (url.pathname.endsWith(shortId)) return shortPage();
      if (url.pathname.endsWith(unknownId)) return new Response(null, { status: 403 });
      return regularPage(url.pathname.split('/').at(-1));
    },
    ...globals,
  });
  return { getYouTubeSongs, requests, writes };
}

test('YouTube search removes the medium-duration restriction and keeps regular songs below 2:30 and above 20 minutes', async () => {
  const fixture = await youtubeFixture();
  const result = await fixture.getYouTubeSongs('music', 'current-token', 'relevance', 10);
  assert.deepEqual(Array.from(result.items, item => item.id), [normalId, longId]);
  const search = fixture.requests.find(({ url }) => url.pathname.endsWith('/search')).url;
  assert.equal(search.searchParams.get('videoDuration'), null);
  assert.equal(search.searchParams.get('q'), 'music');
  assert.equal(search.searchParams.get('pageToken'), 'current-token');
  assert.equal(result.nextPageToken, 'next-real-token');
  assert.equal(result.prevPageToken, 'previous-real-token');
  assert.equal(fixture.requests.some(({ url }) => url.pathname === `/shorts/${longId}`), false, 'a 45-minute video cannot be a Short');
});

test('regular videos must exceed 30 seconds but have no maximum duration', async () => {
  const fixture = await youtubeFixture({ ids: [normalId, longId], durationOverrides: { [normalId]: 'PT1S', [longId]: 'P1DT2H' } });
  const result = await fixture.getYouTubeSongs('music');
  assert.deepEqual(Array.from(result.items, song => song.id), [longId]);
  assert.deepEqual(Array.from(result.items, song => song.durationSeconds), [93600]);
  const query = fixture.requests.find(({ url }) => url.pathname.endsWith('/search')).url.searchParams;
  assert.equal(query.has('videoDuration'), false);
});

test('fresh results exclude 30 seconds or less and unknown duration, retaining pagination and long songs', async () => {
  const ids = Array.from({ length: 9 }, (_, i) => `VIDEO00000${i}`);
  const values = ['PT0S', 'PT29.9S', 'PT30S', 'PT30.1S', 'PT31S', 'P1DT2H', null, undefined, 'invalid'];
  const fixture = await youtubeFixture({ ids, durationOverrides: Object.fromEntries(ids.map((id, i) => [id, values[i]])) });
  const result = await fixture.getYouTubeSongs('music');
  assert.deepEqual(Array.from(result.items, song => song.id), ids.slice(3, 6));
  assert.equal(result.nextPageToken, 'next-real-token');
  assert.equal(result.prevPageToken, 'previous-real-token');
  assert.deepEqual(Array.from(fixture.writes[0][1].songs, song => song.id), ids.slice(3, 6));
});

for (const shortsFiltered of [true, false]) {
  test(`duration cutoff applies on cache reads even when shortsFiltered=${shortsFiltered}, without deleting stored songs`, async () => {
    const durations = [0, 29, 30, 30.1, 31, 93600, null, undefined];
    const songs = durations.map((durationSeconds, i) => ({ id: `VIDEO00000${i}`, title: 'Cached song', durationSeconds }));
    const cached = { cachedAt: new Date(), shortsFiltered, songs, nextPageToken: 'next', prevPageToken: 'prev' };
    const before = JSON.stringify(cached);
    const fixture = await youtubeFixture({ cached });
    const result = await fixture.getYouTubeSongs('music');
    assert.deepEqual(Array.from(result.items, song => song.id), songs.slice(3, 6).map(song => song.id));
    assert.equal(JSON.stringify(cached), before);
    assert.equal(result.nextPageToken, 'next');
    assert.equal(result.prevPageToken, 'prev');
    assert.ok(fixture.requests.some(request => request.url.hostname === 'www.youtube.com'), 'the old lenient marker is not sufficient');
    assert.equal(fixture.writes[0][1].$set.songs.length, songs.length, 'duration filtering must not rewrite the old cache');
  });
}

for (const [name, statsResponse] of [
  ['503', () => Response.json({ error: 'Unavailable' }, { status: 503 })],
  ['timeout', () => { throw Object.assign(new Error('Timeout'), { name: 'TimeoutError' }); }],
]) {
  test(`duration metadata ${name} hides unchecked videos without caching an outage as an empty page`, async () => {
    const fixture = await youtubeFixture({ statsResponse });
    assert.equal((await fixture.getYouTubeSongs('music')).items.length, 0);
    assert.equal(fixture.writes.length, 0);
  });
}

test('legacy cached rows are filtered without mutating the read object and use the unrestricted-search cache namespace', async () => {
  const cached = { cachedAt: new Date(), songs: [normalId, shortId, unknownId].map(id => ({ id, title: `Song ${id}`, durationSeconds: 120 })), nextPageToken: 'cached-next', prevPageToken: 'cached-prev' };
  const before = JSON.stringify(cached);
  const fixture = await youtubeFixture({ cached, probe: id => id === shortId ? shortPage() : regularPage(id) });
  const result = await fixture.getYouTubeSongs('music');
  assert.deepEqual(Array.from(result.items, item => item.id), [normalId, unknownId]);
  assert.equal(result.nextPageToken, 'cached-next');
  assert.equal(result.prevPageToken, 'cached-prev');
  assert.equal(JSON.stringify(cached), before);
  assert.equal(fixture.writes.length, 1);
  assert.deepEqual(Array.from(fixture.writes[0][1].$set.songs, song => song.id), [normalId, unknownId]);
  assert.equal(fixture.writes[0][1].$set.shortsFiltered, true);
  assert.equal('cachedAt' in fixture.writes[0][1].$set, false);
  assert.equal(fixture.requests.some(({ url }) => url.hostname === 'www.googleapis.com'), false);
  const fresh = await youtubeFixture({ ids: [normalId, shortId, longId] });
  await fresh.getYouTubeSongs('music');
  assert.match(fresh.writes[0][0].cacheKey, /^youtube-no-shorts-v2:/);
});

for (const [name, response] of [
  ['forbidden', () => new Response(null, { status: 403 })],
  ['not found', () => new Response(null, { status: 404 })],
  ['rate limited', () => new Response(null, { status: 429 })],
  ['JSON error disguised as 200', () => new Response(null, { headers: { 'content-type': 'application/json', 'content-length': '1450000' } })],
  ['small HTML interstitial', () => new Response(null, { headers: { 'content-type': 'text/html', 'content-length': '1200', 'content-security-policy': mainCsp } })],
  ['large HTML without the YouTube main app signature', () => new Response(null, { headers: { 'content-type': 'text/html', 'content-length': '1450000' } })],
  ['unverifiable HTML without length', () => new Response(null, { headers: { 'content-type': 'text/html' } })],
  ['consent redirect', () => new Response(null, { status: 302, headers: { location: 'https://consent.youtube.com/' } })],
  ['redirect to another video', () => regularPage(shortId)],
  ['network timeout', () => { throw Object.assign(new Error('Timed out'), { name: 'TimeoutError' }); }],
]) {
  test(`unknown Shorts classification (${name}) is hidden and not cached as a verified page`, async () => {
    const fixture = await youtubeFixture({ ids: [normalId], probe: response });
    const result = await fixture.getYouTubeSongs('music');
    assert.equal(result.items.length, 0);
    assert.equal(fixture.writes.length, 0);
  });
}

test('Shorts probes are cached across reads and cap concurrent requests', async () => {
  let active = 0;
  let peak = 0;
  const ids = Array.from({ length: 10 }, (_, i) => `VIDEO00000${i}`);
  const cached = { cachedAt: new Date(), songs: ids.map(id => ({ id, title: id, durationSeconds: 120 })) };
  const fixture = await youtubeFixture({ cached, probe: async id => {
    active += 1;
    peak = Math.max(peak, active);
    await new Promise(resolve => setTimeout(resolve, 3));
    active -= 1;
    return regularPage(id);
  } });
  assert.equal((await fixture.getYouTubeSongs('music')).items.length, ids.length);
  assert.equal((await fixture.getYouTubeSongs('music')).items.length, ids.length);
  assert.ok(peak <= 4, `expected at most 4 probes, observed ${peak}`);
  assert.ok(peak > 1, 'requests should not be unnecessarily serial');
  assert.equal(fixture.requests.length, ids.length, 'each cached classification is reused');
});

test('a bounded batch hides unclassified videos when the total probe time budget is exhausted', async () => {
  let now = Date.now();
  class Clock extends Date { static now() { return now; } }
  const ids = Array.from({ length: 9 }, (_, i) => `VIDEO00000${i}`);
  const fixture = await youtubeFixture({ ids, globals: { Date: Clock }, probe: () => { now += 1000; return shortPage(); } });
  const result = await fixture.getYouTubeSongs('music');
  const probes = fixture.requests.filter(({ url }) => url.hostname === 'www.youtube.com');
  assert.ok(probes.length > 0, 'the classifier should check the initial candidates');
  assert.ok(probes.length <= 4, `work must stop when the shared deadline expires (${probes.length} probes)`);
  assert.equal(result.items.length, 0, 'Shorts and unchecked videos must both be hidden');
  assert.equal(fixture.writes.length, 0, 'a partial classification cannot be cached for an hour');
});

test('invalid legacy IDs never become arbitrary URLs in Shorts probes', async () => {
  const cached = { cachedAt: new Date(), songs: [{ id: '../../private', title: 'Legacy entry', durationSeconds: 120 }] };
  const fixture = await youtubeFixture({ cached });
  assert.equal((await fixture.getYouTubeSongs('music')).items.length, 0);
  assert.equal(fixture.requests.length, 0);
});

test('an empty filtered search page still exposes real next and previous pagination tokens', async () => {
  const harness = createHookHarness();
  const deferred = deferredFetch();
  const navigations = [];
  const settings = { language: 'en', searchHistory: [], addSearchHistory() {} };
  const { default: SearchView } = await loadModule('src/components/SearchView.js', {
    react: harness.react,
    'next/navigation': { useRouter: () => ({ push: url => navigations.push(url) }), useSearchParams: () => new URLSearchParams('q=music') },
    '@/lib/store': { useSettingsStore: selector => selector(settings) },
    '@/components/SongCard': { default: () => null },
  }, { fetch: deferred.fetch });
  const content = find(SearchView(), node => typeof node.type === 'function' && node.type.name === 'SearchContent');
  try {
    harness.render(content.type);
    harness.flushEffects();
    deferred.requests[0].resolve({ items: [], nextPageToken: 'next-real-token', prevPageToken: 'previous-real-token' });
    await settle();
    const tree = harness.render(content.type);
    const buttons = findAll(tree, node => node.type === 'button');
    const next = buttons.find(node => textContent(node).includes('Next page'));
    const previous = buttons.find(node => textContent(node).includes('Previous page'));
    assert.ok(next, 'next page must remain available after every result on this page was filtered');
    assert.ok(previous);
    next.props.onClick();
    assert.equal(new URL(navigations[0], 'http://localhost').searchParams.get('token'), 'next-real-token');
  } finally { harness.unmount(); }
});

test('an expired classification never lets an unchecked video through after the batch budget expires', async () => {
  let now = Date.now();
  let expired = false;
  class Clock extends Date { static now() { return now; } }
  const cached = { cachedAt: new Date(now), songs: [{ id: shortId, title: 'Song', durationSeconds: 120 }] };
  const fixture = await youtubeFixture({ cached, globals: { Date: Clock }, probe: id => {
    if (!expired) return shortPage();
    now += 1000;
    return regularPage(id);
  } });
  assert.equal((await fixture.getYouTubeSongs('music')).items.length, 0);
  now += 24 * 60 * 60 * 1000 + 1;
  expired = true;
  cached.cachedAt = new Date(now);
  cached.songs = [...Array.from({ length: 4 }, (_, i) => ({ id: `VIDEO00000${i}`, title: 'Regular song', durationSeconds: 120 })), { id: shortId, title: 'Unverified now', durationSeconds: 120 }];
  assert.equal((await fixture.getYouTubeSongs('music')).items.some(song => song.id === shortId), false);
});

test('a formerly verified lenient cache is rechecked and hides a Short and unknown result', async () => {
  const cached = { cachedAt: new Date(), shortsFiltered: true, songs: [normalId, shortId, unknownId, longId].map(id => ({ id, title: id, durationSeconds: id === longId ? 2700 : 120 })) };
  const before = JSON.stringify(cached);
  const fixture = await youtubeFixture({ cached });
  const result = await fixture.getYouTubeSongs('music');
  assert.deepEqual(Array.from(result.items, song => song.id), [normalId, longId]);
  assert.equal(JSON.stringify(cached), before);
  assert.equal(fixture.writes.length, 0, 'incomplete classification must not overwrite or certify the old cache');
});

test('blocked cached videos can be verified again after the short retry TTL without certifying an outage', async () => {
  let now = Date.now();
  let blocked = true;
  class Clock extends Date { static now() { return now; } }
  const cached = { cachedAt: new Date(now), shortsFiltered: true, songs: [{ id: normalId, title: 'Song', durationSeconds: 120 }] };
  const fixture = await youtubeFixture({ cached, globals: { Date: Clock }, probe: id => blocked ? new Response(null, { status: 403 }) : regularPage(id) });
  assert.equal((await fixture.getYouTubeSongs('music')).items.length, 0);
  assert.equal(fixture.writes.length, 0);
  blocked = false;
  now += 30001;
  assert.equal((await fixture.getYouTubeSongs('music')).items[0].id, normalId);
  assert.equal(fixture.writes.length, 1);
  assert.equal(fixture.writes[0][1].$set.shortsFilterVersion, 3);
  assert.equal('cachedAt' in fixture.writes[0][1].$set, false);
});

test('YouTube duration metadata is parsed without imposing a minimum song duration', async () => {
  const { parseYouTubeDuration } = await loadModule('src/lib/youtube-shorts.js');
  assert.equal(parseYouTubeDuration('PT19S'), 19);
  assert.equal(parseYouTubeDuration('PT2M30S'), 150);
  assert.equal(parseYouTubeDuration('PT45M'), 2700);
  assert.equal(parseYouTubeDuration('P1DT2H3M4S'), 93784);
  assert.equal(parseYouTubeDuration('PT1.5S'), 1.5);
  for (const value of [undefined, 'P', 'PT', 'invalid', 'PT-1S']) assert.equal(parseYouTubeDuration(value), null);
});
