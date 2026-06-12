import dbConnect from '@/lib/mongodb';
import Playlist from '@/models/Playlist';
import { NextResponse } from 'next/server';

// GET /api/playlist?userId=xxx — list all playlists for user
export async function GET(request) {
  try {
    await dbConnect();
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');

    if (!userId) {
      return NextResponse.json({ success: false, message: 'Missing userId.' }, { status: 400 });
    }

    const playlists = await Playlist.find({ userId }).sort({ createdAt: -1 }).lean();

    const formatted = playlists.map((p) => ({
      id: p._id.toString(),
      name: p.name,
      songs: p.songs || [],
      createdAt: p.createdAt ? new Date(p.createdAt).toISOString() : null,
    }));

    return NextResponse.json({ success: true, data: formatted });
  } catch (error) {
    console.error('Playlist GET error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

// POST /api/playlist — create a new playlist
export async function POST(request) {
  try {
    await dbConnect();
    const body = await request.json();

    if (!body?.userId || !body?.name?.trim()) {
      return NextResponse.json(
        { success: false, message: 'Missing userId or playlist name.' },
        { status: 400 }
      );
    }

    const newPlaylist = await Playlist.create({
      userId: body.userId,
      name: body.name.trim(),
    });

    return NextResponse.json({
      success: true,
      data: {
        id: newPlaylist._id.toString(),
        name: newPlaylist.name,
        songs: [],
        createdAt: newPlaylist.createdAt.toISOString(),
      },
    });
  } catch (error) {
    console.error('Playlist POST error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

// DELETE /api/playlist — delete a playlist
export async function DELETE(request) {
  try {
    await dbConnect();
    const body = await request.json();

    if (!body?.userId || !body?.playlistId) {
      return NextResponse.json(
        { success: false, message: 'Missing userId or playlistId.' },
        { status: 400 }
      );
    }

    const result = await Playlist.deleteOne({ _id: body.playlistId, userId: body.userId });

    if (result.deletedCount === 0) {
      return NextResponse.json(
        { success: false, message: 'Playlist not found.' },
        { status: 404 }
      );
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Playlist DELETE error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
