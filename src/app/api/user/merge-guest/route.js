import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import { getRequestUserId } from '@/lib/request-user';
import { createGuestToken, GUEST_COOKIE, readGuestId } from '@/lib/guest-identity';
import { mergeGuestData } from '@/lib/guest-merge';

// POST /api/user/merge-guest — moves playlists and history created while signed out into the signed-in account.
// Afterwards the guest cookie is replaced, so this browser's next anonymous session starts with no link to the old data.
export async function POST() {
  try {
    const userId = await getRequestUserId();
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }

    const secret = process.env.NEXTAUTH_SECRET;
    const cookieStore = await cookies();
    const guestUserId = readGuestId(cookieStore.get(GUEST_COOKIE)?.value, secret);
    if (!guestUserId) {
      return NextResponse.json({ success: true, merged: null });
    }

    await dbConnect();
    const merged = await mergeGuestData(guestUserId, userId);

    const response = NextResponse.json({ success: true, merged });
    response.cookies.set(GUEST_COOKIE, createGuestToken(secret), {
      httpOnly: true,
      sameSite: 'lax',
      secure: process.env.NODE_ENV === 'production',
      path: '/',
      maxAge: 60 * 60 * 24 * 365,
    });
    return response;
  } catch (error) {
    console.error('Guest merge error:', error);
    return NextResponse.json({ success: false, message: 'Không thể chuyển dữ liệu khách.' }, { status: 500 });
  }
}
