import { getYouTubeSongs } from '@/lib/youtube';
import { clientKey, consumeRateLimit } from '@/lib/rate-limit';
import { LIMITS } from '@/lib/input';
import { NextResponse } from 'next/server';

const ORDERS = ['relevance', 'viewCount', 'date'];

export async function GET(request) {
  const { searchParams } = new URL(request.url);
  const query = (searchParams.get('q') || '').trim();
  const order = searchParams.get('order') || 'viewCount';

  if (!query) {
    return NextResponse.json({ items: [] }, { status: 400 });
  }
  if (query.length > LIMITS.query || !ORDERS.includes(order)) {
    return NextResponse.json({ items: [] }, { status: 400 });
  }
  if (!(await consumeRateLimit(`explore:${clientKey(request)}`, { limit: 60, windowMs: 60_000 }))) {
    return NextResponse.json({ items: [] }, { status: 429, headers: { 'Retry-After': '60' } });
  }

  try {
    const result = await getYouTubeSongs(query, '', order, 8);
    if (result.unavailable) {
      return NextResponse.json({ items: [] }, { status: 503, headers: { 'Retry-After': '30' } });
    }
    return NextResponse.json({ items: result.items });
  } catch {
    return NextResponse.json({ items: [] }, { status: 500 });
  }
}
