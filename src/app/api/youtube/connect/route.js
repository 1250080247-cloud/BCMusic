import { randomBytes } from 'node:crypto';
import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import { getRequestUserId } from '@/lib/request-user';
import { hashMobileProof, mobileProof, newMobileCode } from '@/lib/mobile-auth';
import {
  YOUTUBE_CONNECT_GRANT_TTL_MS,
  YOUTUBE_STATE_COOKIE,
  buildYouTubeAuthUrl,
  getAppOrigin,
  getYouTubeRedirectUri,
  isYouTubeSyncAvailable,
  signYouTubeState,
} from '@/lib/youtube-sync';
import YouTubeConnectGrant from '@/models/YouTubeConnectGrant';

// POST /api/youtube/connect — authenticated mobile clients mint a short-lived
// single-use handoff grant so Android Custom Tabs can initiate OAuth cleanly.
export async function POST(request) {
  try {
    if (!isYouTubeSyncAvailable()) {
      return NextResponse.json(
        { success: false, available: false, message: 'Tính năng đồng bộ YouTube chưa được bật.' },
        { status: 503, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    const userId = await getRequestUserId({ allowGuest: false });
    if (!userId) {
      return NextResponse.json(
        { success: false, message: 'Chưa đăng nhập.' },
        { status: 401, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    await dbConnect();
    const grant = newMobileCode();
    await YouTubeConnectGrant.create({
      _id: hashMobileProof(grant),
      userId: String(userId),
      expiresAt: new Date(Date.now() + YOUTUBE_CONNECT_GRANT_TTL_MS),
    });

    const origin = getAppOrigin(request);
    const connectUrl = `${origin}/api/youtube/connect?grant=${encodeURIComponent(grant)}&source=mobile`;
    return NextResponse.json(
      { success: true, url: connectUrl },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch (error) {
    console.error('YouTube connect grant error:', error);
    return NextResponse.json(
      { success: false, message: 'Không tạo được phiên kết nối YouTube.' },
      { status: 500, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}

// GET /api/youtube/connect — initiates separate-project Google OAuth (youtube.readonly).
export async function GET(request) {
  try {
    if (!isYouTubeSyncAvailable()) {
      return NextResponse.json(
        { success: false, available: false, message: 'Tính năng đồng bộ YouTube chưa được bật.' },
        { status: 503, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    const url = new URL(request.url);
    const source = url.searchParams.get('source') === 'mobile' ? 'mobile' : 'web';
    const grantParam = url.searchParams.get('grant');

    let userId = await getRequestUserId({ allowGuest: false });
    if (!userId && source === 'mobile' && mobileProof(grantParam)) {
      await dbConnect();
      const consumed = await YouTubeConnectGrant.findOneAndDelete({
        _id: hashMobileProof(grantParam),
        expiresAt: { $gt: new Date() },
      }).lean();
      if (consumed?.userId) {
        userId = String(consumed.userId);
      }
    }

    if (!userId) {
      return NextResponse.json(
        { success: false, message: 'Chưa đăng nhập.' },
        { status: 401, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    const nonce = randomBytes(16).toString('base64url');
    const state = signYouTubeState({ userId: String(userId), source, nonce });
    const redirectUri = getYouTubeRedirectUri(request);
    const authUrl = buildYouTubeAuthUrl({ redirectUri, state });

    const response = NextResponse.redirect(authUrl, {
      status: 302,
      headers: { 'Cache-Control': 'no-store' },
    });
    const secure = getAppOrigin(request).startsWith('https://');
    response.cookies.set(YOUTUBE_STATE_COOKIE, nonce, {
      httpOnly: true,
      secure,
      sameSite: 'lax',
      path: '/api/youtube/callback',
      maxAge: 600,
    });
    return response;
  } catch (error) {
    console.error('YouTube connect error:', error);
    return NextResponse.json(
      { success: false, message: 'Không mở được trang cấp quyền YouTube.' },
      { status: 500, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
