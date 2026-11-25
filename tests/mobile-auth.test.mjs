import test from 'node:test';
import assert from 'node:assert/strict';
import { loadModule, jsonRequest } from './helpers.mjs';

test('mobile sign-in only issues a grant to a session on the BCMusic origin', async () => {
  let saved;
  const origin = 'https://bc-music-gilt.vercel.app';
  const { POST } = await loadModule('src/app/api/mobile/auth/authorize/route.js', {
    globals: { process: { env: { NEXTAUTH_URL: origin } } },
    stubs: {
      'next-auth': { getServerSession: async () => ({ user: { id: 'profile-id' } }) },
      '@/lib/auth': { authOptions: {} },
      '@/lib/mongodb': { default: async () => {} },
      '@/models/MobileAuthGrant': { default: { create: async (entry) => { saved = entry; } } },
    },
  });
  const proof = 'A'.repeat(43);
  const request = (caller) => new Request(`${origin}/api/mobile/auth/authorize`, {
    method: 'POST',
    headers: { Origin: caller, 'Content-Type': 'application/json' },
    body: JSON.stringify({ state: proof, challenge: proof }),
  });
  assert.equal((await POST(request('https://unrelated.example'))).status, 403);
  assert.equal(saved, undefined);
  const response = await POST(request(origin));
  assert.equal(response.status, 200);
  const { code } = await response.json();
  assert.match(code, /^[A-Za-z0-9_-]{43}$/);
  assert.notEqual(saved._id, code);
  assert.equal(saved.challenge, proof);
  assert.ok(saved.expiresAt.getTime() > Date.now());
});

test('mobile exchange binds state, verifier and expiry before consuming the grant', async () => {
  let query;
  let issued = 0;
  let grant = { userId: 'profile-id' };
  const verifier = 'B'.repeat(43);
  const state = 'C'.repeat(43);
  const code = 'D'.repeat(43);
  const { hashMobileProof } = await loadModule('src/lib/mobile-auth.js');
  const { POST } = await loadModule('src/app/api/mobile/auth/exchange/route.js', {
    stubs: {
      'next-auth/jwt': { encode: async () => { issued++; return 'session'; } },
      '@/lib/auth': { authOptions: { secret: 'test-only', session: {} } },
      '@/lib/mongodb': { default: async () => {} },
      '@/models/MobileAuthGrant': { default: { findOneAndDelete: (filter) => {
        query = filter;
        return { lean: async () => {
          if (filter._id !== hashMobileProof(code) || filter.state !== state ||
              filter.challenge !== hashMobileProof(verifier)) return null;
          const consumed = grant;
          grant = null;
          return consumed;
        } };
      } } },
      '@/models/User': { default: { findById: () => ({ select: () => ({
        lean: async () => ({ _id: 'profile-id', username: 'tester', displayName: 'BCMusic Test' }),
      }) }) } },
    },
  });
  const path = '/api/mobile/auth/exchange';
  assert.equal((await POST(jsonRequest(path, { state, code, verifier: 'short' }))).status, 400);
  assert.equal(query, undefined);
  assert.equal((await POST(jsonRequest(path, { state, code, verifier: 'X'.repeat(43) }))).status, 401);
  assert.equal(issued, 0);
  const accepted = await POST(jsonRequest(path, { state, code, verifier }));
  assert.equal(accepted.status, 200);
  assert.match(accepted.headers.get('set-cookie'), /next-auth\.session-token=session/);
  assert.match(accepted.headers.get('set-cookie'), /; HttpOnly/i);
  assert.match(accepted.headers.get('set-cookie'), /; Secure/i);
  assert.equal(query._id, hashMobileProof(code));
  assert.equal(query.challenge, hashMobileProof(verifier));
  assert.equal(query.state, state);
  assert.ok(query.expiresAt.$gt.getTime() <= Date.now());
  assert.equal((await POST(jsonRequest(path, { state, code, verifier }))).status, 401);
  assert.equal(issued, 1);
});

test('normalizeProductionNextAuthUrl repairs localhost NEXTAUTH_URL on Vercel without affecting local dev', async () => {
  const { normalizeProductionNextAuthUrl, authOptions } = await loadModule('src/lib/auth.js', {
    stubs: {
      'next-auth/providers/credentials': { default: (options) => ({ id: 'credentials', ...options }) },
      'next-auth/providers/google': { default: (options) => ({ id: 'google', ...options }) },
      bcryptjs: { default: { hashSync: () => 'hash', compare: async () => false } },
      '@/lib/mongodb': { default: async () => {} },
      '@/lib/rate-limit': { consumeRateLimit: async () => true },
      '@/models/User': { default: {} },
    },
  });

  const localEnv = { NEXTAUTH_URL: 'http://localhost:3000' };
  assert.equal(normalizeProductionNextAuthUrl(localEnv), 'http://localhost:3000');
  assert.equal(localEnv.NEXTAUTH_URL, 'http://localhost:3000');

  const vercelBrokenEnv = {
    VERCEL: '1',
    NEXTAUTH_URL: 'http://localhost:3000',
    VERCEL_PROJECT_PRODUCTION_URL: 'bc-music-gilt.vercel.app',
  };
  assert.equal(normalizeProductionNextAuthUrl(vercelBrokenEnv), 'https://bc-music-gilt.vercel.app');
  assert.equal(vercelBrokenEnv.NEXTAUTH_URL, 'https://bc-music-gilt.vercel.app');

  const googleProvider = authOptions.providers.find((p) => p.id === 'google');
  assert.equal(googleProvider.authorization.params.scope, 'openid email profile');
});

test('mobileSessionCookieName uses __Secure- on Vercel HTTPS even if NEXTAUTH_URL was localhost', async () => {
  const { mobileSessionCookieName } = await loadModule('src/lib/mobile-auth.js', {
    globals: { process: { env: { VERCEL: '1', NEXTAUTH_URL: 'http://localhost:3000' } } },
  });
  const req = new Request('https://bc-music-gilt.vercel.app/api/mobile/auth/exchange', {
    headers: { 'x-forwarded-proto': 'https' },
  });
  assert.equal(mobileSessionCookieName(req), '__Secure-next-auth.session-token');
});

test('Google signIn normalizes email, rejects unverified email, and creates valid username fallback', async () => {
  const created = [];
  const { authOptions } = await loadModule('src/lib/auth.js', {
    stubs: {
      'next-auth/providers/credentials': { default: (options) => ({ id: 'credentials', ...options }) },
      'next-auth/providers/google': { default: (options) => ({ id: 'google', ...options }) },
      bcryptjs: { default: { hashSync: () => 'hash', compare: async () => false } },
      '@/lib/mongodb': { default: async () => {} },
      '@/lib/rate-limit': { consumeRateLimit: async () => true },
      '@/models/User': {
        default: {
          findOne: async () => null,
          create: async (doc) => { created.push(doc); return doc; },
        },
      },
    },
  });

  assert.equal(
    await authOptions.callbacks.signIn({
      account: { provider: 'google' },
      profile: { email: 'user@example.com', email_verified: false },
    }),
    false,
  );
  assert.equal(created.length, 0);

  assert.equal(
    await authOptions.callbacks.signIn({
      account: { provider: 'google' },
      profile: { email: '  ._@Example.COM  ', email_verified: true, name: 'Test User', picture: 'https://lh3.googleusercontent.com/a/test' },
    }),
    true,
  );
  assert.equal(created.length, 1);
  assert.equal(created[0].email, '._@example.com');
  assert.match(created[0].username, /^user_[a-z0-9]+$/);
  assert.ok(created[0].username.length >= 3 && created[0].username.length <= 30);
});
