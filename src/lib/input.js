// Pure request-body and field helpers shared by API routes.

// Keep in sync with the Android app (mobile/android/.../AccountClient.kt), which validates titles up to 500.
export const LIMITS = {
  text: 300,
  title: 500,
  id: 128,
  name: 100,
  lyrics: 80000,
  playlistSongs: 500,
  playlistsPerUser: 200,
  query: 200,
};

// Reads a JSON body only when the client declares it. Browsers cannot send this
// content type cross-site without a CORS preflight, which blocks form-based CSRF.
// Returns undefined for the wrong content type, null for malformed JSON.
export async function readJsonBody(request) {
  if (!request.headers.get('content-type')?.toLowerCase().startsWith('application/json')) return undefined;
  try {
    return await request.json();
  } catch {
    return null;
  }
}

// Trimmed string within max length, or undefined.
export function boundedText(value, max) {
  if (typeof value !== 'string') return undefined;
  const trimmed = value.trim();
  return trimmed && trimmed.length <= max ? trimmed : undefined;
}

// Optional string truncated to max length. Non-strings become undefined.
export function optionalText(value, max) {
  return typeof value === 'string' ? value.slice(0, max) : undefined;
}

// Integer from a query parameter, clamped to [min, max]. Missing or non-numeric values get fallback.
export function clampInteger(value, min, max, fallback) {
  const parsed = Number.parseInt(value ?? '', 10);
  return Number.isFinite(parsed) ? Math.min(max, Math.max(min, parsed)) : fallback;
}

// Mongo ObjectId string check used for playlist IDs.
export const isObjectIdString = (value) => typeof value === 'string' && /^[a-f0-9]{24}$/i.test(value);
