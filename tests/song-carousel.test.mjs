import test from 'node:test';
import assert from 'node:assert/strict';
import { loadModule } from './helpers.mjs';
import { createHookHarness, find, findAll } from './ui-harness.mjs';

async function fixture() {
  const harness = createHookHarness();
  const element = Object.assign(new EventTarget(), { scrollLeft: 0, scrollWidth: 1400, clientWidth: 600, dataset: {}, captured: null,
    setPointerCapture(id) { this.captured = id; }, hasPointerCapture(id) { return this.captured === id; }, releasePointerCapture() { this.captured = null; },
    scrollBy({ left, behavior }) { this.scrollLeft += left; this.behavior = behavior; }, scrollTo({ left }) { this.scrollLeft = left; },
  });
  let disconnected = false;
  const { default: Carousel } = await loadModule('src/components/SongCarousel.js', {
    stubs: { react: { ...harness.react, useId: () => 'test-carousel' }, '@/components/MotionList': { default: () => null } },
    globals: { window: { matchMedia: () => ({ matches: true }) }, ResizeObserver: class { observe() {} disconnect() { disconnected = true; } } },
  });
  const render = () => {
    const tree = harness.render(Carousel, { title: 'Top Thịnh Hành', language: 'vi', children: 'Songs' });
    find(tree, node => node.props?.ref).props.ref.current = element;
    harness.flushEffects();
    return tree;
  };
  render();
  const viewport = () => find(render(), node => node.props?.onPointerDown);
  const pointer = (extra = {}) => ({ currentTarget: element, pointerId: 1, pointerType: 'mouse', button: 0, clientX: 400, clientY: 20, ...extra });
  return { harness, element, render, viewport, pointer, get disconnected() { return disconnected; } };
}

test('dragging the song row scrolls both directions and suppresses the resulting click', async () => {
  const f = await fixture();
  const handlers = f.viewport().props;
  handlers.onPointerDown(f.pointer());
  handlers.onPointerMove(f.pointer({ clientX: 220 }));
  assert.equal(f.element.scrollLeft, 180);
  assert.equal(f.element.dataset.dragging, 'true');
  handlers.onPointerMove(f.pointer({ clientX: 300 }));
  assert.equal(f.element.scrollLeft, 100);
  handlers.onPointerUp(f.pointer());
  assert.equal(f.element.dataset.dragging, 'false');
  let prevented = false;
  handlers.onClickCapture({ preventDefault() { prevented = true; }, stopPropagation() {} });
  assert.equal(prevented, true);
  prevented = false;
  handlers.onClickCapture({ detail: 0, preventDefault() { prevented = true; }, stopPropagation() {} });
  assert.equal(prevented, false, 'keyboard activation must remain available immediately after dragging');
  handlers.onPointerDown(f.pointer());
  handlers.onPointerUp(f.pointer());
  prevented = false;
  handlers.onClickCapture({ preventDefault() { prevented = true; }, stopPropagation() {} });
  assert.equal(prevented, false, 'a normal click after a drag must still select a song');
  f.harness.unmount();
  assert.equal(f.disconnected, true);
});

test('discovery preview preserves playback and the explicit play button starts the matching queue', async () => {
  const selected = [];
  const playback = [];
  const song = { id: 'song', title: 'Test &amp; song', artist: 'Test artist' };
  const playlist = [song];
  const state = { currentSong: { id: 'already-playing' }, setViewingSong: (...args) => selected.push(args), startPlayback: (...args) => playback.push(args) };
  const { default: Card } = await loadModule('src/components/DiscoverySongCard.js', {
    '@/lib/store': { useMusicStore: selector => selector(state), useSettingsStore: selector => selector({ language: 'vi' }) },
    'next/image': { default: () => null },
  });
  const buttons = findAll(Card({ song, playlist, rank: 1 }), node => node.type === 'button');
  assert.match(buttons[0].props['aria-label'], /Test & song/);
  buttons[0].props.onClick();
  assert.equal(playback.length, 0);
  assert.equal(selected[0][0], song);
  assert.equal(selected[0][1], playlist);
  buttons[1].props.onClick();
  assert.equal(playback[0][0], song);
  assert.equal(playback[0][1], playlist);
});

test('native touch scrolling is preserved and arrow controls work with reduced motion', async () => {
  const f = await fixture();
  const handlers = f.viewport().props;
  handlers.onPointerDown(f.pointer({ pointerType: 'touch' }));
  handlers.onPointerMove(f.pointer({ pointerType: 'touch', clientX: 100 }));
  assert.equal(f.element.scrollLeft, 0);
  const buttons = findAll(f.render(), node => node.type === 'button');
  assert.equal(buttons[0].props.disabled, true);
  assert.equal(buttons[1].props.disabled, false);
  buttons[1].props.onClick();
  assert.ok(f.element.scrollLeft > 0);
  assert.equal(f.element.behavior, 'auto');
  f.element.scrollLeft = 800;
  f.element.dispatchEvent(new Event('scroll'));
  assert.equal(findAll(f.render(), node => node.type === 'button')[1].props.disabled, true);
  f.harness.unmount();
});

test('keyboard scrolling and pointer cancellation leave the carousel usable', async () => {
  const f = await fixture();
  const handlers = f.viewport().props;
  handlers.onKeyDown({ key: 'ArrowRight', target: f.element, currentTarget: f.element, preventDefault() {} });
  assert.ok(f.element.scrollLeft > 0);
  handlers.onKeyDown({ key: 'Home', target: f.element, currentTarget: f.element, preventDefault() {} });
  assert.equal(f.element.scrollLeft, 0);
  handlers.onPointerDown(f.pointer());
  handlers.onPointerMove(f.pointer({ clientX: 200 }));
  handlers.onPointerCancel(f.pointer());
  assert.equal(f.element.captured, null);
  assert.equal(f.element.dataset.dragging, 'false');
  f.harness.unmount();
});
