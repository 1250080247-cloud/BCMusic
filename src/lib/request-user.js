import { getServerSession } from 'next-auth';
import { cookies } from 'next/headers';
import { authOptions } from '@/lib/auth';
import { GUEST_COOKIE, readGuestId } from '@/lib/guest-identity';

export async function getRequestUserId({ allowGuest = false } = {}) {
  const session = await getServerSession(authOptions);
  if (session?.user?.id) return session.user.id;
  if (!allowGuest) return null;
  const cookieStore = await cookies();
  return readGuestId(cookieStore.get(GUEST_COOKIE)?.value, process.env.NEXTAUTH_SECRET);
}
