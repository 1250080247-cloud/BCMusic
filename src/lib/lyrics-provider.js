import { lyricsSearchParameters, selectLyrics } from './lyrics';

async function requestLyrics(path, parameters, signal) {
  const url = new URL(path, 'https://lrclib.net');
  url.search = new URLSearchParams(parameters).toString();
  const response = await fetch(url, {
    headers: { 'Lrclib-Client': 'BCMusic/0.1.0' },
    signal, redirect: 'error', next: { revalidate: 3600 },
  });
  if (response.status === 404) return null;
  if (!response.ok) throw Object.assign(new Error('lyrics_provider_unavailable'), { status: response.status });
  if (Number(response.headers.get('content-length')) > 512000) throw new Error('lyrics_response_too_large');
  const body = await response.text();
  if (body.length > 512000) throw new Error('lyrics_response_too_large');
  return JSON.parse(body);
}

export async function lookupLyrics(metadata) {
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
