import { getYouTubeSongs } from '@/lib/youtube';
import { clientKey, consumeRateLimit } from '@/lib/rate-limit';
import { LIMITS } from '@/lib/input';
import { NextResponse } from 'next/server';

const ORDERS = ['relevance', 'viewCount', 'date'];
const PAGE_TOKEN = /^[A-Za-z0-9_-]{1,100}$/;

export async function GET(request) {
  try {
    const { searchParams } = new URL(request.url);
    const query = (searchParams.get('q') || '').trim();
    const pageToken = searchParams.get('pageToken') || '';
    const order = searchParams.get('order') || 'relevance';
    const maxResults = Number.parseInt(searchParams.get('maxResults') || '10', 10);

    if (!query) {
      return NextResponse.json({ items: [], nextPageToken: null, prevPageToken: null });
    }
    if (query.length > LIMITS.query || !ORDERS.includes(order) || !Number.isFinite(maxResults)
      || (pageToken && !PAGE_TOKEN.test(pageToken))) {
      return NextResponse.json({ success: false, message: 'Invalid search parameters.' }, { status: 400 });
    }
    if (!(await consumeRateLimit(`search:${clientKey(request)}`, { limit: 60, windowMs: 60_000 }))) {
      return NextResponse.json({ success: false, message: 'Too many requests.' }, { status: 429, headers: { 'Retry-After': '60' } });
    }

    const result = await getYouTubeSongs(query, pageToken, order, Math.min(50, Math.max(1, maxResults)));
    if (result.unavailable) {
      return NextResponse.json(
        { success: false, message: 'Search is temporarily unavailable.', items: [], nextPageToken: null, prevPageToken: null },
        { status: 503, headers: { 'Retry-After': '30' } }
      );
    }
    return NextResponse.json(result);
  } catch (error) {
    console.error('API Search Error:', error);
    return NextResponse.json({ success: false, message: 'Search failed.' }, { status: 500 });
  }
}
