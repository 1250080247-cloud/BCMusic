import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';
import { createHookHarness, deferredFetch, find, findAll, settle, textContent } from './ui-harness.mjs';

const listA = [{ id: 'A1', title: 'Song A1' }, { id: 'A2', title: 'Song A2' }];
const listB = [{ id: 'B1', title: 'Song B1' }, { id: 'B2', title: 'Song B2' }];

async function stores() {
  const loadedModule = await loadModule('src/lib/store.js', {
    'zustand/middleware': { persist: initializer => initializer },
  });
  const bind = bound => Object.assign(selector => selector ? selector(bound.getState()) : bound.getState(), {
    getState: bound.getState, setState: bound.setState,
  });
  loadedModule.useSettingsStore.setState({ language: 'en' });
  return {
    state: loadedModule.useMusicStore,
    hooks: { useMusicStore: bind(loadedModule.useMusicStore), useSettingsStore: bind(loadedModule.useSettingsStore), useUserStore: bind(loadedModule.useUserStore) },
  };
}

test('previewing a song from another list preserves the queue already playing', async () => {
  const { state, hooks } = await stores();
  state.setState({ currentSong: listA[0], playlist: listA });
  const { default: SongCard } = await loadModule('src/components/SongCard.js', {
    '@/lib/store': hooks,
    'next/image': { default: () => null },
  });
  const tree = SongCard({ song: listB[0], playlist: listB });
  tree.props.onClick();
  assert.equal(state.getState().viewingSong.id, 'B1');
  assert.equal(state.getState().currentSong.id, 'A1');
  assert.deepEqual(Array.from(state.getState().playlist, item => item.id), ['A1', 'A2']);
});

test('Play now in a preview starts that preview list even if another queue was playing', async () => {
  const { state, hooks } = await stores();
  state.setState({ currentSong: listA[0], playlist: listA });
  const { default: SongCard } = await loadModule('src/components/SongCard.js', { '@/lib/store': hooks, 'next/image': { default: () => null } });
  SongCard({ song: listB[0], playlist: listB }).props.onClick();
  // Preview context must survive independently of the currently active queue.
  state.setState({ playlist: listA });
  const harness = createHookHarness();
  const { default: SongModal } = await loadModule('src/components/SongModal.js', {
    react: harness.react,
    '@/lib/store': hooks,
    'next-auth/react': { useSession: () => ({ data: null }) },
    'next/image': { default: () => null },
  });
  const tree = harness.render(SongModal);
  harness.flushEffects();
  const play = find(tree, node => node.type === 'button' && textContent(node).includes('Play now'));
  assert.ok(play);
  play.props.onClick();
  assert.equal(state.getState().currentSong.id, 'B1');
  assert.deepEqual(Array.from(state.getState().playlist, item => item.id), ['B1', 'B2']);
  harness.unmount();
});

async function playerFixture(source = 'youtube', repeatMode = 'off') {
  const { state, hooks } = await stores();
  const song = source === 'soundcloud'
    ? { id: 'sc_12345', title: 'SC song', source, embedUrl: 'https://w.soundcloud.com/player/?url=example' }
    : listA[0];
  state.setState({ currentSong: song, playlist: [song], repeatMode });
  const harness = createHookHarness();
  const calls = { pause: 0, play: 0, seeks: [] };
  const events = {};
  const widget = {
    bind: (event, handler) => { events[event] = handler; },
    unbind: event => { delete events[event]; },
    setVolume() {}, getDuration(callback) { callback(180000); },
    play() { calls.play++; }, pause() { calls.pause++; }, seekTo(time) { calls.seeks.push(time); },
  };
  const Widget = () => widget;
  Widget.Events = { READY: 'ready', PLAY: 'play', PAUSE: 'pause', FINISH: 'finish', PLAY_PROGRESS: 'progress' };
  const browser = new EventTarget();
  browser.SC = { Widget };
  const YouTube = () => null;
  const { default: Player } = await loadModule('src/components/Player.js', {
    react: harness.react, '@/lib/store': hooks,
    'next-auth/react': { useSession: () => ({ data: null }) },
    'next/image': { default: () => null }, 'react-youtube': { default: YouTube },
  }, {
    window: browser,
    CustomEvent,
    fetch: async () => ({ ok: true, json: async () => ({ success: true }) }),
    setInterval: () => 1, clearInterval() {},
  });
  let tree = harness.render(Player);
  const iframe = find(tree, node => node.type === 'iframe');
  if (iframe) iframe.props.ref.current = {};
  harness.flushEffects();
  const yt = find(tree, node => node.type === YouTube);
  if (yt) {
    yt.props.onReady({ target: {
      setVolume() {}, setPlaybackRate() {},
      pauseVideo() { calls.pause++; }, playVideo() { calls.play++; }, seekTo(time) { calls.seeks.push(time); },
    } });
    yt.props.onStateChange({ data: 1 });
  } else {
    events.ready?.();
    events.play?.();
  }
  tree = harness.render(Player);
  harness.flushEffects();
  calls.pause = 0; calls.play = 0; calls.seeks.length = 0;
  const render = () => { const output = harness.render(Player); harness.flushEffects(); return output; };
  return { tree, calls, harness, yt: find(tree, node => node.type === YouTube), events, browser, hooks, state, render };
}

test('persistent player answers playback-state requests and removes its listener on unmount', async () => {
  const { browser, harness, yt, render } = await playerFixture();
  const snapshots = [];
  browser.addEventListener('bcmusic:playstate', event => snapshots.push(event.detail));
  browser.dispatchEvent(new Event('bcmusic:requestplaystate'));
  assert.equal(snapshots.at(-1).songId, 'A1');
  assert.equal(snapshots.at(-1).isPlaying, true);
  yt.props.onStateChange({ data: 2 });
  render();
  browser.dispatchEvent(new Event('bcmusic:requestplaystate'));
  assert.equal(snapshots.at(-1).isPlaying, false);
  const count = snapshots.length;
  harness.unmount();
  browser.dispatchEvent(new Event('bcmusic:requestplaystate'));
  assert.equal(snapshots.length, count);
});

for (const source of ['youtube', 'soundcloud']) {
  test(`Next on the last ${source} track pauses the underlying media`, async () => {
    const { tree, calls, harness } = await playerFixture(source);
    try {
      const next = find(tree, node => node.type === 'button' && node.props['aria-label'] === 'Next song');
      assert.ok(next);
      next.props.onClick();
      assert.equal(calls.pause, 1);
    } finally { harness.unmount(); }
  });
}

test('Repeat All restarts a singleton YouTube queue when playback ends', async () => {
  const { yt, calls, harness } = await playerFixture('youtube', 'all');
  try {
    yt.props.onStateChange({ data: 0 });
    assert.deepEqual(calls.seeks, [0]);
    assert.equal(calls.play, 1);
  } finally { harness.unmount(); }
});

test('Repeat All restarts a singleton SoundCloud queue when playback ends', async () => {
  const { calls, events, harness } = await playerFixture('soundcloud', 'all');
  try {
    events.finish();
    assert.deepEqual(calls.seeks, [0]);
    assert.equal(calls.play, 1);
  } finally { harness.unmount(); }
});

test('Now Playing next and previous buttons use the Player media controller', async () => {
  const player = await playerFixture();
  player.state.setState({ nowPlayingOpen: true });
  const panelHarness = createHookHarness();
  const { default: Panel } = await loadModule('src/components/NowPlayingPanel.js', {
    react: panelHarness.react,
    '@/lib/store': player.hooks,
    'next-auth/react': { useSession: () => ({ data: null }) },
    'next/image': { default: () => null },
  }, { window: player.browser, CustomEvent });
  try {
    const tree = panelHarness.render(Panel);
    panelHarness.flushEffects();
    find(tree, node => node.type === 'button' && node.props['aria-label'] === 'Next song').props.onClick();
    assert.equal(player.calls.pause, 1, 'last-track Next must pause the actual media through Player');
    find(tree, node => node.type === 'button' && node.props['aria-label'] === 'Previous song').props.onClick();
    assert.deepEqual(player.calls.seeks, [0]);
    assert.equal(player.calls.play, 1);
  } finally { panelHarness.unmount(); player.harness.unmount(); }
});

test('mini-player lyrics opens the immersive player without changing the current queue', async () => {
  const player = await playerFixture();
  try {
    const before = player.state.getState();
    find(player.tree, node => node.type === 'button' && node.props['aria-label'] === 'Open lyrics').props.onClick();
    const after = player.state.getState();
    assert.equal(after.nowPlayingOpen, true);
    assert.equal(after.currentSong.id, before.currentSong.id);
    assert.deepEqual(after.playlist, before.playlist);
  } finally { player.harness.unmount(); }
});

test('YouTube playback errors pause the UI and report the failed recording to the full player', async () => {
  const player = await playerFixture();
  const errors = [];
  player.browser.addEventListener('bcmusic:playerror', event => errors.push(event.detail));
  try {
    const youtube = find(player.tree, node => node.props?.videoId === 'A1');
    youtube.props.onStateChange({ data: 1 });
    player.render();
    youtube.props.onError({ data: 150 });
    const updated = player.render();
    assert.equal(errors[0].songId, 'A1');
    assert.equal(errors[0].code, 150);
    assert.ok(find(updated, node => node.type === 'button' && node.props['aria-label'] === 'Play'));
  } finally { player.harness.unmount(); }
});

test('changing tracks never broadcasts the previous track time as the new track progress', async () => {
  const player = await playerFixture();
  const updates = [];
  player.browser.addEventListener('bcmusic:timeupdate', event => updates.push(event.detail));
  try {
    const progress = find(player.tree, node => node.type === 'input' && node.props.type === 'range' && node.props.min === 0);
    progress.props.onChange({ target: { value: '45' } });
    player.render();
    assert.ok(updates.some(update => update.songId === 'A1' && update.currentTime === 45));
    player.state.setState({ currentSong: listB[0], playlist: listB });
    player.render();
    assert.ok(updates.filter(update => update.songId === 'B1').every(update => update.currentTime === 0));
  } finally { player.harness.unmount(); }
});

async function searchFixture() {
  const harness = createHookHarness();
  const deferred = deferredFetch();
  let params = new URLSearchParams('q=old');
  const router = { push(url) { params = new URL(url, 'http://localhost').searchParams; } };
  const history = [];
  const settings = {
    language: 'en', searchHistory: [], addSearchHistory: term => history.push(term), removeSearchHistory() {}, clearSearchHistory() {},
  };
  const SongCard = () => null;
  const { default: SearchView } = await loadModule('src/components/SearchView.js', {
    react: harness.react,
    'next/navigation': { useRouter: () => router, useSearchParams: () => params },
    '@/lib/store': { useSettingsStore: selector => selector(settings) },
    '@/components/SongCard': { default: SongCard },
  }, { fetch: deferred.fetch });
  const content = find(SearchView(), node => typeof node.type === 'function' && node.type.name === 'SearchContent');
  assert.ok(content);
  const render = () => {
    const tree = harness.render(content.type);
    harness.flushEffects();
    return tree;
  };
  return {
    ...deferred, harness, render, history,
    navigate(query) { router.push(query ? `/search?q=${query}` : '/search'); return render(); },
    visibleSongs(tree) { return findAll(tree, node => node.type === SongCard).map(node => node.props.song.id); },
  };
}

test('search results keep the latest query when an earlier response arrives later', async () => {
  const fixture = await searchFixture();
  try {
    fixture.render();
    fixture.navigate('new');
    fixture.requests.find(item => item.query.get('q') === 'new').resolve({ items: [{ id: 'new', title: 'New' }] });
    await settle();
    fixture.requests.find(item => item.query.get('q') === 'old').resolve({ items: [{ id: 'old', title: 'Old' }] });
    await settle();
    assert.deepEqual(fixture.visibleSongs(fixture.render()), ['new']);
  } finally { fixture.harness.unmount(); }
});

test('clearing search prevents an outstanding response from restoring results', async () => {
  const fixture = await searchFixture();
  try {
    fixture.render();
    fixture.navigate('');
    fixture.requests[0].resolve({ items: [{ id: 'old', title: 'Old' }] });
    await settle();
    assert.deepEqual(fixture.visibleSongs(fixture.render()), []);
    assert.equal(fixture.history.includes('old'), false);
  } finally { fixture.harness.unmount(); }
});

test('returning to a query after clearing restores that query in the search input', async () => {
  const fixture = await searchFixture();
  try {
    const tree = fixture.render();
    const clear = find(tree, node => node.type === 'button' && node.props.type === 'button');
    assert.ok(clear);
    clear.props.onClick();
    fixture.render();
    const returned = fixture.navigate('old');
    const input = find(returned, node => node.type === 'input' && node.props.type === 'text');
    assert.equal(input.props.value, 'old');
  } finally { fixture.harness.unmount(); }
});

async function genreFixture() {
  const harness = createHookHarness();
  const deferred = deferredFetch();
  const { default: GenreExplorer } = await loadModule('src/components/GenreExplorer.js', {
    react: harness.react, 'next/image': { default: () => null },
    '@/lib/store': { useMusicStore: () => ({}) },
  }, { fetch: deferred.fetch });
  const render = () => { const tree = harness.render(GenreExplorer); harness.flushEffects(); return tree; };
  const pill = (tree, key) => find(tree, node => node.props?.item?.key === key);
  const results = tree => find(tree, node => typeof node.type === 'function' && node.type.name === 'ExploreResults').props;
  const resolveQuery = (query, id) => deferred.requests.filter(item => item.query.get('q') === query).forEach(item => item.resolve({ items: [{ id, title: id }] }));
  return { harness, render, pill, results, resolveQuery };
}

test('changing genre keeps the latest results when the previous genre finishes later', async () => {
  const fixture = await genreFixture();
  try {
    const first = fixture.pill(fixture.render(), 'chill');
    const older = first.props.onClick(first.props.item);
    const second = fixture.pill(fixture.render(), 'party');
    const newer = second.props.onClick(second.props.item);
    fixture.resolveQuery(second.props.item.query, 'party-result');
    await newer; await settle();
    fixture.resolveQuery(first.props.item.query, 'chill-result');
    await older; await settle();
    const results = fixture.results(fixture.render());
    assert.equal(results.selected.key, 'party');
    assert.deepEqual(Array.from(results.songs, item => item.id), ['party-result']);
    assert.deepEqual(Array.from(results.newestSongs, item => item.id), ['party-result']);
  } finally { fixture.harness.unmount(); }
});

test('deselecting a genre prevents its pending results from returning', async () => {
  const fixture = await genreFixture();
  try {
    const selected = fixture.pill(fixture.render(), 'chill');
    const pending = selected.props.onClick(selected.props.item);
    const same = fixture.pill(fixture.render(), 'chill');
    await same.props.onClick(same.props.item);
    fixture.resolveQuery(selected.props.item.query, 'stale');
    await pending; await settle();
    const results = fixture.results(fixture.render());
    assert.equal(results.selected, null);
    assert.equal(results.songs.length, 0);
    assert.equal(results.newestSongs.length, 0);
  } finally { fixture.harness.unmount(); }
});
