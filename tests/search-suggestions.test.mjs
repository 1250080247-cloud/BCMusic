import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';

test('suggestions prefer matching local history, fold Vietnamese accents and remove duplicates', async () => {
  const { mergeSearchSuggestions } = await loadModule('src/lib/search-suggestions.js');
  const history = ['Biển đảo và em', 'Tìm em', 'BIỂN TÌNH'];
  const before = JSON.stringify(history);
  const result = mergeSearchSuggestions('bien', history, ['biển tình', 'biển nhớ', 'Biển đảo và em']);
  assert.deepEqual(Array.from(result), ['Biển đảo và em', 'BIỂN TÌNH', 'biển nhớ']);
  assert.equal(JSON.stringify(history), before);
  assert.equal(mergeSearchSuggestions('', history, ['anything']).length, 0);
});

test('suggestion payloads are bounded and only current-query plain strings are accepted', async () => {
  const { parseSearchSuggestions } = await loadModule('src/lib/search-suggestions.js');
  const result = parseSearchSuggestions(['biển', ['biển tình', 'BIỂN TÌNH', {}, null, 'x'.repeat(161), 'biển\u0000', 'biển nhớ', '<b>biển</b>']], 'biển');
  assert.deepEqual(Array.from(result), ['biển tình', 'biển nhớ', '<b>biển</b>']);
  assert.throws(() => parseSearchSuggestions(['old', ['old response']], 'biển'));
  assert.throws(() => parseSearchSuggestions({ suggestions: [] }, 'biển'));
  assert.equal(parseSearchSuggestions(['biển', Array.from({ length: 50 }, (_, i) => `biển ${i}`)], 'biển').length, 8);
});

test('online autocomplete uses a fixed encoded endpoint without calling the video search API', async () => {
  const requests = [];
  const { getSearchSuggestions } = await loadModule('src/lib/youtube-suggestions.js', {}, {
    fetch: async (input, options) => { requests.push({ url: new URL(input), options }); return Response.json(['biển & em', ['biển & em remix']]); },
  });
  const result = await getSearchSuggestions('biển & em', 'vi');
  assert.equal(result[0], 'biển & em remix');
  assert.equal(requests.length, 1);
  assert.equal(requests[0].url.origin, 'https://www.google.com');
  assert.equal(requests[0].url.pathname, '/complete/search');
  assert.equal(requests[0].url.searchParams.get('q'), 'biển & em');
  assert.equal(requests[0].url.searchParams.get('ds'), 'yt');
  assert.equal(requests[0].url.searchParams.has('key'), false);
  assert.equal(requests[0].options.redirect, 'error');
  assert.ok(requests[0].options.signal instanceof AbortSignal);
});

test('autocomplete API validates before upstream calls and handles outages without leaking details', async () => {
  let calls = 0;
  const { GET } = await loadModule('src/app/api/search/suggestions/route.js', {
    '@/lib/youtube-suggestions': { getSearchSuggestions: async () => { calls++; throw new Error('private upstream details'); } },
    'next/server': { NextResponse: { json: (data, options) => Response.json(data, options) } },
  });
  for (const query of ['q=', 'q=a']) assert.equal((await GET(new Request(`http://localhost/api/search/suggestions?${query}`))).status, 200);
  for (const query of [`q=${'x'.repeat(121)}`, 'q=music&language=unknown']) assert.equal((await GET(new Request(`http://localhost/api/search/suggestions?${query}`))).status, 400);
  assert.equal(calls, 0);
  const response = await GET(new Request('http://localhost/api/search/suggestions?q=biển&language=vi'));
  assert.equal(response.status, 200);
  const body = await response.json();
  assert.equal(body.unavailable, true);
  assert.equal(body.suggestions.length, 0);
  assert.equal(JSON.stringify(body).includes('private upstream details'), false);
  assert.match(response.headers.get('cache-control'), /no-store/);
});
