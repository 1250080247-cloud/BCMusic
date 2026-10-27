import assert from 'node:assert/strict';
import test from 'node:test';
import { createRequire } from 'node:module';
import { loadModule } from './helpers.mjs';

const require = createRequire(import.meta.url);
const { NextRequest } = require('next/server');
const secret = 'review-test-secret-never-use-in-production';

test('independently issued guest tokens identify different isolated guests', async () => {
  const { createGuestToken, readGuestId } = await loadModule('src/lib/guest-identity.js');
  const first = createGuestToken(secret);
  const second = createGuestToken(secret);
  assert.notEqual(first, second);
  assert.match(readGuestId(first, secret), /^guest:/);
  assert.notEqual(readGuestId(first, secret), readGuestId(second, secret));
  assert.equal(readGuestId(first, secret), readGuestId(first, secret));
});

test('guest token validation rejects tampering, another secret, and raw account IDs', async () => {
  const { createGuestToken, readGuestId } = await loadModule('src/lib/guest-identity.js');
  const token = createGuestToken(secret);
  const changed = `${token[0] === 'a' ? 'b' : 'a'}${token.slice(1)}`;
  for (const invalid of [undefined, null, '', 123, {}, '507f1f77bcf86cd799439011', 'guest:forged', token + '.extra', changed]) {
    assert.equal(readGuestId(invalid, secret), null);
  }
  assert.equal(readGuestId(token, 'different-secret'), null);
  assert.equal(readGuestId(token, undefined), null);
  assert.throws(() => createGuestToken(undefined), /secret/i);
});

test('proxy issues an HttpOnly cookie and forwards it into the first server request', async () => {
  const identity = await loadModule('src/lib/guest-identity.js');
  const { proxy } = await loadModule('src/proxy.js', {}, {
    process: { env: { NEXTAUTH_SECRET: secret, NODE_ENV: 'production' } },
  });
  const response = proxy(new NextRequest('https://music.example/history'));
  const cookie = response.cookies.get(identity.GUEST_COOKIE);
  assert.ok(cookie);
  assert.equal(cookie.httpOnly, true);
  assert.equal(cookie.sameSite, 'lax');
  assert.equal(cookie.secure, true);
  assert.equal(cookie.path, '/');
  assert.match(identity.readGuestId(cookie.value, secret), /^guest:/);
  const forwarded = response.headers.get('x-middleware-request-cookie');
  assert.ok(forwarded?.includes(`${identity.GUEST_COOKIE}=${cookie.value}`));
});

test('proxy preserves a valid guest across requests and replaces a forged cookie', async () => {
  const identity = await loadModule('src/lib/guest-identity.js');
  const { proxy } = await loadModule('src/proxy.js', {}, {
    process: { env: { NEXTAUTH_SECRET: secret, NODE_ENV: 'development' } },
  });
  const token = identity.createGuestToken(secret);
  const request = new NextRequest('http://localhost/playlist', {
    headers: { Cookie: `${identity.GUEST_COOKIE}=${token}` },
  });
  const response = proxy(request);
  assert.equal(response.cookies.get(identity.GUEST_COOKIE), undefined, 'valid identity must not rotate on each navigation');
  assert.equal(request.cookies.get(identity.GUEST_COOKIE).value, token);

  const replacement = proxy(new NextRequest('http://localhost/playlist', {
    headers: { Cookie: `${identity.GUEST_COOKIE}=507f1f77bcf86cd799439011` },
  })).cookies.get(identity.GUEST_COOKIE);
  assert.ok(replacement);
  assert.equal(replacement.secure, false);
  assert.match(identity.readGuestId(replacement.value, secret), /^guest:/);
});

async function requestIdentity(session, token) {
  const { getRequestUserId } = await loadModule('src/lib/request-user.js', {
    'next-auth': { getServerSession: async () => session },
    'next/headers': { cookies: async () => ({ get: () => token ? { value: token } : undefined }) },
    '@/lib/auth': { authOptions: {} },
  }, { process: { env: { NEXTAUTH_SECRET: secret } } });
  return getRequestUserId;
}

test('request identity always prefers the authenticated account to a guest cookie', async () => {
  const { createGuestToken } = await loadModule('src/lib/guest-identity.js');
  const getIdentity = await requestIdentity({ user: { id: '507f1f77bcf86cd799439011' } }, createGuestToken(secret));
  assert.equal(await getIdentity(), '507f1f77bcf86cd799439011');
  assert.equal(await getIdentity({ allowGuest: true }), '507f1f77bcf86cd799439011');
});

test('guest access requires explicit permission and a valid server signature', async () => {
  const { createGuestToken, readGuestId } = await loadModule('src/lib/guest-identity.js');
  const token = createGuestToken(secret);
  const getIdentity = await requestIdentity(null, token);
  assert.equal(await getIdentity(), null);
  assert.equal(await getIdentity({ allowGuest: true }), readGuestId(token, secret));
  const forgedIdentity = await requestIdentity(null, '507f1f77bcf86cd799439011');
  assert.equal(await forgedIdentity({ allowGuest: true }), null);
  const noIdentity = await requestIdentity(null, undefined);
  assert.equal(await noIdentity({ allowGuest: true }), null);
});
