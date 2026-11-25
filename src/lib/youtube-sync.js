import { createCipheriv, createDecipheriv, createHmac, randomBytes, timingSafeEqual } from 'node:crypto';
import {
  STRONG_MUSIC_REGEX,
  MIX_MUSIC_REGEX,
  filterMusicSongs,
  getYouTubeSongs,
} from '@/lib/youtube';
import { parseYouTubeDuration } from '@/lib/youtube-shorts';
import { excludeHeard, mergeUnique, rankArtists } from '@/lib/recommendations';

export const YOUTUBE_READONLY_SCOPE = 'https://www.googleapis.com/auth/youtube.readonly';
export const YOUTUBE_SYNC_CACHE_TTL_MS = 12 * 60 * 60 * 1000; // 12 hours
export const YOUTUBE_STATE_TTL_MS = 10 * 60 * 1000; // 10 minutes
export const YOUTUBE_CONNECT_GRANT_TTL_MS = 2 * 60 * 1000; // 2 minutes
export const YOUTUBE_STATE_COOKIE = 'bcmusic_yt_oauth_nonce';
export const YOUTUBE_MOBILE_CALLBACK = 'app.bcmusic.personal://youtube/complete';

const HEX_64_PATTERN = /^[a-fA-F0-9]{64}$/;
const VIDEO_ID_PATTERN = /^[A-Za-z0-9_-]{11}$/;
const GOOGLE_AUTH_ENDPOINT = 'https://accounts.google.com/o/oauth2/v2/auth';
const GOOGLE_TOKEN_ENDPOINT = 'https://oauth2.googleapis.com/token';
const GOOGLE_REVOKE_ENDPOINT = 'https://oauth2.googleapis.com/revoke';
const YOUTUBE_API_BASE = 'https://www.googleapis.com/youtube/v3';
const FETCH_TIMEOUT_MS = 10_000;

export class YouTubeReconnectError extends Error {
  constructor(message = 'Phiên kết nối YouTube đã hết hạn. Hãy kết nối lại.') {
    super(message);
    this.name = 'YouTubeReconnectError';
    this.code = 'invalid_grant';
  }
}

export function getYouTubeOAuthConfig(env = process.env) {
  const clientId = typeof env.YOUTUBE_OAUTH_CLIENT_ID === 'string' ? env.YOUTUBE_OAUTH_CLIENT_ID.trim() : '';
  const clientSecret = typeof env.YOUTUBE_OAUTH_CLIENT_SECRET === 'string' ? env.YOUTUBE_OAUTH_CLIENT_SECRET.trim() : '';
  const encryptionKey = typeof env.YOUTUBE_TOKEN_ENCRYPTION_KEY === 'string' ? env.YOUTUBE_TOKEN_ENCRYPTION_KEY.trim() : '';
  const available = Boolean(clientId && clientSecret && HEX_64_PATTERN.test(encryptionKey));
  return { available, clientId, clientSecret, encryptionKey };
}

export function isYouTubeSyncAvailable(env = process.env) {
  return getYouTubeOAuthConfig(env).available;
}

function keyBuffer(keyHex) {
  if (typeof keyHex !== 'string' || !HEX_64_PATTERN.test(keyHex)) {
    throw new Error('Invalid YOUTUBE_TOKEN_ENCRYPTION_KEY (expected 64-char hex).');
  }
  return Buffer.from(keyHex, 'hex');
}

export function encryptToken(plain, keyHex = process.env.YOUTUBE_TOKEN_ENCRYPTION_KEY) {
  if (typeof plain !== 'string' || !plain.length) {
    throw new Error('Cannot encrypt empty token.');
  }
  const key = keyBuffer(keyHex);
  const iv = randomBytes(12);
  const cipher = createCipheriv('aes-256-gcm', key, iv);
  const encrypted = Buffer.concat([cipher.update(plain, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();
  return `v1:${iv.toString('base64url')}:${authTag.toString('base64url')}:${encrypted.toString('base64url')}`;
}

export function decryptToken(payload, keyHex = process.env.YOUTUBE_TOKEN_ENCRYPTION_KEY) {
  if (typeof payload !== 'string' || !payload.startsWith('v1:')) {
    throw new Error('Malformed encrypted token.');
  }
  const parts = payload.split(':');
  if (parts.length !== 4) {
    throw new Error('Malformed encrypted token.');
  }
  const [, ivB64, tagB64, dataB64] = parts;
  const key = keyBuffer(keyHex);
  const iv = Buffer.from(ivB64, 'base64url');
  const authTag = Buffer.from(tagB64, 'base64url');
  const data = Buffer.from(dataB64, 'base64url');
  if (iv.length !== 12 || authTag.length !== 16) {
    throw new Error('Invalid encrypted token parameters.');
  }
  const decipher = createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(authTag);
  return Buffer.concat([decipher.update(data), decipher.final()]).toString('utf8');
}

export function signYouTubeState(
  { userId, source = 'web', nonce, exp = Date.now() + YOUTUBE_STATE_TTL_MS },
  keyHex = process.env.YOUTUBE_TOKEN_ENCRYPTION_KEY,
) {
  if (typeof userId !== 'string' || !userId.trim()) {
    throw new Error('Missing userId for YouTube OAuth state.');
  }
  const safeSource = source === 'mobile' ? 'mobile' : 'web';
  const safeNonce = typeof nonce === 'string' && nonce.length >= 16
    ? nonce
    : randomBytes(16).toString('base64url');
  const payload = Buffer.from(
    JSON.stringify({ u: userId, s: safeSource, n: safeNonce, e: exp }),
    'utf8',
  ).toString('base64url');
  const sig = createHmac('sha256', keyBuffer(keyHex)).update(payload).digest('base64url');
  return `${payload}.${sig}`;
}

export function verifyYouTubeState(
  state,
  keyHex = process.env.YOUTUBE_TOKEN_ENCRYPTION_KEY,
  now = Date.now(),
) {
  if (typeof state !== 'string' || !state.includes('.')) return null;
  const parts = state.split('.');
  if (parts.length !== 2) return null;
  const [payloadB64, sigB64] = parts;
  if (!payloadB64 || !sigB64) return null;

  try {
    const expectedSig = createHmac('sha256', keyBuffer(keyHex)).update(payloadB64).digest();
    const providedSig = Buffer.from(sigB64, 'base64url');
    if (expectedSig.length !== providedSig.length || !timingSafeEqual(expectedSig, providedSig)) {
      return null;
    }
    const parsed = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf8'));
    if (
      typeof parsed?.u !== 'string' ||
      !parsed.u.trim() ||
      (parsed.s !== 'web' && parsed.s !== 'mobile') ||
      typeof parsed.n !== 'string' ||
      parsed.n.length < 16 ||
      typeof parsed.e !== 'number' ||
      parsed.e <= now
    ) {
      return null;
    }
    return {
      userId: parsed.u,
      source: parsed.s,
      nonce: parsed.n,
      exp: parsed.e,
    };
  } catch {
    return null;
  }
}

export function noncesMatch(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || !a || !b) return false;
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  return bufA.length === bufB.length && timingSafeEqual(bufA, bufB);
}

export function getAppOrigin(request, env = process.env) {
  if (env.VERCEL === '1' && env.VERCEL_PROJECT_PRODUCTION_URL) {
    return `https://${env.VERCEL_PROJECT_PRODUCTION_URL}`;
  }
  const forwardedHost = request?.headers?.get?.('x-forwarded-host')?.split(',')[0]?.trim();
  const forwardedProto = request?.headers?.get?.('x-forwarded-proto')?.split(',')[0]?.trim();
  if (forwardedHost) {
    return `${forwardedProto || 'https'}://${forwardedHost}`;
  }
  if (request?.url) {
    return new URL(request.url).origin;
  }
  return env.NEXTAUTH_URL || 'http://localhost:3000';
}

export function getYouTubeRedirectUri(request, env = process.env) {
  const configured = typeof env.YOUTUBE_OAUTH_REDIRECT_URI === 'string'
    ? env.YOUTUBE_OAUTH_REDIRECT_URI.trim()
    : '';
  if (configured) return configured;
  return `${getAppOrigin(request, env)}/api/youtube/callback`;
}

export function buildYouTubeAuthUrl({
  redirectUri,
  state,
  env = process.env,
}) {
  const { available, clientId } = getYouTubeOAuthConfig(env);
  if (!available) {
    throw new Error('YouTube sync is not configured on this server.');
  }
  const params = new URLSearchParams({
    client_id: clientId,
    redirect_uri: redirectUri,
    response_type: 'code',
    scope: YOUTUBE_READONLY_SCOPE,
    access_type: 'offline',
    prompt: 'consent',
    include_granted_scopes: 'false',
    state,
  });
  return `${GOOGLE_AUTH_ENDPOINT}?${params.toString()}`;
}

export async function exchangeYouTubeCode({
  code,
  redirectUri,
  env = process.env,
  fetchImpl = fetch,
}) {
  const { available, clientId, clientSecret } = getYouTubeOAuthConfig(env);
  if (!available) throw new Error('YouTube sync is not configured.');

  const body = new URLSearchParams({
    code,
    client_id: clientId,
    client_secret: clientSecret,
    redirect_uri: redirectUri,
    grant_type: 'authorization_code',
  });
  const res = await fetchImpl(GOOGLE_TOKEN_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
    cache: 'no-store',
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.access_token) {
    if (data.error === 'invalid_grant') {
      throw new YouTubeReconnectError();
    }
    throw new Error(data.error_description || data.error || 'Failed to exchange YouTube code.');
  }
  const expiresIn = Number(data.expires_in) || 3600;
  return {
    accessToken: data.access_token,
    refreshToken: data.refresh_token || null,
    expiresAt: new Date(Date.now() + Math.max(60, expiresIn - 60) * 1000),
  };
}

export async function refreshYouTubeAccessToken({
  refreshToken,
  env = process.env,
  fetchImpl = fetch,
}) {
  const { available, clientId, clientSecret } = getYouTubeOAuthConfig(env);
  if (!available) throw new Error('YouTube sync is not configured.');

  const body = new URLSearchParams({
    client_id: clientId,
    client_secret: clientSecret,
    refresh_token: refreshToken,
    grant_type: 'refresh_token',
  });
  const res = await fetchImpl(GOOGLE_TOKEN_ENDPOINT, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: body.toString(),
    cache: 'no-store',
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok || !data.access_token) {
    if (data.error === 'invalid_grant') {
      throw new YouTubeReconnectError();
    }
    throw new Error(data.error_description || data.error || 'Failed to refresh YouTube token.');
  }
  const expiresIn = Number(data.expires_in) || 3600;
  return {
    accessToken: data.access_token,
    expiresAt: new Date(Date.now() + Math.max(60, expiresIn - 60) * 1000),
  };
}

export async function revokeYouTubeToken(token, { fetchImpl = fetch } = {}) {
  if (!token || typeof token !== 'string') return false;
  try {
    const res = await fetchImpl(GOOGLE_REVOKE_ENDPOINT, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ token }).toString(),
      cache: 'no-store',
      signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
    });
    return res.ok;
  } catch {
    return false;
  }
}

export function isYouTubeCacheFresh(conn, now = Date.now()) {
  if (!conn?.lastSyncedAt) return false;
  const syncedMs = new Date(conn.lastSyncedAt).getTime();
  return Number.isFinite(syncedMs) && now - syncedMs < YOUTUBE_SYNC_CACHE_TTL_MS;
}

export function filterLikedMusicVideos(items) {
  if (!Array.isArray(items)) return [];
  const candidates = [];
  for (const item of items) {
    const id = typeof item?.id === 'string' ? item.id.trim() : '';
    if (!VIDEO_ID_PATTERN.test(id)) continue;
    const snippet = item?.snippet || {};
    const title = typeof snippet.title === 'string' ? snippet.title.trim() : '';
    if (!title || title === 'Deleted video' || title === 'Private video') continue;
    const categoryId = String(snippet.categoryId || '');
    const artist = typeof snippet.channelTitle === 'string' ? snippet.channelTitle.trim() : '';
    const thumbnail =
      snippet.thumbnails?.high?.url ||
      snippet.thumbnails?.medium?.url ||
      snippet.thumbnails?.default?.url ||
      `https://i.ytimg.com/vi/${id}/hqdefault.jpg`;
    const durationSeconds = parseYouTubeDuration(item?.contentDetails?.duration);
    const song = { id, title, artist, thumbnail, durationSeconds };

    const isMusicCategory = categoryId === '10';
    const hasMusicKeyword =
      STRONG_MUSIC_REGEX.test(title.normalize('NFC')) ||
      MIX_MUSIC_REGEX.test(title.normalize('NFC'));

    if (!isMusicCategory && !hasMusicKeyword) continue;
    if (filterMusicSongs([song]).length === 0) continue;

    candidates.push(song);
    if (candidates.length >= 50) break;
  }
  return candidates;
}

export function formatPlaylistItems(items) {
  if (!Array.isArray(items)) return [];
  const seen = new Set();
  const rawSongs = [];
  for (const item of items) {
    const snippet = item?.snippet || {};
    const id = item?.contentDetails?.videoId || snippet?.resourceId?.videoId || '';
    if (!VIDEO_ID_PATTERN.test(id) || seen.has(id)) continue;
    const title = typeof snippet.title === 'string' ? snippet.title.trim() : '';
    if (!title || title === 'Deleted video' || title === 'Private video') continue;
    seen.add(id);
    const artist =
      (typeof snippet.videoOwnerChannelTitle === 'string' && snippet.videoOwnerChannelTitle.trim()) ||
      (typeof snippet.channelTitle === 'string' && snippet.channelTitle.trim()) ||
      '';
    const thumbnail =
      snippet.thumbnails?.high?.url ||
      snippet.thumbnails?.medium?.url ||
      snippet.thumbnails?.default?.url ||
      `https://i.ytimg.com/vi/${id}/hqdefault.jpg`;
    rawSongs.push({ id, title, artist, thumbnail, durationSeconds: null });
    if (rawSongs.length >= 50) break;
  }
  return filterMusicSongs(rawSongs);
}

async function fetchYouTubeApiJson(path, accessToken, fetchImpl = fetch) {
  const res = await fetchImpl(`${YOUTUBE_API_BASE}${path}`, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      Accept: 'application/json',
    },
    cache: 'no-store',
    signal: AbortSignal.timeout(FETCH_TIMEOUT_MS),
  });
  const data = await res.json().catch(() => ({}));
  if (res.status === 401) {
    throw new YouTubeReconnectError();
  }
  if (!res.ok) {
    throw new Error(data.error?.message || `YouTube API error (${res.status})`);
  }
  return data;
}

async function markConnectionExpired(conn, YouTubeConnectionModel) {
  const update = {
    status: 'expired',
    encryptedAccessToken: null,
    encryptedRefreshToken: null,
    accessTokenExpiresAt: null,
  };
  if (typeof conn?.save === 'function') {
    Object.assign(conn, update);
    await conn.save();
  } else if (YouTubeConnectionModel && conn?.userId) {
    await YouTubeConnectionModel.updateOne({ userId: conn.userId }, { $set: update });
  }
}

export async function getValidYouTubeAccessToken(
  conn,
  { env = process.env, fetchImpl = fetch, YouTubeConnectionModel } = {},
) {
  const { encryptionKey } = getYouTubeOAuthConfig(env);
  const now = Date.now();
  const expiresMs = conn?.accessTokenExpiresAt
    ? new Date(conn.accessTokenExpiresAt).getTime()
    : 0;

  if (conn?.encryptedAccessToken && expiresMs > now + 60_000) {
    return decryptToken(conn.encryptedAccessToken, encryptionKey);
  }
  if (!conn?.encryptedRefreshToken) {
    await markConnectionExpired(conn, YouTubeConnectionModel);
    throw new YouTubeReconnectError();
  }

  let refreshToken;
  try {
    refreshToken = decryptToken(conn.encryptedRefreshToken, encryptionKey);
  } catch {
    await markConnectionExpired(conn, YouTubeConnectionModel);
    throw new YouTubeReconnectError();
  }

  try {
    const refreshed = await refreshYouTubeAccessToken({ refreshToken, env, fetchImpl });
    const encryptedAccessToken = encryptToken(refreshed.accessToken, encryptionKey);
    const update = {
      encryptedAccessToken,
      accessTokenExpiresAt: refreshed.expiresAt,
      status: 'connected',
    };
    if (typeof conn?.save === 'function') {
      Object.assign(conn, update);
      await conn.save();
    } else if (YouTubeConnectionModel && conn?.userId) {
      await YouTubeConnectionModel.updateOne({ userId: conn.userId }, { $set: update });
    }
    return refreshed.accessToken;
  } catch (error) {
    if (error instanceof YouTubeReconnectError) {
      await markConnectionExpired(conn, YouTubeConnectionModel);
    }
    throw error;
  }
}

export async function syncYouTubeConnection(
  conn,
  { env = process.env, fetchImpl = fetch, YouTubeConnectionModel } = {},
) {
  const accessToken = await getValidYouTubeAccessToken(conn, {
    env,
    fetchImpl,
    YouTubeConnectionModel,
  });

  try {
    const [likedRes, playlistsRes, subsRes] = await Promise.all([
      fetchYouTubeApiJson(
        '/videos?part=snippet,contentDetails&myRating=like&maxResults=50',
        accessToken,
        fetchImpl,
      ),
      fetchYouTubeApiJson(
        '/playlists?part=snippet,contentDetails&mine=true&maxResults=12',
        accessToken,
        fetchImpl,
      ),
      fetchYouTubeApiJson(
        '/subscriptions?part=snippet&mine=true&maxResults=25',
        accessToken,
        fetchImpl,
      ).catch(() => ({ items: [] })),
    ]);

    const likedSongs = filterLikedMusicVideos(likedRes.items || []);

    const rawPlaylists = Array.isArray(playlistsRes.items) ? playlistsRes.items.slice(0, 12) : [];
    const playlists = [];
    for (let index = 0; index < rawPlaylists.length; index += 1) {
      const pl = rawPlaylists[index];
      const plId = typeof pl?.id === 'string' ? pl.id.trim() : '';
      const name = typeof pl?.snippet?.title === 'string' ? pl.snippet.title.trim() : '';
      if (!plId || !name) continue;
      let songs = [];
      if (index < 8) {
        try {
          const itemsData = await fetchYouTubeApiJson(
            `/playlistItems?part=snippet,contentDetails&playlistId=${encodeURIComponent(plId)}&maxResults=50`,
            accessToken,
            fetchImpl,
          );
          songs = formatPlaylistItems(itemsData.items || []);
        } catch (err) {
          if (err instanceof YouTubeReconnectError) throw err;
          songs = [];
        }
      }
      const thumbnail =
        pl.snippet?.thumbnails?.high?.url ||
        pl.snippet?.thumbnails?.medium?.url ||
        pl.snippet?.thumbnails?.default?.url ||
        songs[0]?.thumbnail ||
        '';
      playlists.push({
        id: plId,
        name,
        itemCount: songs.length || Number(pl.contentDetails?.itemCount) || 0,
        thumbnail,
        songs,
      });
    }

    const subscribedArtists = [];
    const seenSubs = new Set();
    for (const item of subsRes.items || []) {
      const title = typeof item?.snippet?.title === 'string' ? item.snippet.title.trim() : '';
      if (!title || title.length > 100) continue;
      const lower = title.toLowerCase();
      if (seenSubs.has(lower)) continue;
      seenSubs.add(lower);
      subscribedArtists.push(title);
      if (subscribedArtists.length >= 15) break;
    }

    const allSongsForRanking = [
      ...likedSongs,
      ...playlists.flatMap((pl) => pl.songs || []),
    ];
    const topArtists = rankArtists(allSongsForRanking, 3);
    const lastSyncedAt = new Date();

    const snapshot = {
      status: 'connected',
      lastSyncedAt,
      likedSongs,
      playlists,
      subscribedArtists,
      topArtists,
    };

    if (typeof conn?.save === 'function') {
      Object.assign(conn, snapshot);
      await conn.save();
    } else if (YouTubeConnectionModel && conn?.userId) {
      await YouTubeConnectionModel.updateOne({ userId: conn.userId }, { $set: snapshot });
    }

    return { ...conn, ...snapshot };
  } catch (error) {
    if (error instanceof YouTubeReconnectError) {
      await markConnectionExpired(conn, YouTubeConnectionModel);
    }
    throw error;
  }
}

export function formatYouTubeStatus(conn, available) {
  if (!available) {
    return {
      available: false,
      connected: false,
      needsReconnect: false,
      lastSyncedAt: null,
      likedCount: 0,
      playlistCount: 0,
    };
  }
  if (!conn) {
    return {
      available: true,
      connected: false,
      needsReconnect: false,
      lastSyncedAt: null,
      likedCount: 0,
      playlistCount: 0,
    };
  }
  const expired = conn.status === 'expired';
  return {
    available: true,
    connected: !expired,
    needsReconnect: expired,
    lastSyncedAt: conn.lastSyncedAt ? new Date(conn.lastSyncedAt).toISOString() : null,
    likedCount: Array.isArray(conn.likedSongs) ? conn.likedSongs.length : 0,
    playlistCount: Array.isArray(conn.playlists) ? conn.playlists.length : 0,
  };
}

function formatCollectionSong(song) {
  return {
    id: song.id,
    title: song.title,
    artist: song.artist || '',
    thumbnail: song.thumbnail || `https://i.ytimg.com/vi/${song.id}/hqdefault.jpg`,
    sourceUrl: `https://www.youtube.com/watch?v=${song.id}`,
    source: 'youtube',
    durationSeconds: song.durationSeconds ?? null,
  };
}

export function buildCollectionsPayload(conn) {
  if (!conn || conn.status === 'expired') {
    return {
      connected: false,
      needsReconnect: conn?.status === 'expired',
      lastSyncedAt: conn?.lastSyncedAt ? new Date(conn.lastSyncedAt).toISOString() : null,
      likedPlaylist: null,
      playlists: [],
    };
  }
  const likedSongs = (conn.likedSongs || []).map(formatCollectionSong);
  const likedPlaylist = {
    id: 'yt_liked',
    name: 'Nhạc đã thích',
    source: 'youtube',
    isLiked: true,
    readOnly: true,
    itemCount: likedSongs.length,
    thumbnail: likedSongs[0]?.thumbnail || '',
    songs: likedSongs,
  };
  const playlists = (conn.playlists || []).map((pl) => ({
    id: `yt_${pl.id}`,
    youtubeId: pl.id,
    name: pl.name,
    source: 'youtube',
    isLiked: false,
    readOnly: true,
    itemCount: pl.songs?.length || pl.itemCount || 0,
    thumbnail: pl.thumbnail || pl.songs?.[0]?.thumbnail || '',
    songs: (pl.songs || []).map(formatCollectionSong),
  }));
  return {
    connected: true,
    needsReconnect: false,
    lastSyncedAt: conn.lastSyncedAt ? new Date(conn.lastSyncedAt).toISOString() : null,
    likedPlaylist,
    playlists,
  };
}

export async function buildForYouPayload(
  conn,
  { getSongs = getYouTubeSongs } = {},
) {
  if (!conn || conn.status === 'expired') {
    return {
      connected: false,
      needsReconnect: conn?.status === 'expired',
      sections: [],
    };
  }
  const likedSongs = (conn.likedSongs || []).slice(0, 20).map(formatCollectionSong);
  const heardIds = new Set(likedSongs.map((s) => s.id));

  const topArtists = (conn.topArtists || []).slice(0, 2);
  const recentLists = [];
  for (const artist of topArtists) {
    const page = await getSongs(`${artist} official audio`, '', 'relevance', 8);
    if (page && !page.unavailable && Array.isArray(page.items)) {
      recentLists.push(excludeHeard(page.items, heardIds));
    }
  }
  const tasteSongs = mergeUnique(recentLists, 16).map(formatCollectionSong);

  const subArtists = (conn.subscribedArtists || [])
    .filter((name) => !topArtists.some((top) => top.toLowerCase() === name.toLowerCase()))
    .slice(0, 2);
  const effectiveSubs = subArtists.length > 0 ? subArtists : (conn.subscribedArtists || []).slice(0, 2);
  const subLists = [];
  for (const artist of effectiveSubs) {
    const page = await getSongs(`${artist} music`, '', 'date', 8);
    if (page && !page.unavailable && Array.isArray(page.items)) {
      subLists.push(page.items);
    }
  }
  const subscribedSongs = mergeUnique(subLists, 16).map(formatCollectionSong);

  return {
    connected: true,
    needsReconnect: false,
    sections: [
      {
        id: 'liked',
        eyebrow: 'YÊU THÍCH CỦA BẠN',
        title: 'Nhạc bạn đã thích',
        items: likedSongs,
      },
      {
        id: 'taste',
        eyebrow: 'DỰA TRÊN GU NGHE',
        title: 'Hợp gu nghe gần đây',
        items: tasteSongs,
      },
      {
        id: 'subscribed',
        eyebrow: 'KÊNH BẠN ĐĂNG KÝ',
        title: 'Từ nghệ sĩ bạn theo dõi',
        items: subscribedSongs,
      },
    ],
  };
}
