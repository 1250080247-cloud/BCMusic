import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';
import { createHookHarness, deferredFetch, settle, findAll, textContent } from './ui-harness.mjs';

async function fixture() {
  const harness = createHookHarness();
  const deferred = deferredFetch();
  const timers = new Map();
  let timerId = 0;
  let query = 'bi';
  const selected = [];
  const { default: useSuggestions } = await loadModule('src/components/useSearchSuggestions.js', { react: harness.react }, {
    fetch: deferred.fetch,
    setTimeout: callback => { const id = ++timerId; timers.set(id, callback); return id; },
    clearTimeout: id => timers.delete(id),
  });
  const Component = () => useSuggestions({ query, history: ['Biển đảo và em', 'Tìm em'], language: 'vi', onSelect: term => selected.push(term) });
  const render = () => { const value = harness.render(Component); harness.flushEffects(); return value; };
  return {
    ...deferred, harness, selected, render, timers,
    type(value) { query = value; render().open(); return render(); },
    flushTimers() { const callbacks = [...timers.values()]; timers.clear(); callbacks.forEach(callback => callback()); },
  };
}

test('typing shows matching history immediately and debounces online suggestions', async () => {
  const f = await fixture();
  try {
    const ui = f.type('biển');
    assert.equal(ui.show, true);
    assert.equal(ui.items[0], 'Biển đảo và em');
    assert.equal(f.requests.length, 0);
    f.type('biển đ');
    assert.equal(f.timers.size, 1);
    f.flushTimers();
    assert.equal(f.requests.length, 1);
    assert.equal(f.requests[0].query.get('q'), 'biển đ');
    assert.equal(f.requests[0].query.get('language'), 'vi');
    assert.equal(f.requests[0].query.has('history'), false);
  } finally { f.harness.unmount(); }
});

test('completed suggestions do not trigger repeated requests when the field stays open or is refocused', async () => {
  const f = await fixture();
  try {
    f.type('biển'); f.flushTimers();
    f.requests[0].resolve({ suggestions: ['biển tình'] }); await settle();
    f.render();
    assert.equal(f.timers.size, 0);
    f.render().close(); f.render();
    f.render().open(); f.render();
    assert.equal(f.timers.size, 0);
    assert.equal(f.requests.length, 1);
  } finally { f.harness.unmount(); }
});

test('stale autocomplete responses cannot replace a newer query or reopen a cleared field', async () => {
  const f = await fixture();
  try {
    f.type('biển'); f.flushTimers();
    f.type('tìm'); f.flushTimers();
    f.requests[1].resolve({ suggestions: ['tìm em remix'] }); await settle();
    f.requests[0].resolve({ suggestions: ['biển tình'] }); await settle();
    assert.deepEqual(Array.from(f.render().items), ['Tìm em', 'tìm em remix']);
    assert.equal(f.type('').show, false);
    assert.equal(f.render().items.length, 0);
  } finally { f.harness.unmount(); }
});

test('arrow keys select a suggestion, Enter searches it, Escape closes and IME Enter is preserved', async () => {
  const f = await fixture();
  let prevented = 0;
  const key = (value, extra = {}) => ({ key: value, preventDefault() { prevented++; }, ...extra });
  try {
    let ui = f.type('biển');
    ui.onKeyDown(key('ArrowDown')); ui = f.render();
    assert.equal(ui.activeIndex, 0);
    ui.onKeyDown(key('Enter', { nativeEvent: { isComposing: true } }));
    assert.equal(f.selected.length, 0);
    ui.onKeyDown(key('Enter')); ui = f.render();
    assert.equal(f.selected[0], 'Biển đảo và em');
    assert.equal(ui.show, false);
    ui = f.type('biển');
    ui.onKeyDown(key('Escape'));
    assert.equal(f.render().show, false);
    assert.ok(prevented >= 3);
  } finally { f.harness.unmount(); }
});

test('an online failure retains history suggestions and does not block submitting typed text', async () => {
  const f = await fixture();
  try {
    f.type('biển'); f.flushTimers();
    f.requests[0].resolve({ suggestions: [], unavailable: true }); await settle();
    const ui = f.render();
    assert.equal(ui.unavailable, true);
    assert.equal(ui.items[0], 'Biển đảo và em');
    let prevented = false;
    ui.onKeyDown({ key: 'Enter', preventDefault() { prevented = true; } });
    assert.equal(prevented, false);
    assert.equal(f.selected.length, 0);
  } finally { f.harness.unmount(); }
});

test('suggestion options render untrusted labels as text and selection preserves input focus', async () => {
  const harness = createHookHarness();
  const choices = [];
  const { default: List } = await loadModule('src/components/SearchSuggestionList.js', { react: harness.react });
  const label = '<img src=x onerror=alert(1)> a test song';
  const menu = { show: true, activeIndex: 0, items: [label], select: value => choices.push(value), setActiveIndex() {} };
  const tree = harness.render(List, { menu, listId: 'test-list', copy: { suggestions: 'Suggestions' } });
  const option = findAll(tree, node => node.props?.role === 'option')[0];
  assert.equal(option.props['aria-selected'], true);
  assert.equal(textContent(option), label);
  assert.equal(findAll(tree, node => node.props?.dangerouslySetInnerHTML).length, 0);
  let focusPreserved = false;
  option.props.onPointerDown({ preventDefault() { focusPreserved = true; } });
  option.props.onClick();
  assert.equal(focusPreserved, true);
  assert.equal(choices[0], label);
  harness.unmount();
});
