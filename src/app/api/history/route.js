import { getRequestUserId } from '@/lib/request-user';
import { restoreSoundCloudMetadata } from '@/lib/song-metadata';
import dbConnect from '@/lib/mongodb';
import History from '@/models/History';
import { NextResponse } from 'next/server';
import { LIMITS, boundedText, clampInteger, optionalText, readJsonBody } from '@/lib/input';
import { cleanTrackUrls, safeHttpsUrl } from '@/lib/url-policy';

const SOURCES = ['youtube', 'soundcloud'];

// Newest first. `before` (ISO date from a previous nextBefore) fetches the next older page.
export async function GET(request) {
  try {
    const userId = await getRequestUserId({ allowGuest: true });
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }

    const { searchParams } = new URL(request.url);
    const limit = clampInteger(searchParams.get('limit'), 1, 200, 50);
    const beforeParam = searchParams.get('before');
    const before = beforeParam ? new Date(beforeParam) : null;
    if (before && Number.isNaN(before.getTime())) {
      return NextResponse.json({ success: false, message: 'Invalid cursor.' }, { status: 400 });
    }

    await dbConnect();
    const historyDocs = await History.find(before ? { userId, listenedAt: { $lt: before } } : { userId })
      .sort({ listenedAt: -1 })
      .limit(limit)
      .lean();

    const songs = historyDocs.map((doc) => ({
      id: doc.songId,
      title: doc.title,
      thumbnail: doc.thumbnail,
      artist: doc.artist,
      publishedAt: doc.publishedAt,
      lyrics: doc.lyrics,
      embedUrl: doc.embedUrl,
      sourceUrl: doc.sourceUrl,
      source: doc.source || 'youtube',
      listenedAt: doc.listenedAt ? new Date(doc.listenedAt).toISOString() : null,
    }));

    const oldest = historyDocs.at(-1);
    const nextBefore = historyDocs.length === limit && oldest?.listenedAt
      ? new Date(oldest.listenedAt).toISOString()
      : null;

    return NextResponse.json({
      success: true,
      data: await restoreSoundCloudMetadata(songs, userId),
      nextBefore,
    });
  } catch (error) {
    console.error('History fetch error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function POST(request) {
  try {
    const userId = await getRequestUserId({ allowGuest: true });
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa xác định người nghe.' }, { status: 401 });
    }
    const body = await readJsonBody(request);
    if (body === undefined) {
      return NextResponse.json({ success: false, message: 'Unsupported content type.' }, { status: 415 });
    }

    const songId = boundedText(body?.id, LIMITS.id);
    const title = boundedText(body?.title, LIMITS.text);
    if (!songId || !title) {
      return NextResponse.json({ success: false, message: 'Missing song id or title.' }, { status: 400 });
    }

    await dbConnect();
    const urls = cleanTrackUrls(body);

    // Upsert by (userId, songId): an existing entry only moves to the top of the list.
    const doc = await History.findOneAndUpdate(
      { userId, songId },
      {
        $set: {
          title,
          thumbnail: safeHttpsUrl(body.thumbnail) ?? undefined,
          artist: optionalText(body.artist, LIMITS.text),
          publishedAt: optionalText(body.publishedAt, 64),
          lyrics: typeof body.lyrics === 'string' && body.lyrics.length <= LIMITS.lyrics ? body.lyrics : undefined,
          embedUrl: urls.embedUrl,
          sourceUrl: urls.sourceUrl,
          source: SOURCES.includes(body.source) ? body.source : 'youtube',
          listenedAt: new Date(),
        },
      },
      { upsert: true, returnDocument: 'after' }
    );

    return NextResponse.json({ success: true, data: doc });
  } catch (error) {
    console.error('History save error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
