import { requestLyricsJson } from './lyrics-request';

export async function lookupOvhLyrics({ title, artist }) {
  if ([title, artist].some(value => typeof value !== 'string' || !value.trim() || value.length > 250 || /^\.+$/.test(value.trim()))) return null;
  // Preserve version labels and the full artist credits. This provider supplies
  // plain text only, without recording metadata or verified timing information.
  const url = new URL(`https://api.lyrics.ovh/v1/${encodeURIComponent(artist)}/${encodeURIComponent(title)}`);
  const data = await requestLyricsJson(url, { signal: AbortSignal.timeout(3000) });
  if (data === null) return null;
  if (data.error || typeof data.lyrics !== 'string' || !data.lyrics.trim() || data.lyrics.length > 80000) throw new Error('invalid_lyrics_response');
  return { status: 'plain', source: 'lyrics.ovh', plainLyrics: data.lyrics.trim(), lines: [] };
}
