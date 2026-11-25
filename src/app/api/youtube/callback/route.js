import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import {
  YOUTUBE_MOBILE_CALLBACK,
  YOUTUBE_STATE_COOKIE,
  encryptToken,
  exchangeYouTubeCode,
  getAppOrigin,
  getYouTubeRedirectUri,
  isYouTubeSyncAvailable,
  noncesMatch,
  syncYouTubeConnection,
  verifyYouTubeState,
} from '@/lib/youtube-sync';
import YouTubeConnection from '@/models/YouTubeConnection';

function readCookie(request, name) {
  const fromNext = request.cookies?.get?.(name)?.value;
  if (fromNext) return fromNext;
  const header = request.headers?.get?.('cookie') || '';
  for (const part of header.split(';')) {
    const [k, ...rest] = part.trim().split('=');
    if (k === name) return decodeURIComponent(rest.join('='));
  }
  return '';
}

function finishRedirect(request, source, ok, reason = '') {
  const target = source === 'mobile'
    ? `${YOUTUBE_MOBILE_CALLBACK}?status=${ok ? 'ok' : 'error'}${reason ? `&reason=${encodeURIComponent(reason)}` : ''}`
    : `${getAppOrigin(request)}/profile?youtube=${ok ? 'connected' : 'error'}`;
  const response = NextResponse.redirect(target, {
    status: 302,
    headers: { 'Cache-Control': 'no-store' },
  });
  response.cookies.set(YOUTUBE_STATE_COOKIE, '', {
    httpOnly: true,
    sameSite: 'lax',
    path: '/api/youtube/callback',
    maxAge: 0,
  });
  return response;
}

export async function GET(request) {
  const url = new URL(request.url);
  const stateParam = url.searchParams.get('state');
  const code = url.searchParams.get('code');
  const oauthError = url.searchParams.get('error');

  if (!isYouTubeSyncAvailable()) {
    return NextResponse.json(
      { success: false, available: false, message: 'Tính năng đồng bộ YouTube chưa được bật.' },
      { status: 503, headers: { 'Cache-Control': 'no-store' } },
    );
  }

  const parsedState = verifyYouTubeState(stateParam);
  const source = parsedState?.source || 'web';

  if (oauthError) {
    return finishRedirect(request, source, false, 'denied');
  }

  const cookieNonce = readCookie(request, YOUTUBE_STATE_COOKIE);
  if (!parsedState || !code || !noncesMatch(cookieNonce, parsedState.nonce)) {
    return finishRedirect(request, source, false, 'invalid_state');
  }

  try {
    const redirectUri = getYouTubeRedirectUri(request);
    const tokens = await exchangeYouTubeCode({ code, redirectUri });

    await dbConnect();
    const existing = await YouTubeConnection.findOne({ userId: parsedState.userId });
    const update = {
      userId: parsedState.userId,
      encryptedAccessToken: encryptToken(tokens.accessToken),
      accessTokenExpiresAt: tokens.expiresAt,
      status: 'connected',
    };
    if (tokens.refreshToken) {
      update.encryptedRefreshToken = encryptToken(tokens.refreshToken);
    } else if (existing?.encryptedRefreshToken) {
      update.encryptedRefreshToken = existing.encryptedRefreshToken;
    }

    const conn = await YouTubeConnection.findOneAndUpdate(
      { userId: parsedState.userId },
      { $set: update },
      { upsert: true, returnDocument: 'after' },
    );

    try {
      await syncYouTubeConnection(conn, { YouTubeConnectionModel: YouTubeConnection });
    } catch (syncError) {
      console.warn('Initial YouTube sync failed:', syncError?.name || 'error');
    }

    return finishRedirect(request, source, true);
  } catch (error) {
    console.error('YouTube callback error:', error);
    return finishRedirect(request, source, false, 'exchange_failed');
  }
}
