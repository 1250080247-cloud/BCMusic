import { NextResponse } from 'next/server';
import { createGuestToken, GUEST_COOKIE, readGuestId } from '@/lib/guest-identity';

export function proxy(request) {
  const secret = process.env.NEXTAUTH_SECRET;
  if (readGuestId(request.cookies.get(GUEST_COOKIE)?.value, secret)) {
    return NextResponse.next();
  }

  const token = createGuestToken(secret);
  // Make the identity available to the very first SSR/API request as well.
  request.cookies.set(GUEST_COOKIE, token);
  const response = NextResponse.next({ request: { headers: request.headers } });
  response.cookies.set(GUEST_COOKIE, token, {
    httpOnly: true,
    sameSite: 'lax',
    secure: process.env.NODE_ENV === 'production',
    path: '/',
    maxAge: 60 * 60 * 24 * 365,
  });
  return response;
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
};
