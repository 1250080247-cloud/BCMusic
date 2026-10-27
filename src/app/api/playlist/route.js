import { getRequestUserId } from '@/lib/request-user';
import dbConnect from '@/lib/mongodb';
import Playlist from '@/models/Playlist';
import { NextResponse } from 'next/server';

// List playlists owned by the session or verified guest.
export async function GET(request) {
  try {
    const userId = await getRequestUserId({ allowGuest: true });
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }
    await dbConnect();

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
    const userId = await getRequestUserId({ allowGuest: true });
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }
    const body = await request.json();

    if (typeof body?.name !== 'string' || !body.name.trim() || body.name.trim().length > 100) {
      return NextResponse.json(
        { success: false, message: 'Missing playlist name.' },
        { status: 400 }
      );
    }

    await dbConnect();
    const newPlaylist = await Playlist.create({
      userId,
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
    const userId = await getRequestUserId({ allowGuest: true });
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }
    const body = await request.json();

    if (typeof body?.playlistId !== 'string' || !/^[a-f0-9]{24}$/i.test(body.playlistId)) {
      return NextResponse.json(
        { success: false, message: 'Missing playlistId.' },
        { status: 400 }
      );
    }

    await dbConnect();
    const result = await Playlist.deleteOne({ _id: body.playlistId, userId });

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
