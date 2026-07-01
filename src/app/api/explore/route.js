import { getYouTubeSongs } from '@/lib/youtube';
import { NextResponse } from 'next/server';

export async function GET(request) {
  const { searchParams } = new URL(request.url);
  const query = searchParams.get('q') || '';
  const order = searchParams.get('order') || 'viewCount';

  if (!query) {
    return NextResponse.json({ items: [] }, { status: 400 });
  }

  try {
    const result = await getYouTubeSongs(query, '', order, 8);
    return NextResponse.json({ items: result.items });
  } catch {
    return NextResponse.json({ items: [] }, { status: 500 });
  }
}
