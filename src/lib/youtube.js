import dbConnect from '@/lib/mongodb';
import SongCache from '@/models/SongCache';
import { parseYouTubeDuration, filterYouTubeShorts, SHORTS_FILTER_VERSION } from '@/lib/youtube-shorts';

const CACHE_TTL_MS = 60 * 60 * 1000; // 1 hour in milliseconds
const SEARCH_TIMEOUT_MS = Number(process.env.YOUTUBE_SEARCH_TIMEOUT_MS) || 10000;
const STATS_TIMEOUT_MS = Number(process.env.YOUTUBE_STATS_TIMEOUT_MS) || 4500;
const inFlight = new Map();
const emptyResult = () => ({ items: [], nextPageToken: null, prevPageToken: null });
const MIN_DURATION_SECONDS = 30;
const aboveMinimumDuration = song => Number.isFinite(song.durationSeconds) && song.durationSeconds > MIN_DURATION_SECONDS;

export const STRONG_MUSIC_REGEX = /(?<![\p{L}])(ost|soundtrack|nhạc\s*phim|nhac\s*phim|theme\s*song|official\s*audio|official\s*music\s*video|mv|lyrics|ca\s*khúc|bài\s*hát)(?![\p{L}])/iu;

export const MIX_MUSIC_REGEX = /(?<![\p{L}])(lofi|nonstop|non-stop|non\s*stop|playlist|album|remix|chill|cover|liên\s*khúc|tuyển\s*tập|tuyển\s*chọn|tổng\s*hợp|mashup|nhạc\s*không\s*lời|acoustic|piano|jazz|ambient|relax|study|sleep|hours?|giờ|best\s*of|top\s*hits|mix)(?![\p{L}])/iu;

export const BLACKLIST_REGEX = /(?<![\p{L}])(trailer|teaser|full\s*movie|phim\s*ngắn|phim\s*chiếu\s*rạp|review\s*phim|thuyết\s*minh|lồng\s*tiếng|vietsub|reaction|podcast|behind\s*the\s*scenes?|tập\s*(?:\d+|full|cuối|đặc\s*biệt))(?![\p{L}])/iu;

/**
 * Checks if query contains long-form music keywords (only MIX keywords).
 */
export function isLongFormQuery(query) {
  if (!query || typeof query !== 'string') return false;
  const normalized = query.normalize('NFC');
  return MIX_MUSIC_REGEX.test(normalized);
}

/**
 * Soft filter for music content.
 * - Drops blacklisted videos (trailers, full movies, episodes...) unless title contains STRONG music keyword.
 * - Videos > 15 mins (900s) are dropped unless title or query contains STRONG or MIX music keyword.
 * - Missing duration or duration <= 0 (livestreams) are not considered long.
 */
export function filterMusicSongs(songs, query = '') {
  if (!Array.isArray(songs)) return [];
  const normalizedQuery = (query || '').normalize('NFC');
  const queryIsLongForm = isLongFormQuery(normalizedQuery);

  return songs.filter((song) => {
    const title = (song.title || '').normalize('NFC');
    const hasStrong = STRONG_MUSIC_REGEX.test(title);
    const isBlacklisted = BLACKLIST_REGEX.test(title);

    // Blacklist check: only STRONG keywords can rescue from blacklist
    if (isBlacklisted && !hasStrong) {
      return false;
    }

    // Duration check (> 15 minutes = 900 seconds)
    const duration = song.durationSeconds;
    const isLong = Number.isFinite(duration) && duration > 900 && duration > 0;
    if (isLong) {
      const exempt = hasStrong || MIX_MUSIC_REGEX.test(title) || queryIsLongForm;
      if (!exempt) {
        return false;
      }
    }

    return true;
  });
}

/**
 * Build a unique cache key from query parameters.
 */
function buildCacheKey(query, order, maxResults, pageToken) {
  return `youtube-music-v3:${query}__${order}__${maxResults}__${pageToken || 'first'}`;
}

/**
 * Query YouTube Data API v3 directly.
 */
async function queryYouTubeAPI(searchQuery, pageToken = '', order = 'relevance', maxResults = 5, categoryId = null) {
  const API_KEY = process.env.YOUTUBE_API_KEY;
  if (!API_KEY) return null;

  // Encode every parameter so caller input cannot add or override query parameters.
  const params = new URLSearchParams({
    part: 'snippet',
    maxResults: String(maxResults),
    q: searchQuery,
    type: 'video',
    order,
    key: API_KEY,
  });
  if (categoryId) params.set('videoCategoryId', categoryId);
  if (pageToken) params.set('pageToken', pageToken);
  const url = `https://www.googleapis.com/youtube/v3/search?${params}`;

  try {
    const res = await fetch(url, { cache: 'no-store', signal: AbortSignal.timeout(SEARCH_TIMEOUT_MS) });
    const data = await res.json();

    if (!res.ok) {
      const reason = data.error?.errors?.[0]?.reason;
      if (reason === 'quotaExceeded' || res.status === 429) {
        console.warn('YouTube API quota reached or rate-limited; skipping provider request.');
      } else {
        console.warn('YouTube API error status ' + res.status + '; provider request unavailable.');
      }
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
        const statsRes = await fetch(statsUrl, { cache: 'no-store', signal: AbortSignal.timeout(STATS_TIMEOUT_MS) });
        const statsData = await statsRes.json();
        if (!statsRes.ok || !Array.isArray(statsData.items)) return null;
        for (const v of statsData.items) {
          viewCounts[v.id] = v.statistics?.viewCount || null;
          durations[v.id] = parseYouTubeDuration(v.contentDetails?.duration);
        }
      } catch (statsError) {
        const isTimeout = statsError.name === 'TimeoutError' || statsError.name === 'AbortError';
        if (isTimeout) {
          console.warn('YouTube statistics timed out; metadata unavailable.');
        } else {
          console.warn('YouTube statistics unavailable:', statsError.name || 'network error');
        }
        return null;
      }
    }

    const formattedItems = filteredItems.map((item) => ({
      id: item.id.videoId,
      title: item.snippet.title,
      artist: item.snippet.channelTitle,
      thumbnail: item.snippet.thumbnails?.high?.url || item.snippet.thumbnails?.medium?.url || null,
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
    const isTimeout = error.name === 'TimeoutError' || error.name === 'AbortError';
    if (isTimeout) {
      console.warn('YouTube search timed out for query "' + searchQuery + '"; falling back safely.');
    } else {
      console.warn('YouTube search unavailable:', error.name || 'network error');
    }
    return null;
  }
}

/**
 * Fetch songs from YouTube Data API v3 with 2-tier fallback and soft filtering.
 */
async function fetchFromYouTube(searchQuery, pageToken = '', order = 'relevance', maxResults = 5) {
  // Tier 1: Search with music category (videoCategoryId = 10)
  const result1 = await queryYouTubeAPI(searchQuery, pageToken, order, maxResults, '10');
  if (!result1) return null;

  const tier1Filtered = filterMusicSongs(result1.items, searchQuery);
  const nextPageToken = result1.nextPageToken || null;
  const prevPageToken = result1.prevPageToken || null;
  let shortsFilterComplete = result1.shortsFilterComplete;

  let finalItems = [...tier1Filtered];
  const threshold = Math.min(5, maxResults);

  // Tier 2 (Fallback): Only run when on first page (!pageToken), filtered results < threshold,
  // and Tier 1 filter completed cleanly (no probe timeout/budget exhaustion)
  if (!pageToken && tier1Filtered.length < threshold && result1.shortsFilterComplete) {
    console.log(`[YouTube Search] Tier 2 fallback triggered for query: "${searchQuery}"`);
    const fallbackQuery = `${searchQuery} official audio`;
    const result2 = await queryYouTubeAPI(fallbackQuery, '', order, maxResults, null);
    if (result2 && Array.isArray(result2.items)) {
      if (!result2.shortsFilterComplete) shortsFilterComplete = false;
      const tier2Filtered = filterMusicSongs(result2.items, searchQuery);
      const seenIds = new Set(finalItems.map((item) => item.id));
      for (const item of tier2Filtered) {
        if (!seenIds.has(item.id)) {
          seenIds.add(item.id);
          finalItems.push(item);
        }
      }
    }
  }

  // Safety fallback: only return unfiltered list when result after filtering (after both tiers) === 0.
  // If 1-4 songs remain after filtering, keep those filtered songs.
  if (finalItems.length === 0 && result1.items.length > 0) {
    finalItems = result1.items;
  }

  return {
    items: finalItems,
    shortsFilterComplete,
    nextPageToken,
    prevPageToken,
  };
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
    console.warn('YouTube cache read unavailable; using the provider.');
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
      } catch { console.warn('YouTube cache metadata update unavailable.'); }
    }
    return { items: items.filter(aboveMinimumDuration), nextPageToken: cached.nextPageToken, prevPageToken: cached.prevPageToken };
  }

  const result = await fetchFromYouTube(searchQuery, pageToken, order, maxResults);
  // A provider failure is not an empty result: fall back to stale cache if available,
  // or return an unavailable error indicator without caching an outage.
  if (!result) {
    if (cached && Array.isArray(cached.songs) && cached.songs.length > 0) {
      console.warn('Serving stale cached YouTube songs for "' + searchQuery + '" during provider outage.');
      const verified = cached.shortsFiltered && cached.shortsFilterVersion === SHORTS_FILTER_VERSION;
      const filtered = verified ? { items: cached.songs || [], complete: true } : await filterYouTubeShorts(cached.songs || []);
      return {
        items: (filtered.items || []).filter(aboveMinimumDuration),
        nextPageToken: cached.nextPageToken,
        prevPageToken: cached.prevPageToken,
        stale: true,
      };
    }
    return { ...emptyResult(), unavailable: true };
  }
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
    } catch { console.warn('YouTube cache write unavailable; returning fetched songs.'); }
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
