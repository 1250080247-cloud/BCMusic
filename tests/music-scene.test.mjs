import test from 'node:test';
import assert from 'node:assert/strict';
import { loadModule } from './helpers.mjs';
import { createHookHarness, find, findAll } from './ui-harness.mjs';

test('3D scene requests the current playback state on mount and ignores other songs', async () => {
  const harness = createHookHarness();
  const events = new EventTarget();
  let requests = 0;
  const emit = (songId, isPlaying) => events.dispatchEvent(new CustomEvent('bcmusic:playstate', { detail: { songId, isPlaying } }));
  events.addEventListener('bcmusic:requestplaystate', () => { requests++; emit('first', true); });
  const { default: usePlaybackState } = await loadModule('src/components/usePlaybackState.js', {
    stubs: { react: harness.react }, globals: { window: events, Event, CustomEvent },
  });
  const render = id => harness.render(() => usePlaybackState(id));
  assert.equal(render('first'), false);
  harness.flushEffects();
  assert.equal(requests, 1);
  assert.equal(render('first'), true);
  emit('first', false);
  assert.equal(render('first'), false);
  emit('old', true);
  assert.equal(render('first'), false);
  emit('first', true);
  assert.equal(render('second'), false);
  harness.flushEffects();
  emit('second', true);
  assert.equal(render('second'), true);
  emit('second', false);
  assert.equal(render('second'), false);
  harness.unmount();
  emit('second', true);
  assert.equal(render('second'), false, 'unmounted listeners must be removed');
});

test('3D motion pauses offscreen, when hidden, or disabled; observers and tilt listeners clean up', async () => {
  const harness = createHookHarness();
  const doc = Object.assign(new EventTarget(), { hidden: false });
  const root = { dataset: {} };
  const surface = new EventTarget();
  let observe;
  let disconnected = 0;
  let reverted = 0;
  let tiltCalls = 0;
  const media = { add(query, setup) { assert.match(query, /prefers-reduced-motion: no-preference/); this.cleanup = setup(); }, revert() { reverted++; this.cleanup?.(); } };
  const { default: Scene } = await loadModule('src/components/MusicScene.js', {
    stubs: {
      react: harness.react,
      './music-scene.css': {},
      './usePlaybackState': { default: () => true },
      '@/lib/store': { useMusicStore: selector => selector({ currentSong: { id: 'song', title: 'Test', thumbnail: '/cover.jpg' }, setNowPlayingOpen() {} }), useSettingsStore: selector => selector({ language: 'vi' }) },
      'next/image': { default: () => null },
      gsap: { registerPlugin() {}, matchMedia: () => media, quickTo: () => () => tiltCalls++, set() {} },
      '@gsap/react': { useGSAP: (fn, config) => harness.react.useEffect(fn, config.dependencies) },
    },
    globals: { window: {}, document: doc, IntersectionObserver: class { constructor(callback) { observe = callback; } observe() {} disconnect() { disconnected++; } } },
  });
  function render() {
    const tree = harness.render(Scene);
    const refs = findAll(tree, node => node.props?.ref);
    refs[0].props.ref.current = root;
    refs[1].props.ref.current = surface;
    refs[2].props.ref.current = {};
    harness.flushEffects();
    return tree;
  }
  let tree = render();
  observe([{ isIntersecting: true }]);
  assert.equal(root.dataset.active, 'true');
  doc.hidden = true; doc.dispatchEvent(new Event('visibilitychange'));
  assert.equal(root.dataset.active, 'false');
  doc.hidden = false; doc.dispatchEvent(new Event('visibilitychange'));
  assert.equal(root.dataset.active, 'true');
  observe([{ isIntersecting: false }]);
  assert.equal(root.dataset.active, 'false');
  surface.dispatchEvent(new Event('pointerleave'));
  assert.equal(tiltCalls, 2);
  find(tree, node => node.props?.['aria-label'] === 'Chuyển động 3D').props.onClick();
  tree = render();
  assert.equal(find(tree, node => node.props?.['aria-label'] === 'Chuyển động 3D').props['aria-pressed'], false);
  observe([{ isIntersecting: true }]);
  assert.equal(root.dataset.active, 'false');
  surface.dispatchEvent(new Event('pointerleave'));
  assert.equal(tiltCalls, 2, 'disabled motion must remove pointer listeners');
  assert.equal(reverted, 1);
  harness.unmount();
  assert.equal(disconnected, 2);
});
