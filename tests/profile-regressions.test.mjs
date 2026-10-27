import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';
import { createHookHarness, find } from './ui-harness.mjs';

test('avatar input rejects normalized variants of its own proxy endpoint', async () => {
  const { isAllowedAvatar } = await loadModule('src/lib/avatar.js');
  for (const url of [
    'https://music.example/api/user/avatar/?userId=507f1f77bcf86cd799439011',
    'https://music.example/api/user/%61vatar?userId=507f1f77bcf86cd799439011',
    'https://music.example/api//user/avatar?userId=507f1f77bcf86cd799439011',
  ]) {
    assert.equal(isAllowedAvatar(url), false, url);
  }
  assert.equal(isAllowedAvatar('https://lh3.googleusercontent.com/a/example'), true);
});

test('editing only the display name does not send or clear the session avatar', async () => {
  const harness = createHookHarness();
  const writes = [];
  const session = {
    user: {
      id: '507f1f77bcf86cd799439011', name: 'Original name', username: 'owner',
      image: '/api/user/avatar?userId=507f1f77bcf86cd799439011',
    },
  };
  const { default: Profile } = await loadModule('src/app/profile/page.js', {
    react: harness.react,
    'next-auth/react': { useSession: () => ({ data: session, update: async () => {} }) },
    '@/lib/store': { useMusicStore: () => ({ favorites: [], setCurrentSong() {}, setPlaylist() {}, setViewingSong() {} }) },
    'next/link': { default: () => null },
  }, {
    window: { location: { reload() {} } },
    fetch: async (url, options) => {
      if (url === '/api/user/update') writes.push(JSON.parse(options.body));
      return { ok: true, json: async () => ({ success: true, data: [] }) };
    },
  });
  try {
    let tree = harness.render(Profile);
    harness.flushEffects();
    find(tree, node => node.type === 'button' && node.props.title === 'Chỉnh sửa hồ sơ').props.onClick();
    tree = harness.render(Profile);
    find(tree, node => node.type === 'input' && node.props.required).props.onChange({ target: { value: 'Renamed' } });
    tree = harness.render(Profile);
    await find(tree, node => node.type === 'form').props.onSubmit({ preventDefault() {} });
    assert.equal(writes.length, 1);
    assert.equal(writes[0].displayName, 'Renamed');
    assert.equal(Object.hasOwn(writes[0], 'image'), false);
    assert.equal(Object.hasOwn(writes[0], 'userId'), false);
  } finally { harness.unmount(); }
});
