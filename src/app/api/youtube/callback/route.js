import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import { hashMobileProof } from '@/lib/mobile-auth';
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
import YouTubeConnectGrant from '@/models/YouTubeConnectGrant';
import YouTubeConnection from '@/models/YouTubeConnection';

function escapeHtml(text) {
  return String(text || '')
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&#39;');
}

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

function describeReason(reason) {
  switch (reason) {
    case 'denied':
      return 'Bạn đã hủy cấp quyền đọc YouTube.';
    case 'invalid_state':
      return 'Phiên xác thực đã hết hạn hoặc không khớp. Hãy thử kết nối lại từ ứng dụng BCMusic.';
    case 'exchange_failed':
      return 'Không đổi được mã xác thực Google. Kiểm tra YOUTUBE_OAUTH_CLIENT_ID / SECRET và Redirect URI trên Google Cloud.';
    default:
      return reason || 'Kết nối YouTube chưa hoàn tất. Hãy thử lại.';
  }
}

function finishRedirect(request, source, ok, reason = '', summary = '') {
  const clearCookie = (response) => {
    response.cookies.set(YOUTUBE_STATE_COOKIE, '', {
      httpOnly: true,
      sameSite: 'lax',
      path: '/',
      maxAge: 0,
    });
    return response;
  };

  if (source === 'mobile') {
    const deepLink = `${YOUTUBE_MOBILE_CALLBACK}?status=${ok ? 'ok' : 'error'}${reason ? `&reason=${encodeURIComponent(reason)}` : ''}`;
    const title = ok ? 'Đã kết nối YouTube!' : 'Chưa kết nối được YouTube';
    const detail = ok
      ? (summary || 'Tài khoản YouTube của bạn đã được liên kết với BCMusic.')
      : describeReason(reason);
    const html = `<!doctype html>
<html lang="vi">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width,initial-scale=1" />
  <title>${escapeHtml(title)}</title>
  <style>
    body{margin:0;min-height:100vh;display:flex;align-items:center;justify-content:center;background:#0b0d14;color:#f4f5fa;font-family:system-ui,-apple-system,sans-serif;padding:24px}
    .card{max-width:400px;width:100%;background:linear-gradient(145deg,#2d1822,#191927);border:1px solid rgba(255,92,112,.35);border-radius:22px;padding:26px;text-align:center}
    h1{font-size:20px;margin:0 0 10px}
    p{font-size:14px;line-height:1.5;color:#c9c4d6;margin:0 0 20px}
    .btn{display:block;padding:13px 18px;border-radius:999px;background:#d9ccf6;color:#211a31;font-weight:700;text-decoration:none;font-size:14px}
  </style>
</head>
<body>
  <div class="card">
    <h1>${escapeHtml(title)}</h1>
    <p>${escapeHtml(detail)}</p>
    <a class="btn" href="${escapeHtml(deepLink)}">Quay lại BCMusic</a>
  </div>
  ${ok ? `<script>setTimeout(function(){window.location.replace(${JSON.stringify(deepLink)});},180);</script>` : ''}
</body>
</html>`;
    const response = new NextResponse(html, {
      status: 200,
      headers: {
        'Content-Type': 'text/html; charset=utf-8',
        'Cache-Control': 'no-store',
      },
    });
    return clearCookie(response);
  }

  const target = `${getAppOrigin(request)}/profile?youtube=${ok ? 'connected' : 'error'}${!ok && reason ? `&reason=${encodeURIComponent(reason)}` : ''}`;
  const response = NextResponse.redirect(target, {
    status: 302,
    headers: { 'Cache-Control': 'no-store' },
  });
  return clearCookie(response);
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

  if (!parsedState || !code) {
    return finishRedirect(request, source, false, 'invalid_state');
  }

  const cookieNonce = readCookie(request, YOUTUBE_STATE_COOKIE);
  let nonceVerified = noncesMatch(cookieNonce, parsedState.nonce);

  await dbConnect();
  const consumedState = await YouTubeConnectGrant.findOneAndDelete({
    _id: hashMobileProof(`ytstate:${parsedState.nonce}`),
    userId: parsedState.userId,
    expiresAt: { $gt: new Date() },
  }).lean().catch(() => null);
  if (consumedState?.userId === parsedState.userId) {
    nonceVerified = true;
  }

  if (!nonceVerified) {
    return finishRedirect(request, source, false, 'invalid_state');
  }

  try {
    const redirectUri = getYouTubeRedirectUri(request);
    const tokens = await exchangeYouTubeCode({ code, redirectUri });

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

    let conn = await YouTubeConnection.findOneAndUpdate(
      { userId: parsedState.userId },
      { $set: update },
      { upsert: true, returnDocument: 'after' },
    );

    let summary = '';
    try {
      conn = await syncYouTubeConnection(conn, { YouTubeConnectionModel: YouTubeConnection });
      const likedCount = Array.isArray(conn?.likedSongs) ? conn.likedSongs.length : 0;
      const playlistCount = Array.isArray(conn?.playlists) ? conn.playlists.length : 0;
      summary = `Đã đồng bộ ${likedCount} bài đã thích và ${playlistCount} playlist từ YouTube.`;
    } catch (syncError) {
      console.warn('Initial YouTube sync failed:', syncError?.message || syncError?.name || 'error');
    }

    return finishRedirect(request, source, true, '', summary);
  } catch (error) {
    console.error('YouTube callback error:', error);
    return finishRedirect(request, source, false, 'exchange_failed');
  }
}
