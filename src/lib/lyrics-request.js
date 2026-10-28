const MAX_RESPONSE_BYTES = 512000;

export async function requestLyricsJson(url, { signal, headers } = {}) {
  if (!['https://lrclib.net', 'https://api.lyrics.ovh'].includes(url.origin)) throw new Error('invalid_lyrics_provider');
  const response = await fetch(url, { headers, signal, redirect: 'error', next: { revalidate: 3600 } });
  if (response.status === 404) return null;
  if (!response.ok) throw Object.assign(new Error('lyrics_provider_unavailable'), { status: response.status });
  if (Number(response.headers.get('content-length')) > MAX_RESPONSE_BYTES) {
    await response.body?.cancel();
    throw new Error('lyrics_response_too_large');
  }
  const reader = response.body?.getReader();
  if (!reader) throw new Error('invalid_lyrics_response');
  const decoder = new TextDecoder();
  let bytes = 0;
  let body = '';
  try {
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > MAX_RESPONSE_BYTES) {
        await reader.cancel();
        throw new Error('lyrics_response_too_large');
      }
      body += decoder.decode(value, { stream: true });
    }
    return JSON.parse(body + decoder.decode());
  } finally { reader.releaseLock(); }
}
