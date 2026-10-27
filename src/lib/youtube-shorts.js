// The Data API has no public isShort flag. Resolve the public Shorts URL instead
// of guessing from a song's length: ordinary videos can be shorter than 2:30.
const classificationCache = new Map();
const CACHE_LIMIT = 1000;
const KNOWN_TTL_MS = 24 * 60 * 60 * 1000;
const UNKNOWN_TTL_MS = 30 * 1000;
const BATCH_BUDGET_MS = 3500;
const REQUEST_TIMEOUT_MS = 1500;
const VIDEO_ID = /^[A-Za-z0-9_-]{11}$/;

export function parseYouTubeDuration(value) {
  if (typeof value !== 'string' || value.length > 64) return null;
  const match = value.match(/^P(?:(\d+)D)?(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$/);
  if (!match || !match.slice(1).some(Boolean)) return null;
  const seconds = Number(match[1] || 0) * 86400 + Number(match[2] || 0) * 3600
    + Number(match[3] || 0) * 60 + Number(match[4] || 0);
  return Number.isFinite(seconds) ? seconds : null;
}

function remember(id, isShort) {
  if (classificationCache.size >= CACHE_LIMIT && !classificationCache.has(id)) {
    classificationCache.delete(classificationCache.keys().next().value);
  }
  classificationCache.set(id, {
    isShort,
    expiresAt: Date.now() + (isShort === null ? UNKNOWN_TTL_MS : KNOWN_TTL_MS),
  });
}

async function classifyShort(id, timeout) {
  try {
    const response = await fetch(`https://www.youtube.com/shorts/${id}`, {
      method: 'HEAD', redirect: 'manual', cache: 'no-store',
      signal: AbortSignal.timeout(timeout),
    });
    if ([301, 302, 303, 307, 308].includes(response.status)) {
      const location = response.headers.get('location');
      if (!location) return null;
      const target = new URL(location, 'https://www.youtube.com');
      return target.origin === 'https://www.youtube.com' && target.pathname === '/watch'
        && target.searchParams.get('v') === id ? false : null;
    }
    // A Shorts document stays on /shorts with HTTP 200. Require the YouTube
    // main-app CSP so a consent/challenge HTML page is not treated as a Short.
    // This public routing behavior is best effort, not an official API contract.
    const html = response.headers.get('content-type')?.split(';')[0].trim().toLowerCase() === 'text/html';
    const youtubeDocument = response.headers.get('content-security-policy')?.includes('https://csp.withgoogle.com/csp/youtube_main');
    const length = Number(response.headers.get('content-length'));
    // YouTube normally sends content-length: 0 for HEAD, regardless of page size.
    const plausibleLength = length === 0 || length >= 100000;
    return response.status === 200 && html && youtubeDocument && plausibleLength ? true : null;
  } catch {
    // Network failures, timeouts and blocking must never remove a regular song.
    return null;
  }
}

function longerThanShorts(song) {
  // YouTube currently limits Shorts to 3 minutes. This only avoids unnecessary
  // probes; short-duration videos are never discarded on duration alone.
  return Number.isFinite(song.durationSeconds) && song.durationSeconds > 180;
}

export async function removeYouTubeShorts(songs) {
  const deadline = Date.now() + BATCH_BUDGET_MS;
  const ids = [...new Set(songs.filter(song => VIDEO_ID.test(song.id) && !longerThanShorts(song)).map(song => song.id))].slice(0, 50);
  let cursor = 0;
  await Promise.all(Array.from({ length: Math.min(4, ids.length) }, async () => {
    while (cursor < ids.length) {
      const id = ids[cursor++];
      const cached = classificationCache.get(id);
      if (cached && cached.expiresAt > Date.now()) continue;
      const remaining = deadline - Date.now();
      if (remaining <= 0) break;
      const isShort = await classifyShort(id, Math.max(1, Math.min(REQUEST_TIMEOUT_MS, remaining)));
      remember(id, isShort);
    }
  }));
  return songs.filter(song => {
    if (longerThanShorts(song)) return true;
    const classification = classificationCache.get(song.id);
    return !(classification?.expiresAt > Date.now() && classification.isShort === true);
  });
}
