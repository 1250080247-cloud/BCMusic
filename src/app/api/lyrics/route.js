import { NextResponse } from 'next/server';
import { lookupLyrics } from '@/lib/lyrics-provider';

export async function GET(request) {
  const parameters = new URL(request.url).searchParams;
  const title = parameters.get('title')?.trim();
  const artist = parameters.get('artist')?.trim();
  const duration = Number(parameters.get('duration') || 0);
  if (!title || !artist || title.length > 250 || artist.length > 250
    || !Number.isFinite(duration) || duration < 0 || duration > 86400) {
    return NextResponse.json({ status: 'error', message: 'Invalid track metadata.' }, { status: 400 });
  }
  try {
    const result = await lookupLyrics({ title, artist, duration });
    return NextResponse.json(result, { headers: { 'Cache-Control': 'public, max-age=300, stale-while-revalidate=3600' } });
  } catch {
    return NextResponse.json({ status: 'error', message: 'Lyrics are temporarily unavailable.' }, {
      status: 503, headers: { 'Retry-After': '30' },
    });
  }
}
