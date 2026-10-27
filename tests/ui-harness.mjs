import * as React from 'react';

function sameDependencies(previous, next) {
  return previous && next && previous.length === next.length
    && previous.every((value, index) => Object.is(value, next[index]));
}

// A deliberately small hook driver: tests invoke real JSX event handlers, and
// effects run after refs have been attached, just as they do during commit.
export function createHookHarness() {
  let cursor = 0;
  const slots = [];
  const pending = new Set();
  const useState = initial => {
    const index = cursor++;
    if (!slots[index]) {
      const slot = { value: typeof initial === 'function' ? initial() : initial };
      slot.set = update => { slot.value = typeof update === 'function' ? update(slot.value) : update; };
      slots[index] = slot;
    }
    return [slots[index].value, slots[index].set];
  };
  const useRef = initial => {
    const index = cursor++;
    if (!slots[index]) slots[index] = { current: initial };
    return slots[index];
  };
  const memoize = (factory, dependencies) => {
    const index = cursor++;
    if (!slots[index] || !sameDependencies(slots[index].dependencies, dependencies)) {
      slots[index] = { value: factory(), dependencies };
    }
    return slots[index].value;
  };
  const useEffect = (effect, dependencies) => {
    const index = cursor++;
    const previous = slots[index];
    if (!previous || !sameDependencies(previous.dependencies, dependencies)) {
      slots[index] = { effect, dependencies, cleanup: previous?.cleanup };
      pending.add(index);
    }
  };
  return {
    react: { ...React, useState, useRef, useMemo: memoize, useEffect, useLayoutEffect: useEffect, useCallback: (fn, deps) => memoize(() => fn, deps) },
    render(Component, props = {}) {
      cursor = 0;
      return Component(props);
    },
    flushEffects() {
      for (const index of pending) {
        const slot = slots[index];
        slot.cleanup?.();
        slot.cleanup = slot.effect();
      }
      pending.clear();
    },
    unmount() {
      for (const slot of slots) slot?.cleanup?.();
      pending.clear();
    },
  };
}

export function findAll(tree, predicate) {
  const results = [];
  function visit(node) {
    if (Array.isArray(node)) { node.forEach(visit); return; }
    if (!node || typeof node !== 'object') return;
    if (predicate(node)) results.push(node);
    visit(node.props?.children);
  }
  visit(tree);
  return results;
}

export function find(tree, predicate) {
  return findAll(tree, predicate)[0];
}

export function textContent(tree) {
  if (Array.isArray(tree)) return tree.map(textContent).join('');
  if (typeof tree === 'string' || typeof tree === 'number') return String(tree);
  return tree?.props ? textContent(tree.props.children) : '';
}

export const settle = () => new Promise(resolve => setImmediate(resolve));

export function deferredFetch() {
  const requests = [];
  const fetch = (url, options = {}) => new Promise((resolve, reject) => {
    const request = {
      url: String(url),
      query: new URL(url, 'http://localhost').searchParams,
      resolve: data => resolve({ ok: true, status: 200, json: async () => data }),
    };
    requests.push(request);
    if (options.signal) {
      const abort = () => reject(Object.assign(new Error('Aborted'), { name: 'AbortError' }));
      if (options.signal.aborted) abort();
      else options.signal.addEventListener('abort', abort, { once: true });
    }
  });
  return { fetch, requests };
}
