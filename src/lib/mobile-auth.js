import { createHash, randomBytes } from 'node:crypto';

const proofPattern = /^[A-Za-z0-9_-]{43}$/;
export const mobileWebsiteOrigin = 'https://bc-music-gilt.vercel.app';
export const mobileProof = (value) => typeof value === 'string' && proofPattern.test(value);
export const hashMobileProof = (value) => createHash('sha256').update(value).digest('base64url');
export const newMobileCode = () => randomBytes(32).toString('base64url');

export function mobileSessionCookieName(request, useSecureCookies) {
  const configured = process.env.NEXTAUTH_URL;
  const protocol = request.headers.get('x-forwarded-proto') || new URL(request.url).protocol.slice(0, -1);
  const secure = useSecureCookies ?? (configured ? !configured.startsWith('http://') : protocol === 'https');
  return `${secure ? '__Secure-' : ''}next-auth.session-token`;
}

export function mobileAuthResponse(body, status = 200) {
  return Response.json(body, { status, headers: { 'Cache-Control': 'no-store' } });
}

export async function readMobileAuthInput(request) {
  if (!request.headers.get('content-type')?.toLowerCase().startsWith('application/json')) return null;
  const reader = request.body?.getReader();
  if (!reader) return null;
  const decoder = new TextDecoder('utf-8', { fatal: true });
  let body = '';
  let size = 0;
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > 2048) {
        await reader.cancel();
        return null;
      }
      body += decoder.decode(value, { stream: true });
    }
    return JSON.parse(body + decoder.decode());
  } catch {
    return null;
  } finally {
    reader.releaseLock();
  }
}
