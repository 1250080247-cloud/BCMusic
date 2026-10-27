import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';

async function homeFixture(parameters) {
  const requests = [];
  const components = Object.fromEntries(['DualViewSection', 'GenreExplorer', 'HomeEmptyState', 'HomeHeader', 'PaginationControls', 'RankingSection', 'SongCard'].map(name => [`@/components/${name}`, { default: () => null }]));
  const { default: Home } = await loadModule('src/app/page.js', {
    ...components,
    '@/lib/youtube': { getYouTubeSongs: async (query, token, order, limit) => {
      requests.push({ query, token, order, limit });
      return { items: [{ id: 'fixture', title: 'Fixture' }], nextPageToken: null, prevPageToken: null };
    } },
  });
  await Home({ searchParams: Promise.resolve(parameters) });
  return requests;
}

for (const genre of ['tiktok remix', 'nhạc trung douyin', 'lofi chill vietnamese']) {
  test(`all three home music sections use the selected genre: ${genre}`, async () => {
    const requests = await homeFixture({ genre });
    assert.equal(requests.length, 3);
    assert.ok(requests.every(request => request.query.includes(genre)));
    assert.equal(requests.some(request => request.query === 'music trending'), false);
    assert.deepEqual(requests.map(request => request.order), ['viewCount', 'date', 'relevance']);
  });
}

test('default and old TikTok category links no longer inject the unrelated NCS query', async () => {
  for (const parameters of [{}, { genre: 'tiktok remix ncs' }]) {
    const requests = await homeFixture(parameters);
    assert.ok(requests.every(request => request.query.startsWith('tiktok remix') && !request.query.includes('ncs')));
  }
});

test('genre pagination keeps its token scoped to most-viewed and does not fetch the first-page ranking again', async () => {
  const requests = await homeFixture({ genre: ['kpop hit'], token: ['next-page'] });
  assert.equal(requests.length, 2);
  assert.equal(requests[0].token, 'next-page');
  assert.equal(requests[1].token, '');
  assert.ok(requests.every(request => request.query === 'kpop hit'));
});
