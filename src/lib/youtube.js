import dbConnect from '@/lib/mongodb';
import SongCache from '@/models/SongCache';
import { parseYouTubeDuration, filterYouTubeShorts, SHORTS_FILTER_VERSION } from '@/lib/youtube-shorts';

const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour in milliseconds
const inFlight = new Map();
const emptyResult = () => ({ items: [], nextPageToken: null, prevPageToken: null });
const MIN_DURATION_SECONDS = 30;
const aboveMinimumDuration = song => Number.isFinite(song.durationSeconds) && song.durationSeconds > MIN_DURATION_SECONDS;

/**
 * Build a unique cache key from query parameters.
 */
function buildCacheKey(query, order, maxResults, pageToken) {
  // The old namespace contained only 4–20 minute results (videoDuration=medium).
  // Keep those documents intact. Apply the current minimum on every cache read,
  // including entries previously verified only for Shorts.
  return `youtube-no-shorts-v2:${query}__${order}__${maxResults}__${pageToken || 'first'}`;
}

/**
 * Fetch songs from YouTube Data API v3.
 * This is the raw fetch without any caching.
 */
async function fetchFromYouTube(searchQuery, pageToken = '', order = 'relevance', maxResults = 5) {
  const API_KEY = process.env.YOUTUBE_API_KEY;
  if (!API_KEY) return null;

  const tokenParam = pageToken ? `&pageToken=${pageToken}` : '';
  const url = `https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=${maxResults}&q=${encodeURIComponent(searchQuery)}&type=video&order=${order}&key=${API_KEY}${tokenParam}`;

  try {
    const res = await fetch(url, { cache: 'no-store', signal: AbortSignal.timeout(6000) });
    const data = await res.json();

    if (!res.ok) {
      console.error('YouTube API Error:', data.error?.message);
      return null;
    }

    const filteredItems = (data.items || []).filter((item) => item.id?.videoId);

    // Batch view counts and duration metadata in the same Videos API request.
    let viewCounts = {};
    let durations = {};
    const videoIds = filteredItems.map((item) => item.id.videoId).join(',');
    if (videoIds) {
      try {
        const statsUrl = `https://www.googleapis.com/youtube/v3/videos?part=statistics,contentDetails&id=${videoIds}&key=${API_KEY}`;
        const statsRes = await fetch(statsUrl, { cache: 'no-store', signal: AbortSignal.timeout(2500) });
        const statsData = await statsRes.json();
        // Duration is required to enforce the cutoff. Do not cache a provider
        // outage as a successful empty search page.
        if (!statsRes.ok || !Array.isArray(statsData.items)) return null;
        for (const v of statsData.items) {
          viewCounts[v.id] = v.statistics?.viewCount || null;
          durations[v.id] = parseYouTubeDuration(v.contentDetails?.duration);
        }
      } catch (statsError) {
        console.error('YouTube statistics unavailable:', statsError.name);
        return null;
      }
    }

    const formattedItems = filteredItems.map((item) => ({
      id: item.id.videoId,
      title: item.snippet.title,
      artist: item.snippet.channelTitle,
      thumbnail: item.snippet.thumbnails.high?.url || item.snippet.thumbnails.medium?.url,
      publishedAt: item.snippet.publishedAt,
      viewCount: viewCounts[item.id.videoId] || null,
      durationSeconds: durations[item.id.videoId] ?? null,
      source: 'youtube',
    }));

    const filtered = await filterYouTubeShorts(formattedItems.filter(aboveMinimumDuration));
    return {
      items: filtered.items,
      shortsFilterComplete: filtered.complete,
      nextPageToken: data.nextPageToken || null,
      prevPageToken: data.prevPageToken || null,
    };
  } catch (error) {
    console.error('YouTube search unavailable:', error.name);
    return null;
  }
}

/**
 * Read the one-hour MongoDB cache before contacting YouTube. Legacy entries
 * are filtered once without extending their expiry. Verified entries, including
 * successful empty results, need no further provider calls during that hour.
 */
async function loadSongs(cacheKey, searchQuery, pageToken, order, maxResults) {
  let cached = null;
  let cacheAvailable = false;
  try {
    await dbConnect();
    cached = await SongCache.findOne({ cacheKey }).lean();
    cacheAvailable = true;
  } catch {
    console.error('YouTube cache read unavailable; using the provider.');
  }

  if (cached && Date.now() - new Date(cached.cachedAt).getTime() < CACHE_TTL_MS) {
    const verified = cached.shortsFiltered && cached.shortsFilterVersion === SHORTS_FILTER_VERSION;
    const filtered = verified ? { items: cached.songs || [], complete: true } : await filterYouTubeShorts(cached.songs || []);
    const items = filtered.items;
    if (!verified && filtered.complete) {
      try {
        // Keep the original expiry and avoid overwriting a concurrent refresh.
        await SongCache.findOneAndUpdate({ cacheKey, cachedAt: cached.cachedAt }, {
          $set: { songs: items, shortsFiltered: true, shortsFilterVersion: SHORTS_FILTER_VERSION },
        });
      } catch { console.error('YouTube cache metadata update unavailable.'); }
    }
    return { items: items.filter(aboveMinimumDuration), nextPageToken: cached.nextPageToken, prevPageToken: cached.prevPageToken };
  }

  const result = await fetchFromYouTube(searchQuery, pageToken, order, maxResults);
  if (!result) return emptyResult();
  const { shortsFilterComplete, ...page } = result;
  if (cacheAvailable && shortsFilterComplete) {
    try {
      await SongCache.findOneAndUpdate(
        { cacheKey },
        {
          cacheKey,
          query: searchQuery,
          order,
          maxResults,
          songs: result.items,
          shortsFiltered: true,
          shortsFilterVersion: SHORTS_FILTER_VERSION,
          nextPageToken: result.nextPageToken,
          prevPageToken: result.prevPageToken,
          cachedAt: new Date(),
        },
        { upsert: true, returnDocument: 'after' }
      );
    } catch { console.error('YouTube cache write unavailable; returning fetched songs.'); }
  }
  return page;
}

export function getYouTubeSongs(searchQuery, pageToken = '', order = 'relevance', maxResults = 5) {
  const cacheKey = buildCacheKey(searchQuery, order, maxResults, pageToken);
  if (inFlight.has(cacheKey)) return inFlight.get(cacheKey);
  const request = loadSongs(cacheKey, searchQuery, pageToken, order, maxResults)
    .finally(() => inFlight.delete(cacheKey));
  inFlight.set(cacheKey, request);
  return request;
}
