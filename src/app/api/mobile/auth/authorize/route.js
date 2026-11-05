import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import dbConnect from '@/lib/mongodb';
import { hashMobileProof, mobileAuthResponse, mobileProof, mobileWebsiteOrigin, newMobileCode, readMobileAuthInput } from '@/lib/mobile-auth';
import MobileAuthGrant from '@/models/MobileAuthGrant';

export async function POST(request) {
  const requestUrl = new URL(request.url);
  const origin = request.headers.get('origin');
  if (origin !== requestUrl.origin &&
      !(origin === mobileWebsiteOrigin && requestUrl.host === new URL(mobileWebsiteOrigin).host))
    return mobileAuthResponse({ error: 'origin' }, 403);
  const input = await readMobileAuthInput(request);
  if (!mobileProof(input?.state) || !mobileProof(input?.challenge))
    return mobileAuthResponse({ error: 'invalid_request' }, 400);

  const session = await getServerSession(authOptions);
  if (!session?.user?.id) return mobileAuthResponse({ error: 'sign_in_required' }, 401);

  const code = newMobileCode();
  try {
    await dbConnect();
    await MobileAuthGrant.create({
      _id: hashMobileProof(code),
      userId: session.user.id,
      state: input.state,
      challenge: input.challenge,
      expiresAt: new Date(Date.now() + 2 * 60_000),
    });
  } catch {
    return mobileAuthResponse({ error: 'unavailable' }, 503);
  }
  return mobileAuthResponse({ code });
}
