import { NextResponse } from 'next/server';
import { getSearchSuggestions } from '@/lib/youtube-suggestions';
import { clientKey, consumeRateLimit } from '@/lib/rate-limit';

export async function GET(request) {
  const parameters = new URL(request.url).searchParams;
  const query = (parameters.get('q') || '').trim();
  const language = parameters.get('language') || 'vi';
  if (query.length > 120 || /[\u0000-\u001f\u007f]/.test(query) || !['vi', 'en'].includes(language)) return NextResponse.json({ suggestions: [], message: 'Invalid search query.' }, { status: 400 });
  if (query.length < 2) return NextResponse.json({ suggestions: [] });
  if (!(await consumeRateLimit(`suggest:${clientKey(request)}`, { limit: 120, windowMs: 60_000 }))) {
    return NextResponse.json({ suggestions: [], message: 'Too many requests.' }, { status: 429, headers: { 'Retry-After': '60', 'Cache-Control': 'no-store' } });
  }
  try {
    const suggestions = await getSearchSuggestions(query, language);
    return NextResponse.json({ suggestions }, { headers: { 'Cache-Control': 'public, max-age=60, stale-while-revalidate=300' } });
  } catch {
    return NextResponse.json({ suggestions: [], unavailable: true }, { headers: { 'Cache-Control': 'no-store' } });
  }
}
