import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';
import { createHookHarness, deferredFetch, findAll, textContent, settle } from './ui-harness.mjs';

test('lyrics cancel the previous recording request and only show the current recording response', async () => {
  const harness = createHookHarness();
  const deferred = deferredFetch();
  const { default: Panel } = await loadModule('src/components/LyricsPanel.js', { react: harness.react }, {
    fetch: deferred.fetch, window: { matchMedia: () => ({ matches: false }) },
  });
  let props = { song: { id: 'A', title: 'Song A', artist: 'Artist' }, duration: 180, currentTime: 0, language: 'en' };
  harness.render(Panel, props); harness.flushEffects();
  props = { ...props, song: { id: 'B', title: 'Song B', artist: 'Artist' } };
  harness.render(Panel, props); harness.flushEffects();
  deferred.requests[0].resolve({ status: 'plain', plainLyrics: 'Old recording', lines: [] });
  deferred.requests[1].resolve({ status: 'synced', plainLyrics: 'Current recording', lines: [{ time: 1, text: 'Current recording' }] });
  await settle();
  const tree = harness.render(Panel, props);
  assert.ok(textContent(tree).includes('Current recording'));
  assert.equal(textContent(tree).includes('Old recording'), false);
  harness.unmount();
});

test('timed lyric lines follow actual timestamps and seek through the existing player event', async () => {
  const harness = createHookHarness();
  const deferred = deferredFetch();
  const events = [];
  const { default: Panel } = await loadModule('src/components/LyricsPanel.js', { react: harness.react }, {
    fetch: deferred.fetch,
    window: { matchMedia: () => ({ matches: true }), dispatchEvent: event => events.push(event) },
    CustomEvent,
  });
  const props = { song: { id: 'A', title: 'Song', artist: 'Artist' }, duration: 180, currentTime: 3, language: 'en' };
  harness.render(Panel, props); harness.flushEffects();
  deferred.requests[0].resolve({ status: 'synced', plainLyrics: 'First\nSecond', lines: [{ time: 1, text: 'First' }, { time: 4, text: 'Second' }] });
  await settle();
  const tree = harness.render(Panel, props);
  const lines = findAll(tree, node => node.type === 'button' && node.props.className?.includes('focus-lyric-line'));
  assert.equal(lines[0].props['aria-current'], 'true');
  assert.equal(lines[1].props['aria-current'], undefined);
  lines[1].props.onClick();
  assert.equal(events[0].type, 'bcmusic:seekto');
  assert.equal(events[0].detail.time, 4);
  harness.unmount();
});
