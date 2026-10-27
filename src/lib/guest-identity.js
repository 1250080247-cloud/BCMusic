import { createHmac, randomBytes, timingSafeEqual } from 'node:crypto';

export const GUEST_COOKIE = 'bcmusic-guest';

function sign(id, secret) {
  return createHmac('sha256', secret).update(`bcmusic-guest:v1:${id}`).digest('base64url');
}

export function createGuestToken(secret) {
  if (!secret) throw new Error('NEXTAUTH_SECRET is required for guest identity.');
  const id = randomBytes(24).toString('base64url');
  return `${id}.${sign(id, secret)}`;
}

export function readGuestId(token, secret) {
  if (!secret || typeof token !== 'string') return null;
  const match = token.match(/^([\w-]{32})\.([\w-]{43})$/);
  if (!match) return null;
  const expected = Buffer.from(sign(match[1], secret));
  const supplied = Buffer.from(match[2]);
  return timingSafeEqual(expected, supplied) ? `guest:${match[1]}` : null;
}
