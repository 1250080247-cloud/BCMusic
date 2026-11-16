import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule, jsonRequest } from './helpers.mjs';

test('version endpoint serves the published version and HTTPS download URL', async () => {
  const { GET } = await loadModule('src/app/api/version/route.js', { globals: {
    process: { env: {
      BCMUSIC_ANDROID_VERSION: '1.3.1',
      BCMUSIC_ANDROID_DOWNLOAD_URL: 'https://example.org/bcmusic.apk',
    } },
  } });
  const response = GET();
  assert.equal(response.status, 200);
  const release = await response.json();
  assert.equal(release.version, '1.3.1');
  assert.equal(release.downloadUrl, 'https://example.org/bcmusic.apk');
});

test('version endpoint omits an unpublished release or invalid download URL', async () => {
  for (const downloadUrl of [undefined, 'http://example.org/bcmusic.apk', 'https://user@example.org/bcmusic.apk']) {
    const { GET } = await loadModule('src/app/api/version/route.js', { globals: {
      process: { env: { BCMUSIC_ANDROID_VERSION: '1.3.1', BCMUSIC_ANDROID_DOWNLOAD_URL: downloadUrl } },
    } });
    assert.equal(GET().status, 204);
  }
});

test('rate limiting updates one fixed window and uses the resulting count', async () => {
  let calls = 0;
  const { consumeRateLimit } = await loadModule('src/lib/rate-limit.js', {
    '@/lib/mongodb': { default: async () => {} },
    '@/models/RateLimit': { default: {
      findOneAndUpdate(query, update, options) {
        calls++;
        assert.equal(query._id, 'search:client');
        assert.deepEqual(Object.keys(query), ['_id']);
        assert.equal(Array.isArray(update), true);
        assert.equal(options.upsert, true);
        return { lean: async () => ({ count: 3 }) };
      },
    } },
  });
  const allowed = await consumeRateLimit('search:client', { limit: 2, windowMs: 60_000 });
  assert.equal(calls, 1);
  assert.equal(allowed, false);
});

test('rate limiter uses the Vercel client address and a shared fallback without a trusted proxy', async () => {
  const request = new Request('http://localhost', { headers: {
    'x-vercel-forwarded-for': '192.0.2.10',
    'x-forwarded-for': '192.0.2.20',
  } });
  const stubs = { '@/lib/mongodb': { default: null }, '@/models/RateLimit': { default: null } };
  const hosted = await loadModule('src/lib/rate-limit.js', { stubs, globals: { process: { env: { VERCEL: '1' } } } });
  const local = await loadModule('src/lib/rate-limit.js', { stubs });
  assert.equal(hosted.clientKey(request), '192.0.2.10');
  assert.equal(local.clientKey(request), 'unknown');
});

for (const [endpoint, model] of [['playlist', 'Playlist'], ['favorites', 'Favorite'], ['history', 'History'], ['soundcloud/import', 'SoundCloudTrack']]) {
  test(`${endpoint} hides database error details`, async () => {
    const internalError = 'private database connection detail';
    const { GET } = await loadModule(`src/app/api/${endpoint}/route.js`, {
      '@/lib/request-user': { getRequestUserId: async () => '507f1f77bcf86cd799439011' },
      '@/lib/mongodb': { default: async () => { throw new Error(internalError); } },
      [`@/models/${model}`]: { default: {} },
    });
    const response = await GET(jsonRequest(`/api/${endpoint}`, undefined, 'GET'));
    assert.equal(response.status, 500);
    const result = await response.json();
    assert.equal(result.success, false);
    assert.ok(result.message);
    assert.ok(!result.message.includes(internalError));
  });
}
