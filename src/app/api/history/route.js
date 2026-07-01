import { getServerSession } from 'next-auth';
import dbConnect from '@/lib/mongodb';
import History from '@/models/History';
import { authOptions } from '@/app/api/auth/[...nextauth]/route';
import { NextResponse } from 'next/server';

export async function GET(request) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user?.id) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }

    await dbConnect();
    const historyDocs = await History.find({ userId: session.user.id })
      .sort({ listenedAt: -1 })
      .limit(50)
      .lean();

    const songs = historyDocs.map((doc) => ({
      id: doc.songId,
      title: doc.title,
      thumbnail: doc.thumbnail,
      artist: doc.artist,
      publishedAt: doc.publishedAt,
      lyrics: doc.lyrics,
      source: doc.source || 'youtube',
      listenedAt: doc.listenedAt ? new Date(doc.listenedAt).toISOString() : null,
    }));

    return NextResponse.json({ success: true, data: songs });
  } catch (error) {
    console.error('History fetch error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

export async function POST(request) {
  try {
    const session = await getServerSession(authOptions);
    const body = await request.json();

    if (!body?.id || !body?.title) {
      return NextResponse.json({ success: false, message: 'Missing song id or title.' }, { status: 400 });
    }

    await dbConnect();

    const userId = session?.user?.id || null;

    // Upsert theo (userId, songId):
    //  - Nếu bài đã có trong history → chỉ cập nhật listenedAt (đẩy lên đầu danh sách)
    //  - Nếu chưa có → tạo document mới
    // => Không bao giờ tạo trùng lặp
    const doc = await History.findOneAndUpdate(
      { userId, songId: body.id },
      {
        $set: {
          title: body.title,
          thumbnail: body.thumbnail,
          artist: body.artist,
          publishedAt: body.publishedAt,
          lyrics: body.lyrics,
          source: body.source || 'youtube',
          listenedAt: new Date(),
        },
      },
      { upsert: true, new: true }
    );

    return NextResponse.json({ success: true, data: doc });
  } catch (error) {
    console.error('History save error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
