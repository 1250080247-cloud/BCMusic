import assert from 'node:assert/strict';
import test from 'node:test';
import { readFile } from 'node:fs/promises';
import { encode, getToken } from 'next-auth/jwt';
import bcrypt from 'bcryptjs';
import { loadModule } from './helpers.mjs';

const secret = 'dependency-upgrade-test-secret-not-a-real-credential';

test('NextAuth rejects malformed Bearer tokens without throwing, including raw mode', async () => {
  for (const authorization of ['Bearer %', 'Bearer %E0%A4%A', 'Bearer %ZZ']) {
    for (const raw of [false, true]) {
      assert.equal(await getToken({ req: { headers: { authorization }, cookies: {} }, secret, raw }), null);
    }
  }
});

test('sessions issued before the dependency upgrade remain readable with the same secret', async () => {
  const fixture = JSON.parse(await readFile(new URL('./fixtures/nextauth-v4-session.json', import.meta.url), 'utf8'));
  const req = { headers: {}, cookies: { 'next-auth.session-token': fixture.token } };
  const token = await getToken({ req, secret, secureCookie: false });
  assert.equal(token.userId, 'legacy-test-user');
  assert.equal(token.username, 'compatibility-fixture');
  assert.equal(await getToken({ req, secret: 'another-test-secret', secureCookie: false }), null);
});

test('new encrypted sessions round-trip while invalid session cookies are rejected', async () => {
  const session = await encode({ secret, token: { userId: 'new-test-user' } });
  const req = { headers: {}, cookies: { '__Secure-next-auth.session-token': session } };
  assert.equal((await getToken({ req, secret, secureCookie: true })).userId, 'new-test-user');
  req.cookies['__Secure-next-auth.session-token'] = 'invalid-session';
  assert.equal(await getToken({ req, secret, secureCookie: true }), null);
});

async function authFixture(user) {
  const queries = [];
  const { authOptions } = await loadModule('src/lib/auth.js', {
    'next-auth/providers/credentials': { default: options => ({ id: 'credentials', ...options }) },
    'next-auth/providers/google': { default: options => ({ id: 'google', ...options }) },
    bcryptjs: { default: bcrypt },
    '@/lib/mongodb': { default: async () => {} },
    '@/models/User': { default: { findOne: query => {
      queries.push(query);
      return Promise.resolve(user);
    } } },
  });
  return { authOptions, queries, authorize: authOptions.providers.find(provider => provider.id === 'credentials').authorize };
}

test('credentials still verify existing bcrypt hashes and preserve the account identity in JWT sessions', async () => {
  const fixture = await authFixture({
    _id: 'existing-test-user', username: 'existinguser', displayName: 'Existing user',
    password: bcrypt.hashSync('test-password', 4), image: null,
  });
  const user = await fixture.authorize({ username: ' ExistingUser ', password: 'test-password' });
  assert.equal(fixture.queries[0].username, 'existinguser');
  assert.equal(user.id, 'existing-test-user');
  const token = await fixture.authOptions.callbacks.jwt({ token: {}, user, account: { provider: 'credentials' } });
  const session = await fixture.authOptions.callbacks.session({ session: { user: {} }, token });
  assert.equal(session.user.id, 'existing-test-user');
  assert.equal(session.user.username, 'existinguser');
  assert.equal(session.user.name, 'Existing user');
  assert.equal(session.user.image, '/api/user/avatar?userId=existing-test-user');
  assert.equal(fixture.authOptions.session.strategy, 'jwt');
});

test('credentials reject wrong passwords, missing accounts, OAuth-only accounts and incomplete input', async () => {
  const existing = await authFixture({ password: bcrypt.hashSync('correct-password', 4) });
  assert.equal(await existing.authorize({ username: 'someone', password: 'wrong-password' }), null);
  for (const user of [null, { password: null }]) {
    const fixture = await authFixture(user);
    assert.equal(await fixture.authorize({ username: 'someone', password: 'test-password' }), null);
  }
  const incomplete = await authFixture(null);
  assert.equal(await incomplete.authorize({ username: 'someone' }), null);
  assert.equal(incomplete.queries.length, 0);
});
