import assert from 'node:assert/strict';
import test from 'node:test';
import { createElement } from 'react';
import { renderToStaticMarkup } from 'react-dom/server';
import { loadModule } from './helpers.mjs';
import { createHookHarness } from './ui-harness.mjs';

function animationBoundary({ reducedMotion = false } = {}) {
  const tweens = [];
  const contexts = [];
  const record = (method, targets, vars) => {
    tweens.push({ method, targets: Array.isArray(targets) ? [...targets] : [targets], vars });
    return { revert() {}, kill() {} };
  };
  const gsap = {
    registerPlugin() {},
    from: (targets, vars) => record('from', targets, vars),
    to: (targets, vars) => record('to', targets, vars),
    fromTo: (targets, from, vars) => record('fromTo', targets, { ...from, ...vars }),
    set: (targets, vars) => record('set', targets, vars),
    utils: { toArray: targets => Array.from(targets) },
    matchMedia() {
      const context = { queries: [], reverted: 0 };
      contexts.push(context);
      return {
        add(query, callback) {
          context.queries.push(query);
          if (typeof query === 'string' && /prefers-reduced-motion\s*:\s*no-preference/.test(query) && !reducedMotion) callback();
          return this;
        },
        revert() { context.reverted++; },
      };
    },
  };
  const ScrollTrigger = { refresh() {} };
  return {
    tweens, contexts,
    packages: {
      gsap: { gsap, default: gsap },
      'gsap/ScrollTrigger': { ScrollTrigger, default: ScrollTrigger },
      'gsap/dist/ScrollTrigger': { ScrollTrigger, default: ScrollTrigger },
    },
  };
}

async function motionFixture(name, options = {}) {
  const harness = createHookHarness();
  const animation = animationBoundary(options);
  const hookConfigs = [];
  let pathname = '/';
  const useGSAP = (callback, config = {}) => {
    hookConfigs.push(config);
    const deferred = harness.react.useRef([]);
    harness.react.useEffect(() => {
      const cleanup = callback();
      if (config.revertOnUpdate) return cleanup;
      if (typeof cleanup === 'function') deferred.current.push(cleanup);
    }, config.dependencies || []);
    harness.react.useEffect(() => () => {
      deferred.current.forEach(cleanup => cleanup());
    }, []);
  };
  const { default: Component } = await loadModule(`src/components/${name}.js`, {
    ...animation.packages,
    react: harness.react,
    '@gsap/react': { useGSAP },
    'next/navigation': { usePathname: () => pathname },
  }, {
    document: { querySelectorAll() { throw new Error('Animations must be scoped to their component root'); } },
  });
  const heading = { id: 'heading' };
  const sections = [{ id: 'section-one' }, { id: 'section-two' }];
  const queries = [];
  const root = {
    children: [{ id: 'first' }, { id: 'second' }],
    querySelectorAll(selector) {
      queries.push(selector);
      return selector.includes('[data-motion-section]') ? sections : [heading];
    },
  };
  return {
    ...animation, harness, root, hookConfigs, queries,
    route(next) { pathname = next; },
    render(props) {
      const tree = harness.render(Component, props);
      assert.ok(tree.props.ref, 'motion wrapper must expose a scoped root ref');
      tree.props.ref.current = root;
      harness.flushEffects();
      return tree;
    },
  };
}

for (const name of ['PageMotion', 'MotionList']) {
  test(`${name} keeps SSR content visible before JavaScript animations run`, async () => {
    const animation = animationBoundary();
    const { default: Component } = await loadModule(`src/components/${name}.js`, {
      ...animation.packages,
      '@gsap/react': { useGSAP() {} },
      'next/navigation': { usePathname: () => '/' },
    });
    const children = [createElement('button', { key: 'first' }, 'First song'), createElement('button', { key: 'second' }, 'Second song')];
    const markup = renderToStaticMarkup(createElement(Component, { className: 'song-list', style: { display: 'grid' }, animationKey: 'first-load' }, children));
    assert.ok(markup.includes('First song'));
    assert.ok(markup.indexOf('First song') < markup.indexOf('Second song'));
    assert.doesNotMatch(markup, /(?:opacity:\s*0(?:[;"\s])|visibility:\s*hidden|display:\s*none)/);
    assert.equal(animation.tweens.length, 0);
  });

  test(`${name} respects reduced motion and cleans up its matchMedia context`, async () => {
    const fixture = await motionFixture(name, { reducedMotion: true });
    fixture.render({ children: createElement('p', null, 'Visible content'), animationKey: 'one' });
    assert.equal(fixture.tweens.length, 0);
    assert.equal(fixture.contexts.length, 1);
    assert.ok(fixture.contexts[0].queries.some(query => /prefers-reduced-motion\s*:\s*no-preference/.test(query)));
    assert.equal(fixture.hookConfigs.at(-1).scope.current, fixture.root);
    fixture.harness.unmount();
    assert.equal(fixture.contexts[0].reverted, 1);
  });
}

test('PageMotion scopes scroll reveals and does not immediately hide sections below the viewport', async () => {
  const fixture = await motionFixture('PageMotion');
  try {
    fixture.render({ children: createElement('main', null, 'Page content') });
    assert.ok(fixture.queries.some(selector => selector.includes('[data-motion-section]')));
    assert.ok(fixture.queries.some(selector => selector.includes('h1')));
    const reveals = fixture.tweens.filter(tween => tween.vars.scrollTrigger);
    assert.ok(reveals.length > 0, 'page sections should have scroll-triggered reveals');
    for (const reveal of reveals) {
      assert.equal(reveal.vars.immediateRender, false);
      assert.equal(reveal.vars.scrollTrigger.markers === true, false);
    }
  } finally { fixture.harness.unmount(); }
});

test('PageMotion reverts old animations when route or rendered page content changes', async () => {
  const fixture = await motionFixture('PageMotion');
  const children = createElement('main', null, 'Page one');
  fixture.render({ children });
  fixture.route('/search');
  fixture.render({ children });
  assert.equal(fixture.contexts[0].reverted, 1);
  fixture.render({ children: createElement('main', null, 'New search results') });
  assert.equal(fixture.contexts[1].reverted, 1);
  assert.equal(fixture.contexts.length, 3);
  fixture.harness.unmount();
  assert.ok(fixture.contexts.every(context => context.reverted === 1));
});

test('MotionList uses current child order after updates and preserves hover transforms', async () => {
  const fixture = await motionFixture('MotionList');
  const children = [createElement('button', { key: 'first' }, 'First'), createElement('button', { key: 'second' }, 'Second')];
  const style = { display: 'grid' };
  const tree = fixture.render({ children, className: 'song-list', style, animationKey: 'first' });
  assert.equal(tree.props.children, children);
  assert.equal(tree.props.className, 'song-list');
  assert.equal(tree.props.style, style);
  assert.deepEqual(fixture.tweens.at(-1).targets.map(target => target.id), ['first', 'second']);
  fixture.root.children = [{ id: 'second' }, { id: 'third' }];
  fixture.render({ children: [children[1], createElement('button', { key: 'third' }, 'Third')], animationKey: 'updated' });
  assert.equal(fixture.contexts[0].reverted, 1);
  assert.deepEqual(fixture.tweens.at(-1).targets.map(target => target.id), ['second', 'third']);
  for (const tween of fixture.tweens) {
    assert.equal(typeof tween.vars.opacity, 'number');
    for (const property of ['x', 'y', 'xPercent', 'yPercent', 'scale', 'scaleX', 'scaleY', 'rotation', 'transform']) {
      assert.equal(Object.hasOwn(tween.vars, property), false, `${property} must remain available to hover styling`);
    }
  }
  fixture.harness.unmount();
  assert.ok(fixture.contexts.every(context => context.reverted === 1));
});
