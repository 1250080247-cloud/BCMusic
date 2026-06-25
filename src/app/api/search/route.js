import { getYouTubeSongs } from '@/lib/youtube';
import { NextResponse } from 'next/server';

export async function GET(request) {
  try {
    const { searchParams } = new URL(request.url);
    const query = searchParams.get('q') || '';
    const pageToken = searchParams.get('pageToken') || '';
    const order = searchParams.get('order') || 'relevance';
    const maxResults = parseInt(searchParams.get('maxResults') || '10', 10);

    if (!query.trim()) {
      return NextResponse.json({ items: [], nextPageToken: null, prevPageToken: null });
    }

    const result = await getYouTubeSongs(query, pageToken, order, maxResults);
    return NextResponse.json(result);
  } catch (error) {
    console.error('API Search Error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
