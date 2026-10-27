import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';
import { createHookHarness, find, textContent } from './ui-harness.mjs';

async function fixture(currentSong, document) {
  const harness = createHookHarness();
  const browser = new EventTarget();
  const close = [];
  const { default: Panel } = await loadModule('src/components/NowPlayingPanel.js', {
    react: harness.react,
    '@/lib/store': {
      useMusicStore: () => ({ currentSong, nowPlayingOpen: Boolean(currentSong), favorites: [], playlist: [], repeatMode: 'off', setNowPlayingOpen: value => close.push(value) }),
      useSettingsStore: selector => selector({ language: 'en', volume: 80 }),
    },
    'next-auth/react': { useSession: () => ({ data: null }) },
    'next/image': { default: () => null },
  }, { window: browser, CustomEvent, ...(document ? { document } : {}) });
  return { harness, browser, close, Panel };
}

test('Now Playing safely renders nothing before any song is selected, including SSR', async () => {
  const { harness, Panel } = await fixture(null);
  assert.equal(harness.render(Panel), null);
});

test('keyboard progress changes seek through the media controller and closing keeps playback running', async () => {
  const { harness, browser, Panel, close } = await fixture({ id: 'track', title: 'Test recording', artist: 'Test artist' });
  harness.render(Panel); harness.flushEffects();
  browser.dispatchEvent(new CustomEvent('bcmusic:timeupdate', { detail: { songId: 'track', currentTime: 0, duration: 180 } }));
  const tree = harness.render(Panel);
  const seeks = [];
  const playbackCommands = [];
  browser.addEventListener('bcmusic:seekto', event => seeks.push(event.detail.time));
  browser.addEventListener('bcmusic:toggleplay', () => playbackCommands.push('toggle'));
  find(tree, node => node.type === 'input' && node.props['aria-label'] === 'Playback position').props.onChange({ target: { value: '42' } });
  assert.deepEqual(seeks, [42]);
  find(tree, node => node.type === 'dialog').props.onCancel({ preventDefault() {} });
  assert.deepEqual(close, [false]);
  assert.deepEqual(playbackCommands, []);
  harness.unmount();
});

test('closing the immersive player restores the previous keyboard focus and body scrolling', async () => {
  let focused = 0;
  const document = { body: { style: { overflow: 'auto' } }, activeElement: { isConnected: true, focus() { focused++; } } };
  const { harness, Panel } = await fixture({ id: 'track', title: 'Test', artist: 'Artist' }, document);
  const tree = harness.render(Panel);
  const element = { open: false, showModal() { this.open = true; }, close() { this.open = false; } };
  find(tree, node => node.type === 'dialog').props.ref.current = element;
  harness.flushEffects();
  assert.equal(element.open, true);
  assert.equal(document.body.style.overflow, 'hidden');
  harness.unmount();
  assert.equal(element.open, false);
  assert.equal(document.body.style.overflow, 'auto');
  assert.equal(focused, 1);
});

test('the full player explains an unavailable YouTube recording without showing an old track error', async () => {
  const { harness, browser, Panel } = await fixture({ id: 'track', title: 'Test', artist: 'Artist' });
  harness.render(Panel); harness.flushEffects();
  browser.dispatchEvent(new CustomEvent('bcmusic:playerror', { detail: { songId: 'track', code: 150 } }));
  assert.ok(textContent(harness.render(Panel)).includes('YouTube cannot play this recording'));
  browser.dispatchEvent(new CustomEvent('bcmusic:playerror', { detail: { songId: 'another-track', code: 150 } }));
  assert.equal(textContent(harness.render(Panel)).includes('YouTube cannot play this recording'), false);
  harness.unmount();
});
