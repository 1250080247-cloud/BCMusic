import assert from 'node:assert/strict';
import test from 'node:test';
import { loadModule } from './helpers.mjs';

const mocks = {
  '@/lib/mongodb': { default: async () => {} },
  '@/models/SongCache': { default: {
    findOne: () => ({ lean: async () => null }),
    findOneAndUpdate: async () => {},
  } },
};

function handleShortsProbe(url) {
  if (url.hostname === 'www.youtube.com') {
    const id = url.pathname.split('/').pop();
    return new Response(null, { status: 303, headers: { location: `https://www.youtube.com/watch?v=${id}` } });
  }
  return new Response(null, { status: 404 });
}

test('Unicode lookaround regexes match word boundaries with accents and ignore substrings', async () => {
  const { STRONG_MUSIC_REGEX, MIX_MUSIC_REGEX, BLACKLIST_REGEX, isLongFormQuery } = await loadModule('src/lib/youtube.js', mocks);

  // STRONG keywords
  assert.equal(STRONG_MUSIC_REGEX.test('Titanic OST'.normalize('NFC')), true);
  assert.equal(STRONG_MUSIC_REGEX.test('Lost'.normalize('NFC')), false);
  assert.equal(STRONG_MUSIC_REGEX.test('Most'.normalize('NFC')), false);
  assert.equal(STRONG_MUSIC_REGEX.test('Cost'.normalize('NFC')), false);
  assert.equal(STRONG_MUSIC_REGEX.test('Bài hát tôi yêu'.normalize('NFC')), true);
  assert.equal(STRONG_MUSIC_REGEX.test('Nhạc phim Cổng mặt trời'.normalize('NFC')), true);
  assert.equal(STRONG_MUSIC_REGEX.test('Official Music Video 4K'.normalize('NFC')), true);
  assert.equal(STRONG_MUSIC_REGEX.test('Ca khúc bất hủ'.normalize('NFC')), true);

  // Standalone 'song', 'live', 'audio' are removed and do NOT match STRONG
  assert.equal(STRONG_MUSIC_REGEX.test('Love Song'.normalize('NFC')), false);
  assert.equal(STRONG_MUSIC_REGEX.test('Concert Live'.normalize('NFC')), false);
  assert.equal(STRONG_MUSIC_REGEX.test('Audio Leak'.normalize('NFC')), false);
  // 'official audio' is included in STRONG
  assert.equal(STRONG_MUSIC_REGEX.test('Track 1 (Official Audio)'.normalize('NFC')), true);

  // MIX keywords
  assert.equal(MIX_MUSIC_REGEX.test('Nonstop 2026'.normalize('NFC')), true);
  assert.equal(MIX_MUSIC_REGEX.test('Liên khúc nhạc vàng'.normalize('NFC')), true);
  assert.equal(MIX_MUSIC_REGEX.test('Tuyển tập acoustic piano'.normalize('NFC')), true);
  assert.equal(MIX_MUSIC_REGEX.test('Chill 2 hours'.normalize('NFC')), true);
  assert.equal(MIX_MUSIC_REGEX.test('3 giờ học bài'.normalize('NFC')), true);

  // isLongFormQuery
  assert.equal(isLongFormQuery('lofi'), true);
  assert.equal(isLongFormQuery('remix tiktok'), true);
  assert.equal(isLongFormQuery('Avengers'), false);
  assert.equal(isLongFormQuery('Titanic'), false);

  // BLACKLIST keywords
  assert.equal(BLACKLIST_REGEX.test('Official Trailer 2026'.normalize('NFC')), true);
  assert.equal(BLACKLIST_REGEX.test('Tập 15 Full'.normalize('NFC')), true);
  assert.equal(BLACKLIST_REGEX.test('Phim chiếu rạp HD Vietsub'.normalize('NFC')), true);
  assert.equal(BLACKLIST_REGEX.test('Review phim hay'.normalize('NFC')), true);
});

test('filterMusicSongs: (a) query "lofi" keeps a 2-hour video without MIX in title', async () => {
  const { filterMusicSongs } = await loadModule('src/lib/youtube.js', mocks);
  const songs = [
    { id: 'VIDEO000001', title: 'Deep Night Focus Session', durationSeconds: 7200 },
  ];
  const filtered = filterMusicSongs(songs, 'lofi');
  assert.equal(filtered.length, 1);
  assert.equal(filtered[0].id, 'VIDEO000001');
});

test('filterMusicSongs: (b) "Liên khúc nhạc vàng" 40 minutes is kept', async () => {
  const { filterMusicSongs } = await loadModule('src/lib/youtube.js', mocks);
  const songs = [
    { id: 'VIDEO000002', title: 'Liên khúc nhạc vàng bất hủ', durationSeconds: 2400 },
  ];
  const filtered = filterMusicSongs(songs, 'bolero');
  assert.equal(filtered.length, 1);
  assert.equal(filtered[0].id, 'VIDEO000002');
});

test('filterMusicSongs: (c) 2-hour video "Avengers full movie vietsub" is filtered out', async () => {
  const { filterMusicSongs } = await loadModule('src/lib/youtube.js', mocks);
  const songs = [
    { id: 'VIDEO000003', title: 'Avengers full movie vietsub', durationSeconds: 7200 },
  ];
  // Even if query is 'lofi', blacklisted items without STRONG keywords are dropped
  const filtered = filterMusicSongs(songs, 'lofi');
  assert.equal(filtered.length, 0);
});

test('filterMusicSongs: (d) durationSeconds = 0 or missing is not filtered out as long', async () => {
  const { filterMusicSongs } = await loadModule('src/lib/youtube.js', mocks);
  const songs = [
    { id: 'VIDEO000004', title: 'Chill Radio 24/7 Livestream', durationSeconds: 0 },
    { id: 'VIDEO000005', title: 'Acoustic Stream', durationSeconds: null },
  ];
  const filtered = filterMusicSongs(songs, 'general');
  assert.equal(filtered.length, 2);
});

test('filterMusicSongs: (e) keywords "live" or "song" do not rescue video from blacklist', async () => {
  const { filterMusicSongs } = await loadModule('src/lib/youtube.js', mocks);
  const songs = [
    { id: 'VIDEO000006', title: 'Avengers Endgame Official Trailer Live Broadcast', durationSeconds: 150 },
    { id: 'VIDEO000007', title: 'Fast & Furious Teaser Song Promo', durationSeconds: 120 },
  ];
  const filtered = filterMusicSongs(songs, 'Avengers');
  assert.equal(filtered.length, 0);
});

test('filterMusicSongs: STRONG keywords rescue video from blacklist', async () => {
  const { filterMusicSongs } = await loadModule('src/lib/youtube.js', mocks);
  const songs = [
    { id: 'VIDEO000008', title: 'Lật Mặt 7: Nhạc Phim Official MV (Trailer Cut)', durationSeconds: 240 },
    { id: 'VIDEO000009', title: 'Titanic Full Movie OST Theme Song', durationSeconds: 300 },
  ];
  const filtered = filterMusicSongs(songs, 'Nhạc phim');
  assert.equal(filtered.length, 2);
});

test('fetchFromYouTube: Tier 2 fallback triggers when filtered < threshold on first page', async () => {
  const requests = [];
  const { getYouTubeSongs } = await loadModule('src/lib/youtube.js', mocks, {
    process: { env: { YOUTUBE_API_KEY: 'test-api-key' } },
    fetch: async (input) => {
      const url = new URL(input);
      requests.push(url);
      if (url.pathname.endsWith('/search')) {
        const cat = url.searchParams.get('videoCategoryId');
        // Tier 1 (with videoCategoryId=10): returns 2 music items and 2 trailer items
        if (cat === '10') {
          return Response.json({
            items: [
              { id: { videoId: 'T1MUSIC0001' }, snippet: { title: 'Avengers Main Theme OST', channelTitle: 'Marvel Music' } },
              { id: { videoId: 'T1TRAILER01' }, snippet: { title: 'Avengers Official Trailer', channelTitle: 'Marvel' } },
              { id: { videoId: 'T1MUSIC0002' }, snippet: { title: 'Portals Theme (Official Audio)', channelTitle: 'Marvel Music' } },
              { id: { videoId: 'T1MOVIE0001' }, snippet: { title: 'Avengers Full Movie Vietsub', channelTitle: 'Cinema' } },
            ],
            nextPageToken: 'tier1-next-token',
            prevPageToken: 'tier1-prev-token',
          });
        }
        // Tier 2 (fallback without categoryId): returns additional music items
        return Response.json({
          items: [
            { id: { videoId: 'T1MUSIC0001' }, snippet: { title: 'Avengers Main Theme OST', channelTitle: 'Marvel Music' } }, // duplicate
            { id: { videoId: 'T2MUSIC0003' }, snippet: { title: 'Avengers Suite Official Audio', channelTitle: 'Hollywood Records' } },
            { id: { videoId: 'T2TRAILER01' }, snippet: { title: 'Avengers Teaser Trailer', channelTitle: 'Marvel' } },
          ],
          nextPageToken: 'tier2-ignored-token',
        });
      }
      if (url.pathname.endsWith('/videos')) {
        const ids = (url.searchParams.get('id') || '').split(',').filter(Boolean);
        return Response.json({
          items: ids.map(id => ({
            id,
            statistics: { viewCount: '1000' },
            contentDetails: { duration: 'PT3M30S' },
          })),
        });
      }
      return handleShortsProbe(url);
    },
  });

  const result = await getYouTubeSongs('Avengers', '', 'relevance', 5);

  // Check requests: Tier 1 then Tier 2
  const searchRequests = requests.filter(r => r.pathname.endsWith('/search'));
  assert.equal(searchRequests.length, 2, 'Tier 2 fallback should have triggered');
  assert.equal(searchRequests[0].searchParams.get('videoCategoryId'), '10');
  assert.equal(searchRequests[1].searchParams.get('q'), 'Avengers official audio');
  assert.equal(searchRequests[1].searchParams.get('videoCategoryId'), null);

  // Check results: trailers and movies filtered out, Tier 1 ranked before Tier 2, deduplicated
  assert.deepEqual([...result.items.map(s => s.id)], ['T1MUSIC0001', 'T1MUSIC0002', 'T2MUSIC0003']);
  // nextPageToken and prevPageToken must be from Tier 1!
  assert.equal(result.nextPageToken, 'tier1-next-token');
  assert.equal(result.prevPageToken, 'tier1-prev-token');
});

test('fetchFromYouTube: Tier 2 does NOT run when pageToken is present', async () => {
  const requests = [];
  const { getYouTubeSongs } = await loadModule('src/lib/youtube.js', mocks, {
    process: { env: { YOUTUBE_API_KEY: 'test-api-key' } },
    fetch: async (input) => {
      const url = new URL(input);
      requests.push(url);
      if (url.pathname.endsWith('/search')) {
        return Response.json({
          items: [
            { id: { videoId: 'P2MUSIC0001' }, snippet: { title: 'Avengers Track Page 2 OST', channelTitle: 'Artist' } },
          ],
          nextPageToken: 'page3-token',
        });
      }
      if (url.pathname.endsWith('/videos')) {
        return Response.json({
          items: [{ id: 'P2MUSIC0001', statistics: { viewCount: '500' }, contentDetails: { duration: 'PT3M30S' } }],
        });
      }
      return handleShortsProbe(url);
    },
  });

  const result = await getYouTubeSongs('Avengers', 'page2-token', 'relevance', 5);

  const searchRequests = requests.filter(r => r.pathname.endsWith('/search'));
  assert.equal(searchRequests.length, 1, 'Tier 2 should NOT run when pageToken is present');
  assert.equal(result.items.length, 1);
  assert.equal(result.nextPageToken, 'page3-token');
});

test('fetchFromYouTube: (d) when filtered result has 3 songs, keep those 3 songs (do not return unfiltered)', async () => {
  const { getYouTubeSongs } = await loadModule('src/lib/youtube.js', mocks, {
    process: { env: { YOUTUBE_API_KEY: 'test-api-key' } },
    fetch: async (input) => {
      const url = new URL(input);
      if (url.pathname.endsWith('/search')) {
        const cat = url.searchParams.get('videoCategoryId');
        if (cat === '10') {
          return Response.json({
            items: [
              { id: { videoId: 'SONG0000001' }, snippet: { title: 'Valid Song 1 (Official Audio)', channelTitle: 'Artist' } },
              { id: { videoId: 'SONG0000002' }, snippet: { title: 'Valid Song 2 OST', channelTitle: 'Artist' } },
              { id: { videoId: 'SONG0000003' }, snippet: { title: 'Valid Song 3 MV', channelTitle: 'Artist' } },
              { id: { videoId: 'TR000000001' }, snippet: { title: 'Movie Trailer 1', channelTitle: 'Cinema' } },
              { id: { videoId: 'TR000000002' }, snippet: { title: 'Movie Trailer 2', channelTitle: 'Cinema' } },
            ],
          });
        }
        // Fallback tier returns nothing new
        return Response.json({ items: [] });
      }
      if (url.pathname.endsWith('/videos')) {
        const ids = (url.searchParams.get('id') || '').split(',').filter(Boolean);
        return Response.json({
          items: ids.map(id => ({ id, statistics: { viewCount: '10' }, contentDetails: { duration: 'PT3M30S' } })),
        });
      }
      return handleShortsProbe(url);
    },
  });

  const result = await getYouTubeSongs('SomeMovie', '', 'relevance', 5);
  // Exactly 3 filtered songs should be returned, NOT the 5 unfiltered songs!
  assert.equal(result.items.length, 3);
  assert.deepEqual([...result.items.map(s => s.id)], ['SONG0000001', 'SONG0000002', 'SONG0000003']);
});

test('fetchFromYouTube: when filtered result is 0, falls back to unfiltered list to protect home feed', async () => {
  const { getYouTubeSongs } = await loadModule('src/lib/youtube.js', mocks, {
    process: { env: { YOUTUBE_API_KEY: 'test-api-key' } },
    fetch: async (input) => {
      const url = new URL(input);
      if (url.pathname.endsWith('/search')) {
        return Response.json({
          items: [
            { id: { videoId: 'ODD00000001' }, snippet: { title: 'Odd Video Without Music Metadata', channelTitle: 'Channel' } },
            { id: { videoId: 'ODD00000002' }, snippet: { title: 'Another Unknown Clip', channelTitle: 'Channel' } },
          ],
        });
      }
      if (url.pathname.endsWith('/videos')) {
        const ids = (url.searchParams.get('id') || '').split(',').filter(Boolean);
        return Response.json({
          items: ids.map(id => ({ id, statistics: { viewCount: '10' }, contentDetails: { duration: 'PT30M' } })), // > 15m without music keyword
        });
      }
      return handleShortsProbe(url);
    },
  });

  const result = await getYouTubeSongs('OddQuery', '', 'relevance', 5);
  // Because all items were filtered out (length === 0), it falls back to unfiltered to prevent empty screen
  assert.equal(result.items.length, 2);
  assert.equal(result.items[0].id, 'ODD00000001');
});

test('parseYouTubeDuration parses empty string, spaces, P0D and PT0S as 0 without NaN or errors', async () => {
  const { parseYouTubeDuration } = await loadModule('src/lib/youtube-shorts.js');
  assert.equal(parseYouTubeDuration(''), 0);
  assert.equal(parseYouTubeDuration('   '), 0);
  assert.equal(parseYouTubeDuration('P0D'), 0);
  assert.equal(parseYouTubeDuration('PT0S'), 0);
  assert.equal(parseYouTubeDuration('P0DT0S'), 0);
  assert.equal(parseYouTubeDuration('PT19S'), 19);
  assert.equal(parseYouTubeDuration('PT2M30S'), 150);
  assert.equal(parseYouTubeDuration('P'), null);
  assert.equal(parseYouTubeDuration('PT'), null);
  assert.equal(parseYouTubeDuration('invalid'), null);
  assert.equal(parseYouTubeDuration(undefined), null);
  assert.equal(parseYouTubeDuration(null), null);
  assert.equal(Number.isNaN(parseYouTubeDuration('')), false);
  assert.equal(Number.isNaN(parseYouTubeDuration('P0D')), false);
});

test('Shorts do not leak into Tier 1, Tier 2, or safety fallback results', async () => {
  const shortResponse = () => new Response(null, {
    status: 200,
    headers: {
      'content-type': 'text/html',
      'content-security-policy': 'https://csp.withgoogle.com/csp/youtube_main',
      'content-length': '0',
    },
  });

  const { getYouTubeSongs } = await loadModule('src/lib/youtube.js', mocks, {
    process: { env: { YOUTUBE_API_KEY: 'test-api-key' } },
    fetch: async (input) => {
      const url = new URL(input);
      if (url.pathname.endsWith('/search')) {
        const cat = url.searchParams.get('videoCategoryId');
        // Tier 1: 1 regular song, 1 Short (both under category 10)
        if (cat === '10') {
          return Response.json({
            items: [
              { id: { videoId: 'REGULAR0001' }, snippet: { title: 'Regular Song 1 (Official Audio)', channelTitle: 'Artist' } },
              { id: { videoId: 'SHORT000001' }, snippet: { title: 'Short Clip 1 (Official Audio)', channelTitle: 'Artist' } },
            ],
          });
        }
        // Tier 2 (fallback): 1 regular song, 1 Short
        return Response.json({
          items: [
            { id: { videoId: 'REGULAR0002' }, snippet: { title: 'Regular Song 2 (Official Audio)', channelTitle: 'Artist' } },
            { id: { videoId: 'SHORT000002' }, snippet: { title: 'Short Clip 2 (Official Audio)', channelTitle: 'Artist' } },
          ],
        });
      }
      if (url.pathname.endsWith('/videos')) {
        const ids = (url.searchParams.get('id') || '').split(',').filter(Boolean);
        return Response.json({
          items: ids.map(id => ({ id, statistics: { viewCount: '10' }, contentDetails: { duration: 'PT45S' } })),
        });
      }
      if (url.hostname === 'www.youtube.com') {
        const id = url.pathname.split('/').pop();
        if (id.startsWith('SHORT')) {
          return shortResponse();
        }
        return new Response(null, { status: 303, headers: { location: `https://www.youtube.com/watch?v=${id}` } });
      }
      return new Response(null, { status: 404 });
    },
  });

  const result = await getYouTubeSongs('TestShorts', '', 'relevance', 5);

  // Both SHORT000001 and SHORT000002 must be completely excluded!
  assert.deepEqual([...result.items.map(s => s.id)], ['REGULAR0001', 'REGULAR0002']);
  assert.equal(result.items.some(s => s.id.startsWith('SHORT')), false);
});

test('Shorts do not leak into safety fallback when all music items are filtered', async () => {
  const shortResponse = () => new Response(null, {
    status: 200,
    headers: {
      'content-type': 'text/html',
      'content-security-policy': 'https://csp.withgoogle.com/csp/youtube_main',
      'content-length': '0',
    },
  });

  const { getYouTubeSongs } = await loadModule('src/lib/youtube.js', mocks, {
    process: { env: { YOUTUBE_API_KEY: 'test-api-key' } },
    fetch: async (input) => {
      const url = new URL(input);
      if (url.pathname.endsWith('/search')) {
        return Response.json({
          items: [
            { id: { videoId: 'REGULAR0003' }, snippet: { title: 'Movie Without Music Keywords', channelTitle: 'Channel' } },
            { id: { videoId: 'SHORT000003' }, snippet: { title: 'Short Clip Without Music Keywords', channelTitle: 'Channel' } },
          ],
        });
      }
      if (url.pathname.endsWith('/videos')) {
        const ids = (url.searchParams.get('id') || '').split(',').filter(Boolean);
        return Response.json({
          items: ids.map(id => ({
            id,
            statistics: { viewCount: '10' },
            contentDetails: { duration: id.startsWith('SHORT') ? 'PT45S' : 'PT30M' },
          })),
        });
      }
      if (url.hostname === 'www.youtube.com') {
        const id = url.pathname.split('/').pop();
        if (id.startsWith('SHORT')) {
          return shortResponse();
        }
        return new Response(null, { status: 303, headers: { location: `https://www.youtube.com/watch?v=${id}` } });
      }
      return new Response(null, { status: 404 });
    },
  });

  const result = await getYouTubeSongs('MovieQuery', '', 'relevance', 5);

  // REGULAR0003 is > 15m without music keywords, so it gets filtered by music filter.
  // Because 0 items remain after music filter, safety fallback triggers and returns Tier 1 items.
  // BUT SHORT000003 was filtered by Shorts filter before music filtering, so it is NEVER in Tier 1 items!
  // Safety fallback must only contain REGULAR0003, NEVER SHORT000003!
  assert.deepEqual([...result.items.map(s => s.id)], ['REGULAR0003']);
  assert.equal(result.items.some(s => s.id === 'SHORT000003'), false);
});

test('isLongFormQuery checks only MIX keywords, NOT STRONG keywords', async () => {
  const { isLongFormQuery } = await loadModule('src/lib/youtube.js', mocks);
  // MIX keywords return true
  assert.equal(isLongFormQuery('lofi chill'), true);
  assert.equal(isLongFormQuery('liên khúc nhạc vàng'), true);
  assert.equal(isLongFormQuery('acoustic cover'), true);
  assert.equal(isLongFormQuery('album'), true);

  // STRONG keywords (without MIX) return false
  assert.equal(isLongFormQuery('Titanic OST'), false);
  assert.equal(isLongFormQuery('Official Audio'), false);
  assert.equal(isLongFormQuery('soundtrack'), false);
  assert.equal(isLongFormQuery('nhạc phim'), false);
  assert.equal(isLongFormQuery('Avengers'), false);
});

test('fetchFromYouTube: Tier 2 results are still bounded by 15-min limit when original query has no MIX keyword', async () => {
  const { getYouTubeSongs } = await loadModule('src/lib/youtube.js', mocks, {
    process: { env: { YOUTUBE_API_KEY: 'test-api-key' } },
    fetch: async (input) => {
      const url = new URL(input);
      if (url.pathname.endsWith('/search')) {
        const cat = url.searchParams.get('videoCategoryId');
        // Tier 1 returns nothing
        if (cat === '10') {
          return Response.json({ items: [] });
        }
        // Tier 2 (fallback query is "Adele official audio")
        return Response.json({
          items: [
            // Video 1: 3-minute normal audio -> kept
            { id: { videoId: 'T2SHORT0001' }, snippet: { title: 'Adele - Hello Track', channelTitle: 'Adele' } },
            // Video 2: 25-minute video without STRONG or MIX in title -> MUST BE FILTERED OUT even though Tier 2 searched with "official audio"
            { id: { videoId: 'T2LONG00001' }, snippet: { title: 'Adele Symphony Instrumental Session', channelTitle: 'Music' } },
            // Video 3: 30-minute video with STRONG in title -> kept
            { id: { videoId: 'T2STRON0001' }, snippet: { title: 'Adele Full Concert (Official Audio)', channelTitle: 'Adele' } },
          ],
        });
      }
      if (url.pathname.endsWith('/videos')) {
        const ids = (url.searchParams.get('id') || '').split(',').filter(Boolean);
        return Response.json({
          items: ids.map(id => {
            if (id === 'T2SHORT0001') return { id, statistics: { viewCount: '100' }, contentDetails: { duration: 'PT3M' } };
            if (id === 'T2LONG00001') return { id, statistics: { viewCount: '100' }, contentDetails: { duration: 'PT25M' } }; // 1500s > 900s
            if (id === 'T2STRON0001') return { id, statistics: { viewCount: '100' }, contentDetails: { duration: 'PT30M' } };
            return { id, statistics: { viewCount: '10' }, contentDetails: { duration: 'PT3M' } };
          }),
        });
      }
      return handleShortsProbe(url);
    },
  });

  const result = await getYouTubeSongs('Adele', '', 'relevance', 5);
  // Original query 'Adele' has no MIX keyword.
  // T2LONG00001 (25 mins, no STRONG/MIX title) MUST be filtered out!
  // T2SHORT0001 (3 mins) and T2STRON0001 (STRONG title) are kept.
  assert.equal(result.items.length, 2);
  assert.deepEqual([...result.items.map(s => s.id)], ['T2SHORT0001', 'T2STRON0001']);
});

test('fetchFromYouTube: nextPageToken and prevPageToken are always taken from Tier 1 even when Tier 2 runs', async () => {
  const { getYouTubeSongs } = await loadModule('src/lib/youtube.js', mocks, {
    process: { env: { YOUTUBE_API_KEY: 'test-api-key' } },
    fetch: async (input) => {
      const url = new URL(input);
      if (url.pathname.endsWith('/search')) {
        const cat = url.searchParams.get('videoCategoryId');
        if (cat === '10') {
          return Response.json({
            items: [
              { id: { videoId: 'T1SONG00001' }, snippet: { title: 'Tier 1 Song OST', channelTitle: 'Artist' } },
            ],
            nextPageToken: 'TIER1_NEXT_PAGE_TOKEN',
            prevPageToken: 'TIER1_PREV_PAGE_TOKEN',
          });
        }
        // Tier 2 returns items with its own tokens
        return Response.json({
          items: [
            { id: { videoId: 'T2SONG00002' }, snippet: { title: 'Tier 2 Song (Official Audio)', channelTitle: 'Artist' } },
          ],
          nextPageToken: 'TIER2_NEXT_SHOULD_BE_IGNORED',
          prevPageToken: 'TIER2_PREV_SHOULD_BE_IGNORED',
        });
      }
      if (url.pathname.endsWith('/videos')) {
        const ids = (url.searchParams.get('id') || '').split(',').filter(Boolean);
        return Response.json({
          items: ids.map(id => ({ id, statistics: { viewCount: '50' }, contentDetails: { duration: 'PT3M' } })),
        });
      }
      return handleShortsProbe(url);
    },
  });

  const result = await getYouTubeSongs('SomeMovie', '', 'relevance', 5);
  assert.equal(result.items.length, 2);
  assert.equal(result.nextPageToken, 'TIER1_NEXT_PAGE_TOKEN');
  assert.equal(result.prevPageToken, 'TIER1_PREV_PAGE_TOKEN');
});

test('BLACKLIST_REGEX matches reaction, podcast, behind the scenes, and movie episodes, while preserving songs with "tập"', async () => {
  const { BLACKLIST_REGEX, filterMusicSongs } = await loadModule('src/lib/youtube.js', mocks);

  // Blacklist words
  assert.equal(BLACKLIST_REGEX.test('MV Reaction by Famous Streamer'.normalize('NFC')), true);
  assert.equal(BLACKLIST_REGEX.test('Vietcetera Podcast Show'.normalize('NFC')), true);
  assert.equal(BLACKLIST_REGEX.test('Behind the Scenes Making of Video'.normalize('NFC')), true);
  assert.equal(BLACKLIST_REGEX.test('Behind The Scene Clip'.normalize('NFC')), true);
  assert.equal(BLACKLIST_REGEX.test('Phim Mùa Hè Tập 1'.normalize('NFC')), true);
  assert.equal(BLACKLIST_REGEX.test('Phim Chiếu Rạp Tập Full'.normalize('NFC')), true);
  assert.equal(BLACKLIST_REGEX.test('Tập cuối phim truyền hình'.normalize('NFC')), true);
  assert.equal(BLACKLIST_REGEX.test('Tập đặc biệt Tết 2026'.normalize('NFC')), true);

  // Vietnamese songs containing "Tập" are NOT blacklisted
  assert.equal(BLACKLIST_REGEX.test('Tập Quên Em - Ca sĩ A'.normalize('NFC')), false);
  assert.equal(BLACKLIST_REGEX.test('Tập Yêu - Ca sĩ B'.normalize('NFC')), false);
  assert.equal(BLACKLIST_REGEX.test('Tuyển tập nhạc Trịnh bất hủ'.normalize('NFC')), false);
  assert.equal(BLACKLIST_REGEX.test('Tập làm người lớn'.normalize('NFC')), false);
  assert.equal(BLACKLIST_REGEX.test('Tập sống thiếu em'.normalize('NFC')), false);

  // filterMusicSongs filters out reaction/podcast/behind the scenes videos without strong music keywords
  const testSongs = [
    { id: 'REC00000001', title: 'Streamer Reaction Video', durationSeconds: 600 },
    { id: 'POD00000001', title: 'Late Night Podcast Episode', durationSeconds: 600 },
    { id: 'BTS00000001', title: 'Behind the Scenes Making of', durationSeconds: 600 },
    { id: 'TAP00000001', title: 'Tập Quên Em', durationSeconds: 240 },
    { id: 'EPI00000001', title: 'Người Phán Xử Tập 25', durationSeconds: 2400 },
  ];
  const filtered = filterMusicSongs(testSongs, 'test');
  assert.equal(filtered.length, 1);
  assert.equal(filtered[0].id, 'TAP00000001');
});

test('filterMusicSongs: checking title "[Vietsub] Shape of You - Ed Sheeran"', async () => {
  const { filterMusicSongs } = await loadModule('src/lib/youtube.js', mocks);
  const songs = [
    { id: 'VIETSUB0001', title: '[Vietsub] Shape of You - Ed Sheeran', durationSeconds: 235 },
  ];
  const filtered = filterMusicSongs(songs, 'Shape of You');
  // Currently, because "vietsub" is in BLACKLIST_REGEX and title has no STRONG music keywords,
  // this song is filtered out (result length is 0).
  assert.equal(filtered.length, 0);
});
