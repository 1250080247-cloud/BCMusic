import dbConnect from '@/lib/mongodb';
import History from '@/models/History';
import { NextResponse } from 'next/server';

export async function POST(request) {
  try {
    await dbConnect();
    const body = await request.json();

    if (!body?.id || !body?.title) {
      return NextResponse.json(
        { success: false, message: 'Missing song id or title.' },
        { status: 400 }
      );
    }

    const newHistory = await History.create({
      songId: body.id,
      title: body.title,
      thumbnail: body.thumbnail,
      artist: body.artist,
      publishedAt: body.publishedAt,
      lyrics: body.lyrics,
    });

    return NextResponse.json({ success: true, data: newHistory });
  } catch (error) {
    console.error("History save error:", error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
