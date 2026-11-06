// Pure helpers for personalized recommendations. They take plain data, so they can be tested without a database.

// Artists in the listener's history, most played first. Empty and placeholder artists are ignored.
export function rankArtists(historyDocs, limit = 2) {
  const counts = new Map();
  for (const doc of historyDocs) {
    const artist = typeof doc?.artist === 'string' ? doc.artist.trim() : '';
    if (!artist || artist.length > 120 || /^unknown/i.test(artist)) continue;
    counts.set(artist, (counts.get(artist) ?? 0) + 1);
  }
  return [...counts.entries()]
    .sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))
    .slice(0, limit)
    .map(([artist]) => artist);
}

// Drops songs the listener already has in history.
export function excludeHeard(songs, heardIds) {
  return songs.filter((song) => song?.id && !heardIds.has(song.id));
}

// Interleaves several result lists and removes duplicates, up to max songs.
export function mergeUnique(lists, max) {
  const seen = new Set();
  const merged = [];
  const longest = Math.max(0, ...lists.map((list) => list.length));
  for (let index = 0; index < longest; index += 1) {
    for (const list of lists) {
      const song = list[index];
      if (!song?.id || seen.has(song.id)) continue;
      seen.add(song.id);
      merged.push(song);
      if (merged.length >= max) return merged;
    }
  }
  return merged;
}
