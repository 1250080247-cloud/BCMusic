import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import History from '@/models/History';
import { getRequestUserId } from '@/lib/request-user';
import { getYouTubeSongs } from '@/lib/youtube';
import { consumeRateLimit } from '@/lib/rate-limit';
import { excludeHeard, mergeUnique, rankArtists } from '@/lib/recommendations';

// GET /api/recommendations — songs by the two artists the listener plays most, minus songs already heard.
// Each artist search is cached by getYouTubeSongs, so repeat visits cost no extra YouTube quota.
export async function GET(request) {
  try {
    const userId = await getRequestUserId({ allowGuest: true });
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa xác định người nghe.' }, { status: 401 });
    }
    // Each new artist query costs YouTube quota, so limit how often one listener can trigger it.
    if (!(await consumeRateLimit(`recommend:${userId}`, { limit: 30, windowMs: 60 * 60_000 }))) {
      return NextResponse.json({ success: false, message: 'Too many requests.' }, { status: 429, headers: { 'Retry-After': '3600' } });
    }

    await dbConnect();
    const recent = await History.find({ userId }).sort({ listenedAt: -1 }).limit(100).lean();
    const artists = rankArtists(recent, 2);
    if (!artists.length) {
      return NextResponse.json({ success: true, data: [], basedOn: [] });
    }

    const heard = new Set(recent.map((doc) => doc.songId));
    const pages = [];
    let failed = 0;
    for (const artist of artists) {
      const page = await getYouTubeSongs(`${artist} songs`, '', 'viewCount', 10);
      if (page.unavailable) {
        failed += 1;
        continue;
      }
      pages.push(excludeHeard(page.items, heard));
    }
    if (!pages.length && failed) {
      return NextResponse.json({ success: false, message: 'Recommendations are temporarily unavailable.', data: [] }, { status: 503, headers: { 'Retry-After': '30' } });
    }

    return NextResponse.json({ success: true, data: mergeUnique(pages, 20), basedOn: artists });
  } catch (error) {
    console.error('Recommendations error:', error);
    return NextResponse.json({ success: false, message: 'Recommendations failed.' }, { status: 500 });
  }
}
