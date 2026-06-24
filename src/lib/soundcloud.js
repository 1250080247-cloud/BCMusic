/**
 * SoundCloud integration via oEmbed API (FREE — no API key required).
 *
 * This module resolves public SoundCloud URLs into metadata objects
 * that BCMusic can display and play using the SoundCloud Widget API.
 */

/**
 * Resolve a SoundCloud track/playlist URL into metadata via oEmbed.
 * @param {string} scUrl - A public SoundCloud URL (e.g. https://soundcloud.com/artist/track)
 * @returns {Promise<object>} Resolved track metadata
 */
export async function resolveSoundCloudUrl(scUrl) {
  const oembedEndpoint = `https://soundcloud.com/oembed?format=json&url=${encodeURIComponent(scUrl)}`;

  const res = await fetch(oembedEndpoint, { cache: 'no-store' });

  if (!res.ok) {
    const text = await res.text().catch(() => '');
    throw new Error(`SoundCloud oEmbed failed (${res.status}): ${text}`);
  }

  const data = await res.json();

  // Extract the track/playlist ID from the embed HTML
  // The iframe src contains: api.soundcloud.com/tracks/<ID> or api.soundcloud.com/playlists/<ID>
  const trackIdMatch = data.html?.match(/tracks%2F(\d+)/);
  const playlistIdMatch = data.html?.match(/playlists%2F(\d+)/);

  // Extract the widget embed URL from the iframe src
  const iframeSrcMatch = data.html?.match(/src="([^"]+)"/);
  const widgetUrl = iframeSrcMatch ? iframeSrcMatch[1] : null;

  const trackId = trackIdMatch ? trackIdMatch[1] : null;
  const playlistId = playlistIdMatch ? playlistIdMatch[1] : null;

  if (!trackId && !playlistId) {
    throw new Error('Could not extract SoundCloud track/playlist ID from oEmbed response.');
  }

  // Build the widget URL for embedding
  // If we got the src from the HTML, use that; otherwise build it manually
  const resourcePath = trackId
    ? `https%3A//api.soundcloud.com/tracks/${trackId}`
    : `https%3A//api.soundcloud.com/playlists/${playlistId}`;

  const embedUrl = widgetUrl || `https://w.soundcloud.com/player/?url=${resourcePath}&auto_play=false&hide_related=true&show_comments=false&show_user=true&show_reposts=false&visual=false`;

  return {
    id: `sc_${trackId || playlistId}`,
    scTrackId: trackId,
    scPlaylistId: playlistId,
    title: data.title || 'Unknown Track',
    artist: data.author_name || 'Unknown Artist',
    thumbnail: data.thumbnail_url ? data.thumbnail_url.replace('-large', '-t500x500') : null,
    sourceUrl: scUrl,
    embedUrl,
    source: 'soundcloud',
  };
}
