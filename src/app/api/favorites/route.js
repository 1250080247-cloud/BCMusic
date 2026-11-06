import { getRequestUserId } from '@/lib/request-user';
import { restoreSoundCloudMetadata } from '@/lib/song-metadata';
import dbConnect from '@/lib/mongodb';
import Favorite from '@/models/Favorite';
import { NextResponse } from 'next/server';
import { LIMITS, boundedText, optionalText, readJsonBody } from '@/lib/input';
import { cleanTrackUrls, safeHttpsUrl } from '@/lib/url-policy';

const SOURCES = ['youtube', 'soundcloud'];

// Favorites belong to the authenticated account.
export async function GET(request) {
  try {
    const userId = await getRequestUserId();
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }
    await dbConnect();

    const favorites = await Favorite.find({ userId }).sort({ favoritedAt: -1 }).lean();

    const formatted = favorites.map((f) => ({
      id: f.songId, // Sử dụng songId làm ID chính ở Client để dễ so khớp
      title: f.title,
      thumbnail: f.thumbnail,
      artist: f.artist,
      publishedAt: f.publishedAt,
      embedUrl: f.embedUrl,
      sourceUrl: f.sourceUrl,
      source: f.source || 'youtube',
    }));

    return NextResponse.json({ success: true, data: await restoreSoundCloudMetadata(formatted, userId) });
  } catch (error) {
    console.error('Favorites GET error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

// POST /api/favorites
export async function POST(request) {
  try {
    const userId = await getRequestUserId();
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }
    const body = await readJsonBody(request);
    if (body === undefined) {
      return NextResponse.json({ success: false, message: 'Unsupported content type.' }, { status: 415 });
    }

    const song = body?.song;
    const songId = boundedText(song?.id, LIMITS.id);
    const title = boundedText(song?.title, LIMITS.text);
    if (!songId || !title) {
      return NextResponse.json({ success: false, message: 'Missing song info.' }, { status: 400 });
    }

    await dbConnect();
    const urls = cleanTrackUrls(song);
    const update = {
      userId,
      songId,
      title,
      thumbnail: safeHttpsUrl(song.thumbnail) ?? '',
      artist: optionalText(song.artist, LIMITS.text) || 'Unknown',
      publishedAt: optionalText(song.publishedAt, 64) || '',
      embedUrl: urls.embedUrl,
      sourceUrl: urls.sourceUrl,
      source: SOURCES.includes(song.source) ? song.source : 'youtube',
      favoritedAt: new Date(),
    };
    let favorite;
    try {
      // Upsert keyed by (userId, songId). The unique index turns a concurrent duplicate into E11000.
      favorite = await Favorite.findOneAndUpdate({ userId, songId }, update, { upsert: true, returnDocument: 'after' });
    } catch (error) {
      if (error.code !== 11000) throw error;
      favorite = await Favorite.findOne({ userId, songId }).lean();
    }

    return NextResponse.json({ success: true, data: favorite });
  } catch (error) {
    console.error('Favorites POST error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

// DELETE /api/favorites
export async function DELETE(request) {
  try {
    const userId = await getRequestUserId();
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }
    const { searchParams } = new URL(request.url);
    const songId = searchParams.get('songId');

    if (!userId || !songId) {
      return NextResponse.json(
        { success: false, message: 'Missing songId.' },
        { status: 400 }
      );
    }

    await dbConnect();
    const result = await Favorite.deleteOne({ userId, songId });

    if (result.deletedCount === 0) {
      return NextResponse.json(
        { success: false, message: 'Favorite not found.' },
        { status: 404 }
      );
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Favorites DELETE error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
