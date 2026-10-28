import { lyricsSearchParameters, selectLyrics } from './lyrics';
import { requestLyricsJson } from './lyrics-request';
import { lookupOvhLyrics } from './lyrics-ovh';

async function requestLyrics(path, parameters, signal) {
  const url = new URL(path, 'https://lrclib.net');
  url.search = new URLSearchParams(parameters).toString();
  return requestLyricsJson(url, {
    headers: { 'Lrclib-Client': 'BCMusic/0.1.0' },
    signal,
  });
}

async function lookupLrclib(metadata) {
  const parameters = { track_name: metadata.title, artist_name: metadata.artist };
  let exact = null;
  try {
    exact = await requestLyrics('/api/get', {
      ...parameters, ...(metadata.duration > 0 ? { duration: String(metadata.duration) } : {}),
    }, AbortSignal.timeout(3000));
  } catch (error) {
    // A failed direct lookup must not suppress a usable search result. Do not
    // fan out when the provider explicitly rejects or rate-limits the request.
    if (error.status && error.status < 500) throw error;
  }
  const result = selectLyrics(exact ? [exact] : [], metadata);
  if (result.status === 'instrumental' || (result.status === 'synced' && result.lines.length > 1)) return result;
  try {
    const candidates = await requestLyrics('/api/search', lyricsSearchParameters(metadata), AbortSignal.timeout(3500));
    return selectLyrics([...(exact ? [exact] : []), ...(Array.isArray(candidates) ? candidates : [])], metadata);
  } catch (error) {
    if (result.status !== 'unavailable') return result;
    throw error;
  }
}

export async function lookupLyrics(metadata) {
  let primary;
  let primaryError;
  try { primary = await lookupLrclib(metadata); }
  catch (error) { primaryError = error; }
  if (primary && primary.status !== 'unavailable') return primary;
  const backup = await lookupOvhLyrics(metadata);
  if (backup) return backup;
  if (primaryError) throw primaryError;
  return primary;
}
