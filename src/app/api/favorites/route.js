import dbConnect from '@/lib/mongodb';
import Favorite from '@/models/Favorite';
import { NextResponse } from 'next/server';

// GET /api/favorites?userId=xxx
export async function GET(request) {
  try {
    await dbConnect();
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');

    if (!userId) {
      return NextResponse.json({ success: false, message: 'Missing userId.' }, { status: 400 });
    }

    const favorites = await Favorite.find({ userId }).sort({ favoritedAt: -1 }).lean();

    const formatted = favorites.map((f) => ({
      id: f.songId, // Sử dụng songId làm ID chính ở Client để dễ so khớp
      title: f.title,
      thumbnail: f.thumbnail,
      artist: f.artist,
      publishedAt: f.publishedAt,
      source: f.source || 'youtube',
    }));

    return NextResponse.json({ success: true, data: formatted });
  } catch (error) {
    console.error('Favorites GET error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

// POST /api/favorites
export async function POST(request) {
  try {
    await dbConnect();
    const body = await request.json();

    const { userId, song } = body;
    if (!userId || !song?.id || !song?.title) {
      return NextResponse.json(
        { success: false, message: 'Missing userId or song info.' },
        { status: 400 }
      );
    }

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
    await dbConnect();
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');
    const songId = searchParams.get('songId');

    if (!userId || !songId) {
      return NextResponse.json(
        { success: false, message: 'Missing userId or songId.' },
        { status: 400 }
      );
    }

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
