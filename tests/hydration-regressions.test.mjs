import assert from 'node:assert/strict';
import test from 'node:test';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { loadModule } from './helpers.mjs';
import { createHookHarness } from './ui-harness.mjs';

function mockStore(initialLanguage = 'en') {
  return {
    useSettingsStore: (selector) => {
      const state = { language: initialLanguage, searchHistory: [] };
      return selector ? selector(state) : state;
    },
  };
}

test('HomeHeader produces stable SSR markup and matches initial client hydration when stored language is English', async () => {
  const harness = createHookHarness();
  const store = mockStore('en');

  const { default: HomeHeader } = await loadModule('src/components/HomeHeader.js', {
    react: harness.react,
    '@/lib/store': store,
    'next/image': { default: () => null },
    'next/link': { default: ({ children, ...props }) => createElement('a', props, children) },
    '@/components/CategoryScroller': { default: () => null },
    '@/components/SettingsPanel': { default: () => null },
    '@/components/AuthModal': { default: () => null },
    '@/components/MusicScene': { default: () => null },
  });

  const categories = [{ key: 'tiktokRemix', query: 'tiktok remix' }];
  const props = { categories, currentQuery: 'tiktok remix', currentSearch: '' };

  // Server render to static HTML
  const ssrMarkup = renderToStaticMarkup(createElement(HomeHeader, props));
  assert.ok(ssrMarkup.includes('Chào buổi sáng'), 'SSR markup must use stable default greeting');

  // Client first render (before effects flush)
  const clientTree = harness.render(HomeHeader, props);
  // Verify that during first render, greeting is stable 'Chào buổi sáng'
  // Find greeting in clientTree
  const findGreeting = (node) => {
    if (!node || typeof node !== 'object') return null;
    if (node.props?.className === 'home-header-greeting') return node.props.children;
    if (Array.isArray(node.props?.children)) {
      for (const child of node.props.children) {
        const found = findGreeting(child);
        if (found) return found;
      }
    }
    return findGreeting(node.props?.children);
  };

  assert.equal(findGreeting(clientTree), 'Chào buổi sáng', 'Client first render must match SSR greeting');

  // Flush effects (mount)
  harness.flushEffects();
  const mountedTree = harness.render(HomeHeader, props);
  const mountedGreeting = findGreeting(mountedTree);
  assert.ok(
    mountedGreeting.startsWith('Good '),
    `After mount, greeting should reflect English stored language; got: ${mountedGreeting}`
  );
  harness.unmount();
});

test('RankingSection and SongRowSection omit data-motion-section in Suspense fallback (isLoading: true)', async () => {
  const harness = createHookHarness();
  const store = mockStore('vi');

  const { default: RankingSection } = await loadModule('src/components/RankingSection.js', {
    react: harness.react,
    '@/lib/store': store,
    '@/components/SongCarousel': { default: ({ children }) => createElement('div', null, children) },
    '@/components/DiscoverySongCard': { default: () => null },
    '@/components/MusicRowSkeleton': { default: () => createElement('div', { className: 'skeleton' }) },
  });

  const { SongRowSection } = await loadModule('src/components/DualViewSection.js', {
    react: harness.react,
    '@/lib/store': store,
    '@/components/SongCarousel': { default: ({ children }) => createElement('div', null, children) },
    '@/components/DiscoverySongCard': { default: () => null },
    '@/components/MusicRowSkeleton': { default: () => createElement('div', { className: 'skeleton' }) },
  });

  // Suspense fallback with isLoading: true
  const rankingFallback = harness.render(RankingSection, { songs: [], genreKey: 'tiktokRemix', isLoading: true });
  assert.equal(
    rankingFallback.props['data-motion-section'],
    undefined,
    'RankingSection loading skeleton must not have data-motion-section'
  );

  const rowFallback = harness.render(SongRowSection, { songs: [], genreKey: 'tiktokRemix', kind: 'mostViewed', isLoading: true });
  assert.equal(
    rowFallback.props['data-motion-section'],
    undefined,
    'SongRowSection loading skeleton must not have data-motion-section'
  );

  // Mount components by flushing effects
  harness.flushEffects();

  // Loaded content with isLoading: false after mount
  const songs = [{ id: '1', title: 'Song 1' }];
  const rankingLoaded = harness.render(RankingSection, { songs, genreKey: 'tiktokRemix', isLoading: false });
  assert.notEqual(
    rankingLoaded.props['data-motion-section'],
    undefined,
    'RankingSection loaded content after mount must have data-motion-section'
  );

  const rowLoaded = harness.render(SongRowSection, { songs, genreKey: 'tiktokRemix', kind: 'mostViewed', isLoading: false });
  assert.notEqual(
    rowLoaded.props['data-motion-section'],
    undefined,
    'SongRowSection loaded content after mount must have data-motion-section'
  );

  harness.unmount();
});

test('RankingSection and SongRowSection render friendly error state when unavailable is true', async () => {
  const harness = createHookHarness();
  const store = mockStore('vi');

  const { default: RankingSection } = await loadModule('src/components/RankingSection.js', {
    react: harness.react,
    '@/lib/store': store,
    '@/components/SongCarousel': { default: ({ children }) => createElement('div', null, children) },
    '@/components/DiscoverySongCard': { default: () => null },
    '@/components/MusicRowSkeleton': { default: () => null },
  });

  const tree = harness.render(RankingSection, { songs: [], genreKey: 'tiktokRemix', isLoading: false, unavailable: true });
  const markup = renderToStaticMarkup(tree);
  assert.ok(
    markup.includes('Tạm thời không kết nối được nguồn nhạc'),
    'Should display unavailable message when unavailable is true'
  );

  harness.unmount();
});

test('GenreExplorer omits data-motion-section on initial render and attaches it after mount', async () => {
  const harness = createHookHarness();
  const { default: GenreExplorer } = await loadModule('src/components/GenreExplorer.js', {
    react: harness.react,
    'next/image': { default: () => null },
    '@/lib/store': { useMusicStore: () => ({}) },
  });

  // Initial client render before effects flush (SSR / first client hydration pass)
  const initialTree = harness.render(GenreExplorer);
  const findSection = (node) => {
    if (!node || typeof node !== 'object') return null;
    if (node.type === 'section') return node;
    if (Array.isArray(node.props?.children)) {
      for (const child of node.props.children) {
        const found = findSection(child);
        if (found) return found;
      }
    }
    return findSection(node.props?.children);
  };

  const initialSection = findSection(initialTree);
  assert.ok(initialSection, 'GenreExplorer must render a section element');
  assert.equal(
    initialSection.props['data-motion-section'],
    undefined,
    'GenreExplorer initial render must omit data-motion-section to prevent GSAP hydration mismatch'
  );

  // Mount (flush effects)
  harness.flushEffects();
  const mountedTree = harness.render(GenreExplorer);
  const mountedSection = findSection(mountedTree);
  assert.notEqual(
    mountedSection.props['data-motion-section'],
    undefined,
    'GenreExplorer must attach data-motion-section after mount for smooth page motion'
  );

  harness.unmount();
});
