import { readJsonResponse } from './read-json-response';

export async function requestLyricsJson(url, { signal, headers } = {}) {
  if (!['https://lrclib.net', 'https://api.lyrics.ovh'].includes(url.origin)) throw new Error('invalid_lyrics_provider');
  const response = await fetch(url, { headers, signal, redirect: 'error', next: { revalidate: 3600 } });
  if (response.status === 404) return null;
  if (!response.ok) throw Object.assign(new Error('lyrics_provider_unavailable'), { status: response.status });
  return readJsonResponse(response, 512000);
}
