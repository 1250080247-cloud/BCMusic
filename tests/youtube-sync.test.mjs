import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import path from 'node:path';
import { loadModule } from './helpers.mjs';

const TEST_KEY = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const OTHER_KEY = 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

const ENV_READY = {
  YOUTUBE_OAUTH_CLIENT_ID: 'yt-separate-client-id.apps.googleusercontent.com',
  YOUTUBE_OAUTH_CLIENT_SECRET: 'yt-separate-secret',
  YOUTUBE_TOKEN_ENCRYPTION_KEY: TEST_KEY,
  GOOGLE_CLIENT_ID: 'login-google-client-id-must-never-be-used',
  GOOGLE_CLIENT_SECRET: 'login-google-secret-must-never-be-used',
};

const YOUTUBE_STUBS = {
  '@/lib/mongodb': { default: async () => {} },
  '@/models/SongCache': { default: {} },
};

test('YouTube sync is completely isolated from GOOGLE_CLIENT_ID and auth.js', async () => {
  const root = path.resolve(import.meta.dirname, '..');
  const authCode = await readFile(path.join(root, 'src/lib/auth.js'), 'utf8');
  const syncCode = await readFile(path.join(root, 'src/lib/youtube-sync.js'), 'utf8');
  assert.doesNotMatch(authCode, /youtube\.readonly/i);
  assert.doesNotMatch(syncCode, /GOOGLE_CLIENT_ID|GOOGLE_CLIENT_SECRET/);

  const mod = await loadModule('src/lib/youtube-sync.js', {
    stubs: YOUTUBE_STUBS,
    globals: {
      process: {
        env: {
          GOOGLE_CLIENT_ID: 'login-client',
          GOOGLE_CLIENT_SECRET: 'login-secret',
        },
      },
    },
  });
  assert.equal(mod.isYouTubeSyncAvailable(), false);

  const readyMod = await loadModule('src/lib/youtube-sync.js', {
    stubs: YOUTUBE_STUBS,
    globals: { process: { env: ENV_READY } },
  });
  assert.equal(readyMod.isYouTubeSyncAvailable(), true);
  const authUrl = new URL(
    readyMod.buildYouTubeAuthUrl({
      redirectUri: 'https://bc-music-gilt.vercel.app/api/youtube/callback',
      state: 'signed.state',
    }),
  );
  assert.equal(authUrl.searchParams.get('client_id'), ENV_READY.YOUTUBE_OAUTH_CLIENT_ID);
  assert.notEqual(authUrl.searchParams.get('client_id'), ENV_READY.GOOGLE_CLIENT_ID);
  assert.equal(authUrl.searchParams.get('scope'), 'https://www.googleapis.com/auth/youtube.readonly');
  assert.equal(authUrl.searchParams.get('access_type'), 'offline');
  assert.equal(authUrl.searchParams.get('prompt'), 'consent');
});

test('AES-256-GCM token encryption roundtrips, uses unique IVs, and rejects tampering', async () => {
  const mod = await loadModule('src/lib/youtube-sync.js', {
    stubs: YOUTUBE_STUBS,
    globals: { process: { env: ENV_READY } },
  });

  const c1 = mod.encryptToken('ya29.refresh-secret-token', TEST_KEY);
  const c2 = mod.encryptToken('ya29.refresh-secret-token', TEST_KEY);
  assert.notEqual(c1, c2);
  assert.ok(c1.startsWith('v1:'));
  assert.equal(mod.decryptToken(c1, TEST_KEY), 'ya29.refresh-secret-token');
  assert.equal(mod.decryptToken(c2, TEST_KEY), 'ya29.refresh-secret-token');

  // Wrong key fails authentication tag check.
  assert.throws(() => mod.decryptToken(c1, OTHER_KEY));

  // Tampered ciphertext fails authentication tag check.
  const parts = c1.split(':');
  parts[3] = parts[3].slice(0, -2) + (parts[3].endsWith('AA') ? 'BB' : 'AA');
  assert.throws(() => mod.decryptToken(parts.join(':'), TEST_KEY));
});

test('CSRF state signing verifies HMAC, expiry, and source binding', async () => {
  const mod = await loadModule('src/lib/youtube-sync.js', {
    stubs: YOUTUBE_STUBS,
    globals: { process: { env: ENV_READY } },
  });

  const now = 1_700_000_000_000;
  const nonce = 'nonce_1234567890abcdef';
  const state = mod.signYouTubeState(
    { userId: 'user-1', source: 'mobile', nonce, exp: now + 60_000 },
    TEST_KEY,
  );
  const verified = mod.verifyYouTubeState(state, TEST_KEY, now + 1000);
  assert.deepEqual({ ...verified }, {
    userId: 'user-1',
    source: 'mobile',
    nonce,
    exp: now + 60_000,
  });

  assert.equal(mod.verifyYouTubeState(state, TEST_KEY, now + 60_001), null);
  assert.equal(mod.verifyYouTubeState(state, OTHER_KEY, now + 1000), null);
  assert.equal(mod.verifyYouTubeState(`${state}x`, TEST_KEY, now + 1000), null);
});

test('filterLikedMusicVideos keeps categoryId=10 music & music-keyword videos and drops non-music/blacklisted', async () => {
  const mod = await loadModule('src/lib/youtube-sync.js', {
    stubs: YOUTUBE_STUBS,
    globals: { process: { env: ENV_READY } },
  });

  const liked = mod.filterLikedMusicVideos([
    {
      id: 'dQw4w9WgXcQ',
      snippet: { title: 'Nàng Thơ', channelTitle: 'Hoàng Dũng', categoryId: '10' },
      contentDetails: { duration: 'PT4M14S' },
    },
    {
      id: 'M7lc1UVf-VE',
      snippet: { title: 'Review Laptop Gaming 2026', channelTitle: 'Tech Channel', categoryId: '28' },
      contentDetails: { duration: 'PT10M0S' },
    },
    {
      id: 'jNQXAC9IVRw',
      snippet: { title: 'Chìm Sâu (Official MV)', channelTitle: 'RPT MCK', categoryId: '22' },
      contentDetails: { duration: 'PT2M36S' },
    },
    {
      id: 'aqz-KE-bpKQ',
      snippet: { title: 'Phim Chiếu Rạp Trailer Mới', channelTitle: 'Cinema', categoryId: '10' },
      contentDetails: { duration: 'PT2M10S' },
    },
  ]);

  assert.deepEqual([...liked.map((s) => s.id)], ['dQw4w9WgXcQ', 'jNQXAC9IVRw']);
  assert.equal(liked[0].durationSeconds, 254);
});

test('GET /api/youtube/status returns available=false when env vars are unset', async () => {
  const { GET } = await loadModule('src/app/api/youtube/status/route.js', {
    globals: { process: { env: {} } },
    stubs: {
      '@/lib/mongodb': { default: async () => {} },
      '@/lib/request-user': { getRequestUserId: async () => 'user-1' },
      '@/models/YouTubeConnection': { default: {} },
      '@/models/SongCache': { default: {} },
    },
  });

  const res = await GET();
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.available, false);
  assert.equal(body.connected, false);
  assert.equal(body.needsReconnect, false);
});

test('POST + GET /api/youtube/connect mobile handoff mints hashed grant, consumes once, and sets CSRF cookie', async () => {
  let savedGrant = null;
  const { POST, GET } = await loadModule('src/app/api/youtube/connect/route.js', {
    globals: { process: { env: ENV_READY } },
    stubs: {
      '@/lib/mongodb': { default: async () => {} },
      '@/lib/request-user': { getRequestUserId: async () => 'user-42' },
      '@/models/SongCache': { default: {} },
      '@/models/YouTubeConnectGrant': {
        default: {
          create: async (doc) => {
            savedGrant = doc;
            return doc;
          },
          findOneAndDelete: (filter) => ({
            lean: async () => {
              if (!savedGrant || filter._id !== savedGrant._id) return null;
              const hit = savedGrant;
              savedGrant = null;
              return hit;
            },
          }),
        },
      },
    },
  });

  const postRes = await POST(
    new Request('https://bc-music-gilt.vercel.app/api/youtube/connect', { method: 'POST' }),
  );
  assert.equal(postRes.status, 200);
  const { url } = await postRes.json();
  const parsed = new URL(url);
  const grant = parsed.searchParams.get('grant');
  assert.ok(grant);
  assert.notEqual(savedGrant._id, grant);
  assert.equal(parsed.searchParams.get('source'), 'mobile');

  // Now simulate Custom Tabs hitting GET /api/youtube/connect without session cookie.
  const { GET: GET_UNAUTH } = await loadModule('src/app/api/youtube/connect/route.js', {
    globals: { process: { env: ENV_READY } },
    stubs: {
      '@/lib/mongodb': { default: async () => {} },
      '@/lib/request-user': { getRequestUserId: async () => null },
      '@/models/SongCache': { default: {} },
      '@/models/YouTubeConnectGrant': {
        default: {
          findOneAndDelete: (filter) => ({
            lean: async () => {
              if (!savedGrant || filter._id !== savedGrant._id) return null;
              const hit = savedGrant;
              savedGrant = null;
              return hit;
            },
          }),
        },
      },
    },
  });

  const redirectRes = await GET_UNAUTH(new Request(url));
  assert.equal(redirectRes.status, 302);
  const location = new URL(redirectRes.headers.get('location'));
  assert.equal(location.origin, 'https://accounts.google.com');
  assert.equal(location.searchParams.get('client_id'), ENV_READY.YOUTUBE_OAUTH_CLIENT_ID);
  assert.match(redirectRes.headers.get('set-cookie') || '', /bcmusic_yt_oauth_nonce=/);

  // Replaying the same single-use grant fails with 401.
  const replayRes = await GET_UNAUTH(new Request(url));
  assert.equal(replayRes.status, 401);
});

test('POST /api/youtube/sync enforces 3/hour rate limit and marks invalid_grant as expired', async () => {
  let calls = 0;
  let savedUpdate = null;

  const syncLib = await loadModule('src/lib/youtube-sync.js', {
    stubs: YOUTUBE_STUBS,
    globals: { process: { env: ENV_READY } },
  });
  const encRefresh = syncLib.encryptToken('expired-refresh-token', TEST_KEY);

  const mockConn = {
    userId: 'user-7',
    status: 'connected',
    encryptedRefreshToken: encRefresh,
    encryptedAccessToken: null,
    accessTokenExpiresAt: new Date(Date.now() - 1000),
    likedSongs: [],
    playlists: [],
    async save() {
      savedUpdate = {
        status: this.status,
        encryptedRefreshToken: this.encryptedRefreshToken,
        encryptedAccessToken: this.encryptedAccessToken,
      };
    },
  };

  const { POST } = await loadModule('src/app/api/youtube/sync/route.js', {
    globals: {
      process: { env: ENV_READY },
      fetch: async () =>
        new Response(JSON.stringify({ error: 'invalid_grant' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }),
    },
    stubs: {
      '@/lib/mongodb': { default: async () => {} },
      '@/lib/request-user': { getRequestUserId: async () => 'user-7' },
      '@/lib/rate-limit': {
        consumeRateLimit: async () => {
          calls += 1;
          return calls <= 3;
        },
      },
      '@/models/SongCache': { default: {} },
      '@/models/YouTubeConnection': {
        default: {
          findOne: async () => mockConn,
          updateOne: async (_filter, update) => {
            savedUpdate = update.$set;
          },
        },
      },
    },
  });

  // 1st call hits invalid_grant -> marks expired, wipes tokens, returns needsReconnect=true.
  const res1 = await POST();
  assert.equal(res1.status, 200);
  const body1 = await res1.json();
  assert.equal(body1.needsReconnect, true);
  assert.equal(body1.connected, false);
  assert.equal(savedUpdate.status, 'expired');
  assert.equal(savedUpdate.encryptedRefreshToken, null);

  // 2nd & 3rd allowed, 4th blocked with 429.
  await POST();
  await POST();
  const res4 = await POST();
  assert.equal(res4.status, 429);
});

test('POST /api/youtube/disconnect revokes token with Google and deletes DB connection', async () => {
  const revokedUrls = [];
  let deletedFilter = null;
  const syncLib = await loadModule('src/lib/youtube-sync.js', {
    stubs: YOUTUBE_STUBS,
    globals: { process: { env: ENV_READY } },
  });
  const encRefresh = syncLib.encryptToken('refresh-to-revoke', TEST_KEY);

  const { POST } = await loadModule('src/app/api/youtube/disconnect/route.js', {
    globals: {
      process: { env: ENV_READY },
      fetch: async (url, init) => {
        revokedUrls.push({ url: String(url), body: init?.body });
        return new Response('', { status: 200 });
      },
    },
    stubs: {
      '@/lib/mongodb': { default: async () => {} },
      '@/lib/request-user': { getRequestUserId: async () => 'user-9' },
      '@/models/SongCache': { default: {} },
      '@/models/YouTubeConnection': {
        default: {
          findOne: () => ({
            lean: async () => ({
              userId: 'user-9',
              encryptedRefreshToken: encRefresh,
            }),
          }),
          deleteOne: async (filter) => {
            deletedFilter = filter;
          },
        },
      },
    },
  });

  const res = await POST();
  assert.equal(res.status, 200);
  const body = await res.json();
  assert.equal(body.success, true);
  assert.equal(body.connected, false);
  assert.equal(revokedUrls.length, 1);
  assert.equal(revokedUrls[0].url, 'https://oauth2.googleapis.com/revoke');
  assert.match(revokedUrls[0].body, /token=refresh-to-revoke/);
  assert.deepEqual({ ...deletedFilter }, { userId: 'user-9' });
});

test('isYouTubeCacheFresh enforces 12-hour TTL and buildCollectionsPayload marks items readOnly YouTube', async () => {
  const mod = await loadModule('src/lib/youtube-sync.js', {
    stubs: YOUTUBE_STUBS,
    globals: { process: { env: ENV_READY } },
  });

  const now = 1_700_000_000_000;
  assert.equal(mod.isYouTubeCacheFresh({ lastSyncedAt: new Date(now - 11 * 3600_000) }, now), true);
  assert.equal(mod.isYouTubeCacheFresh({ lastSyncedAt: new Date(now - 13 * 3600_000) }, now), false);

  const payload = mod.buildCollectionsPayload({
    status: 'connected',
    lastSyncedAt: new Date(now),
    likedSongs: [{ id: 'dQw4w9WgXcQ', title: 'Nàng Thơ', artist: 'Hoàng Dũng', thumbnail: '' }],
    playlists: [
      {
        id: 'PL123',
        name: 'Nhạc Đêm',
        itemCount: 1,
        thumbnail: '',
        songs: [{ id: 'M7lc1UVf-VE', title: 'Chìm Sâu', artist: 'RPT MCK', thumbnail: '' }],
      },
    ],
  });
  assert.equal(payload.connected, true);
  assert.equal(payload.likedPlaylist.source, 'youtube');
  assert.equal(payload.likedPlaylist.isLiked, true);
  assert.equal(payload.likedPlaylist.readOnly, true);
  assert.equal(payload.playlists[0].source, 'youtube');
  assert.equal(payload.playlists[0].isLiked, false);
  assert.equal(payload.playlists[0].readOnly, true);
});

test('mobile YouTube connect prioritizes mobile grant over browser session and callback verifies server-side nonce without cookie', async () => {
  const grants = new Map();
  const YouTubeConnectGrantStub = {
    create: async (doc) => {
      grants.set(doc._id, doc);
      return doc;
    },
    findOneAndDelete: (filter) => ({
      lean: async () => {
        const hit = grants.get(filter._id) || null;
        if (!hit) return null;
        if (filter.userId && hit.userId !== filter.userId) return null;
        grants.delete(filter._id);
        return hit;
      },
    }),
  };

  // Android app mints a grant for mobile-user-99.
  const { POST } = await loadModule('src/app/api/youtube/connect/route.js', {
    globals: { process: { env: ENV_READY } },
    stubs: {
      '@/lib/mongodb': { default: async () => {} },
      '@/lib/request-user': { getRequestUserId: async () => 'mobile-user-99' },
      '@/models/SongCache': { default: {} },
      '@/models/YouTubeConnectGrant': { default: YouTubeConnectGrantStub },
    },
  });
  const postRes = await POST(
    new Request('https://bc-music-gilt.vercel.app/api/youtube/connect', { method: 'POST' }),
  );
  const { url } = await postRes.json();

  // Browser has a DIFFERENT logged-in web session (other-web-user), yet mobile grant must win.
  const { GET: GET_CONNECT } = await loadModule('src/app/api/youtube/connect/route.js', {
    globals: { process: { env: ENV_READY } },
    stubs: {
      '@/lib/mongodb': { default: async () => {} },
      '@/lib/request-user': { getRequestUserId: async () => 'other-web-user' },
      '@/models/SongCache': { default: {} },
      '@/models/YouTubeConnectGrant': { default: YouTubeConnectGrantStub },
    },
  });
  const connectRes = await GET_CONNECT(new Request(url));
  assert.equal(connectRes.status, 302);
  const googleAuthUrl = new URL(connectRes.headers.get('location'));
  const signedState = googleAuthUrl.searchParams.get('state');
  assert.ok(signedState);

  // Now simulate callback arriving with NO cookie (dropped by Custom Tabs) — server-side nonce must verify and link mobile-user-99.
  let savedUserId = null;
  const { GET: GET_CALLBACK } = await loadModule('src/app/api/youtube/callback/route.js', {
    globals: {
      process: { env: ENV_READY },
      fetch: async (targetUrl) => {
        const s = String(targetUrl);
        if (s.includes('oauth2.googleapis.com/token')) {
          return new Response(
            JSON.stringify({ access_token: 'ya29.ok', refresh_token: '1//ref', expires_in: 3600 }),
            { status: 200, headers: { 'Content-Type': 'application/json' } },
          );
        }
        return new Response(JSON.stringify({ items: [] }), {
          status: 200,
          headers: { 'Content-Type': 'application/json' },
        });
      },
    },
    stubs: {
      '@/lib/mongodb': { default: async () => {} },
      '@/models/SongCache': { default: {} },
      '@/models/YouTubeConnectGrant': { default: YouTubeConnectGrantStub },
      '@/models/YouTubeConnection': {
        default: {
          findOne: async () => null,
          findOneAndUpdate: async (filter, update) => {
            savedUserId = filter.userId;
            return { ...update.$set, async save() {} };
          },
          updateOne: async () => {},
        },
      },
    },
  });

  const cbRes = await GET_CALLBACK(
    new Request(
      `https://bc-music-gilt.vercel.app/api/youtube/callback?state=${encodeURIComponent(signedState)}&code=auth-code-123`,
    ),
  );
  assert.equal(cbRes.status, 200);
  const html = await cbRes.text();
  assert.equal(savedUserId, 'mobile-user-99');
  assert.match(html, /app\.bcmusic\.personal:\/\/youtube\/complete\?status=ok/);
});
