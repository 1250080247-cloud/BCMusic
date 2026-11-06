// Pure URL checks shared by API routes (server) and components (client).
// Stored URLs become iframe sources and links, so only https URLs on known hosts pass.

const MAX_URL_LENGTH = 2048;

// SoundCloud Widget player URLs. These are the only iframe sources BCMusic creates.
const EMBED_HOSTS = new Set(['w.soundcloud.com']);

// Public pages that a user can open from a song or playlist.
const SOURCE_HOSTS = new Set([
  'soundcloud.com', 'www.soundcloud.com', 'm.soundcloud.com', 'on.soundcloud.com',
  'youtube.com', 'www.youtube.com', 'm.youtube.com', 'music.youtube.com', 'youtu.be',
]);

function parseHttpsUrl(value) {
  if (typeof value !== 'string' || !value || value.length > MAX_URL_LENGTH) return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password ? url : null;
  } catch {
    return null;
  }
}

export function safeEmbedUrl(value) {
  const url = parseHttpsUrl(value);
  return url && EMBED_HOSTS.has(url.hostname) ? url.toString() : null;
}

// Any https URL, for images (thumbnails, avatars) that are rendered but never executed.
export function safeHttpsUrl(value) {
  const url = parseHttpsUrl(value);
  return url ? url.toString() : null;
}

export function safeSourceUrl(value) {
  const url = parseHttpsUrl(value);
  return url && SOURCE_HOSTS.has(url.hostname) ? url.toString() : null;
}

// Keeps only URLs that are safe to store. Invalid values become undefined so Mongoose skips them.
export function cleanTrackUrls(song) {
  return {
    embedUrl: safeEmbedUrl(song?.embedUrl) ?? undefined,
    sourceUrl: safeSourceUrl(song?.sourceUrl) ?? undefined,
  };
}
