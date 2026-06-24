import dbConnect from '@/lib/mongodb';
import SongCache from '@/models/SongCache';

const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour in milliseconds

/**
 * Build a unique cache key from query parameters.
 */
function buildCacheKey(query, order, maxResults, pageToken) {
  return `${query}__${order}__${maxResults}__${pageToken || 'first'}`;
}

/**
 * Fetch songs from YouTube Data API v3.
 * This is the raw fetch without any caching.
 */
async function fetchFromYouTube(searchQuery, pageToken = '', order = 'relevance', maxResults = 5) {
  const API_KEY = process.env.YOUTUBE_API_KEY;
  if (!API_KEY) return { items: [], nextPageToken: null, prevPageToken: null };

  const tokenParam = pageToken ? `&pageToken=${pageToken}` : '';
  const url = `https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=${maxResults}&q=${encodeURIComponent(searchQuery)}&type=video&videoDuration=medium&order=${order}&key=${API_KEY}${tokenParam}`;

  try {
    const res = await fetch(url, { cache: 'no-store' });
    const data = await res.json();

    if (!res.ok) {
      console.error('YouTube API Error:', data.error?.message);
      return { items: [], nextPageToken: null, prevPageToken: null };
    }

    const filteredItems = (data.items || []).filter((item) => item.id?.videoId);

    // Fetch view counts via Videos API (part=statistics)
    let viewCounts = {};
    const videoIds = filteredItems.map((item) => item.id.videoId).join(',');
    if (videoIds) {
      try {
        const statsUrl = `https://www.googleapis.com/youtube/v3/videos?part=statistics&id=${videoIds}&key=${API_KEY}`;
        const statsRes = await fetch(statsUrl, { cache: 'no-store' });
        const statsData = await statsRes.json();
        if (statsRes.ok && statsData.items) {
          for (const v of statsData.items) {
            viewCounts[v.id] = v.statistics?.viewCount || null;
          }
        }
      } catch (statsError) {
        console.error('YouTube Stats Fetch Error:', statsError);
      }
    }

    const formattedItems = filteredItems.map((item) => ({
      id: item.id.videoId,
      title: item.snippet.title,
      artist: item.snippet.channelTitle,
      thumbnail: item.snippet.thumbnails.high?.url || item.snippet.thumbnails.medium?.url,
      publishedAt: item.snippet.publishedAt,
      viewCount: viewCounts[item.id.videoId] || null,
      source: 'youtube',
    }));

    return {
      items: formattedItems,
      nextPageToken: data.nextPageToken || null,
      prevPageToken: data.prevPageToken || null,
    };
  } catch (error) {
    console.error('YouTube Fetch Error:', error);
    return { items: [], nextPageToken: null, prevPageToken: null };
  }
}

/**
 * Get songs with MongoDB caching layer.
 * 1. Check MongoDB for a cached result that is still fresh (< 1 hour old).
 * 2. If found, return it instantly (no YouTube API call).
 * 3. If not found or expired, call YouTube API, save to MongoDB, then return.
 *
 * This dramatically reduces YouTube API quota usage:
 * - Without cache: 300 quota points per page load
 * - With cache: 300 quota points per HOUR (regardless of traffic)
 */
export async function getYouTubeSongs(searchQuery, pageToken = '', order = 'relevance', maxResults = 5) {
  const cacheKey = buildCacheKey(searchQuery, order, maxResults, pageToken);

  try {
    await dbConnect();

    // Step 1: Check cache
    const cached = await SongCache.findOne({ cacheKey }).lean();

    if (cached) {
      const age = Date.now() - new Date(cached.cachedAt).getTime();
      if (age < CACHE_TTL_MS) {
        // Cache hit! Return cached data without calling YouTube
        console.log(`[Cache HIT] "${searchQuery}" (${order}) — saved 100 quota points`);
        return {
          items: cached.songs,
          nextPageToken: cached.nextPageToken,
          prevPageToken: cached.prevPageToken,
        };
      }
    }

    // Step 2: Cache miss or expired — fetch from YouTube
    console.log(`[Cache MISS] "${searchQuery}" (${order}) — calling YouTube API`);
    const result = await fetchFromYouTube(searchQuery, pageToken, order, maxResults);

    // Step 3: Save to MongoDB (upsert so we update if key exists)
    if (result.items.length > 0) {
      await SongCache.findOneAndUpdate(
        { cacheKey },
        {
          cacheKey,
          query: searchQuery,
          order,
          maxResults,
          songs: result.items,
          nextPageToken: result.nextPageToken,
          prevPageToken: result.prevPageToken,
          cachedAt: new Date(),
        },
        { upsert: true, returnDocument: 'after' }
      );
    }

    return result;
  } catch (dbError) {
    // If MongoDB is unavailable, fall back to direct YouTube API call
    console.error('[Cache Error] MongoDB unavailable, falling back to YouTube:', dbError.message);
    return fetchFromYouTube(searchQuery, pageToken, order, maxResults);
  }
}
