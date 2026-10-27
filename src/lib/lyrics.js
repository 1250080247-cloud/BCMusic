import { decodeSongTitle } from './song-title';

const MAX_TEXT = 80000;
const normalize = value => value.normalize('NFKC').toLowerCase().replace(/[^\p{L}\p{N}]+/gu, ' ').trim();

function splitFeaturedTitle(title) {
  const match = title.match(/\s+(?:[[(](?:feat(?:uring)?|ft)\.?\s+([^()[\]]+)[\])]|(?:feat(?:uring)?|ft)\.?\s+([^()[\]]+))$/i);
  return match ? { title: title.slice(0, match.index).trim(), featured: (match[1] || match[2]).trim() } : { title, featured: '' };
}

function artistCredits(artist) {
  return artist.split(/\s*(?:,|&|\bfeat(?:uring)?\.?\s+|\bft\.?\s+)\s*/i).map(value => value.trim()).filter(Boolean);
}

function recordingIdentity(title, artist) {
  const recording = splitFeaturedTitle(title);
  const credits = [...artistCredits(artist), ...artistCredits(recording.featured)];
  return { title: normalize(recording.title), artists: [...new Set(credits.map(normalize))].sort().join('|') };
}

export function lyricsSearchParameters(metadata) {
  return { track_name: splitFeaturedTitle(metadata.title).title, artist_name: artistCredits(metadata.artist)[0] || metadata.artist };
}

export function lyricsMetadata(song, duration = 0) {
  let title = decodeSongTitle(song?.title || '')
    .replace(/\s*[[(](?:official(?:\s+(?:music|lyric))?(?:\s+video)?|official\s+audio|lyrics?|lyric\s+video|music\s+video|(?:hd|4k)(?:\s+remaster(?:ed)?)?|visualizer)[\])]\s*/gi, ' ')
    .replace(/\s*(?:\||[-–—])\s*(?:official(?:\s+(?:music|lyric))?(?:\s+video)?|official\s+audio|lyrics?|lyric\s+video|music\s+video|visualizer)\s*$/i, '').trim();
  let artist = (song?.artist || '').replace(/\s*-\s*Topic$/i, '').replace(/VEVO$/i, '').trim();
  const split = title.match(/^(.+?)\s[-–—]\s(.+)$/);
  if (split) {
    artist = split[1].trim();
    title = split[2].trim();
  }
  const recording = splitFeaturedTitle(title);
  if (recording.featured) artist = [...artistCredits(artist), ...artistCredits(recording.featured)].join(', ');
  return { title: recording.title, artist, duration: Number.isFinite(duration) && duration > 0 ? duration : 0 };
}

export function parseLrc(value) {
  if (typeof value !== 'string' || value.length > MAX_TEXT) return [];
  const lines = [];
  for (const raw of value.split(/\r?\n/).slice(0, 2000)) {
    const stamps = [];
    let remaining = raw.trim();
    let match;
    while ((match = remaining.match(/^\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]/))) {
      const time = Number(match[1]) * 60 + Number(match[2]) + Number(`0.${match[3] || 0}`);
      if (Number(match[2]) < 60 && time < 86400) stamps.push(time);
      remaining = remaining.slice(match[0].length);
    }
    for (const time of stamps) lines.push({ time, text: remaining.trim() });
  }
  return lines.sort((a, b) => a.time - b.time);
}

export function activeLineAt(lines, time) {
  if (!Number.isFinite(time)) return -1;
  let low = 0;
  let high = lines.length - 1;
  while (low <= high) {
    const mid = Math.floor((low + high) / 2);
    if (lines[mid].time <= time) low = mid + 1;
    else high = mid - 1;
  }
  return high;
}

export function selectLyrics(records, metadata) {
  const empty = { status: 'unavailable', source: null, plainLyrics: '', lines: [] };
  if (!Array.isArray(records)) return empty;
  const expected = recordingIdentity(metadata.title, metadata.artist);
  const matches = records.slice(0, 100).filter(track => track
    && typeof track.trackName === 'string' && typeof track.artistName === 'string'
    && recordingIdentity(track.trackName, track.artistName).title === expected.title
    && recordingIdentity(track.trackName, track.artistName).artists === expected.artists
    && [track.plainLyrics, track.syncedLyrics].every(value => value == null || (typeof value === 'string' && value.length <= MAX_TEXT)))
    .map(track => ({ track, parsed: parseLrc(track.syncedLyrics) }));
  const durationMatches = track => metadata.duration > 0 && typeof track.duration === 'number'
    && Math.abs(track.duration - metadata.duration) <= 3;
  matches.sort((a, b) => Number(durationMatches(b.track)) - Number(durationMatches(a.track))
    || b.parsed.length - a.parsed.length
    || (b.track.plainLyrics?.length || 0) - (a.track.plainLyrics?.length || 0));
  const selected = matches[0];
  const track = selected?.track;
  if (!track) return empty;
  if (track.instrumental === true) return { ...empty, status: 'instrumental', source: 'LRCLIB' };
  const parsed = selected.parsed;
  const plainLyrics = track.plainLyrics?.trim() || parsed.map(line => line.text).join('\n').trim();
  const lines = durationMatches(track) ? parsed : [];
  return { status: lines.length ? 'synced' : plainLyrics ? 'plain' : 'unavailable', source: 'LRCLIB', plainLyrics, lines };
}
