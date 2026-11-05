import { encode } from 'next-auth/jwt';
import { NextResponse } from 'next/server';
import { authOptions } from '@/lib/auth';
import dbConnect from '@/lib/mongodb';
import { hashMobileProof, mobileAuthResponse, mobileProof, mobileSessionCookieName, readMobileAuthInput } from '@/lib/mobile-auth';
import MobileAuthGrant from '@/models/MobileAuthGrant';
import User from '@/models/User';

export function GET() {
  return mobileAuthResponse({
    google: Boolean(authOptions.secret && process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET),
  });
}

export async function POST(request) {
  if (!authOptions.secret) return mobileAuthResponse({ error: 'unavailable' }, 503);
  const input = await readMobileAuthInput(request);
  if (!mobileProof(input?.code) || !mobileProof(input?.state) || !mobileProof(input?.verifier))
    return mobileAuthResponse({ error: 'invalid_request' }, 400);

  try {
    await dbConnect();
    const grant = await MobileAuthGrant.findOneAndDelete({
      _id: hashMobileProof(input.code),
      state: input.state,
      challenge: hashMobileProof(input.verifier),
      expiresAt: { $gt: new Date() },
    }).lean();
    if (!grant) return mobileAuthResponse({ error: 'invalid_grant' }, 401);

    const user = await User.findById(grant.userId).select('username displayName email').lean();
    if (!user) return mobileAuthResponse({ error: 'invalid_grant' }, 401);
    const userId = String(user._id);
    const maxAge = authOptions.session.maxAge ?? 30 * 24 * 60 * 60;
    const token = await encode({
      secret: authOptions.secret,
      maxAge,
      token: {
        sub: userId, userId, username: user.username, name: user.displayName || user.username,
        email: user.email, picture: `/api/user/avatar?userId=${userId}`,
      },
    });
    const response = NextResponse.json({ success: true }, { headers: { 'Cache-Control': 'no-store' } });
    response.cookies.set(mobileSessionCookieName(request, authOptions.useSecureCookies), token, {
      httpOnly: true, secure: true, sameSite: 'lax', path: '/', maxAge,
    });
    return response;
  } catch {
    return mobileAuthResponse({ error: 'unavailable' }, 503);
  }
}
