import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';
import { Suspense } from 'react';
import { findAll, settle } from './ui-harness.mjs';

const components = Object.fromEntries(['DualViewSection', 'GenreExplorer', 'HomeEmptyState', 'HomeHeader', 'PaginationControls', 'RankingSection', 'SongCard'].map(name => [`@/components/${name}`, { default: () => null, ...(name === 'DualViewSection' ? { SongRowSection: () => null } : {}) }]));

async function homeFixture(parameters) {
  const requests = [];
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

test('category navigation renders its header and independent feed boundaries before providers finish', async () => {
  const pending = [];
  const { default: Home } = await loadModule('src/app/page.js', {
    ...components,
    '@/lib/youtube': { getYouTubeSongs: () => new Promise(resolve => pending.push(resolve)) },
  });
  let tree;
  const rendered = Home({ searchParams: Promise.resolve({ genre: 'tiktok remix' }) }).then(value => { tree = value; });
  await settle();
  const immediate = Boolean(tree);
  // Always finish the promises so a failing reproduction leaves no pending work.
  const result = { items: [{ id: 'test', title: 'Original test song' }], nextPageToken: 'next' };
  if (!immediate) { pending.forEach(resolve => resolve(result)); await rendered; }
  assert.equal(immediate, true, 'a slow YouTube request must not hold the whole category page');
  assert.equal(pending.length, 3);
  const boundaries = findAll(tree, node => node.type === Suspense);
  assert.equal(boundaries.length, 4, 'ranking, two rows and pagination resolve independently');
  const mostViewed = boundaries.find(node => node.props.children.props.kind === 'mostViewed');
  pending[0](result);
  const row = await mostViewed.props.children.type(mostViewed.props.children.props);
  assert.equal(row.props.songs[0].id, 'test');
  assert.equal(row.props.genreKey, 'tiktokRemix');
  pending[1](result); pending[2](result);
  await rendered;
});

test('genre pagination keeps its token scoped to most-viewed and does not fetch the first-page ranking again', async () => {
  const requests = await homeFixture({ genre: ['kpop hit'], token: ['next-page'] });
  assert.equal(requests.length, 2);
  assert.equal(requests[0].token, 'next-page');
  assert.equal(requests[1].token, '');
  assert.ok(requests.every(request => request.query === 'kpop hit'));
});
