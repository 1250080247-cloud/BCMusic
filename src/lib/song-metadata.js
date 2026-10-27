import SoundCloudTrack from '@/models/SoundCloudTrack';

// Old favorites/history did not store embedUrl. Recover without rewriting records.
export async function restoreSoundCloudMetadata(songs, userId) {
  const missing = songs.filter((song) => song.source === 'soundcloud' && !song.embedUrl);
  if (!missing.length) return songs;

  const tracks = await SoundCloudTrack.find({
    userId,
    scId: { $in: missing.map((song) => song.id) },
  }).lean();
  const byId = new Map(tracks.map((track) => [track.scId, track]));

  return songs.map((song) => {
    if (song.source !== 'soundcloud' || song.embedUrl) return song;
    const track = byId.get(song.id);
    const numericId = song.id?.match(/^sc_(\d+)$/)?.[1];
    const resource = numericId ? `https://api.soundcloud.com/tracks/${numericId}` : null;
    return {
      ...song,
      embedUrl: track?.embedUrl || (resource
        ? `https://w.soundcloud.com/player/?url=${encodeURIComponent(resource)}&auto_play=false`
        : undefined),
      sourceUrl: song.sourceUrl || track?.sourceUrl,
    };
  });
}
