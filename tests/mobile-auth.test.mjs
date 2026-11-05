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
