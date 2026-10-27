import { getRequestUserId } from '@/lib/request-user';
import { restoreSoundCloudMetadata } from '@/lib/song-metadata';
import dbConnect from '@/lib/mongodb';
import Favorite from '@/models/Favorite';
import { NextResponse } from 'next/server';

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
    const body = await request.json();

    const { song } = body;
    if (typeof song?.id !== 'string' || typeof song?.title !== 'string' || !song.id || !song.title.trim()) {
      return NextResponse.json(
        { success: false, message: 'Missing song info.' },
        { status: 400 }
      );
    }

    await dbConnect();
    // Tạo favorite mới (nếu đã tồn tại nhờ index unique sẽ tự báo lỗi hoặc ta dùng findOneAndUpdate)
    const favorite = await Favorite.findOneAndUpdate(
      { userId, songId: song.id },
      {
        userId,
        songId: song.id,
        title: song.title,
        thumbnail: song.thumbnail || '',
        artist: song.artist || 'Unknown',
        publishedAt: song.publishedAt || '',
        embedUrl: song.embedUrl,
        sourceUrl: song.sourceUrl,
        source: song.source || 'youtube',
        favoritedAt: new Date(),
      },
      { upsert: true, returnDocument: 'after' }
    );

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
