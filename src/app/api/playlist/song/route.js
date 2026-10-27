import { getRequestUserId } from '@/lib/request-user';
import dbConnect from '@/lib/mongodb';
import Playlist from '@/models/Playlist';
import { NextResponse } from 'next/server';

// POST /api/playlist/song — add a song to a playlist
export async function POST(request) {
  try {
    const userId = await getRequestUserId({ allowGuest: true });
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }
    const body = await request.json();

    if (typeof body?.playlistId !== 'string' || !/^[a-f0-9]{24}$/i.test(body.playlistId) || typeof body?.song?.id !== 'string' || typeof body?.song?.title !== 'string' || !body.song.id || !body.song.title.trim()) {
      return NextResponse.json(
        { success: false, message: 'Missing required fields.' },
        { status: 400 }
      );
    }

    await dbConnect();
    const playlist = await Playlist.findOne({ _id: body.playlistId, userId });

    if (!playlist) {
      return NextResponse.json(
        { success: false, message: 'Playlist not found.' },
        { status: 404 }
      );
    }

    // Check if song already exists
    const alreadyExists = playlist.songs.some((s) => s.id === body.song.id);
    if (alreadyExists) {
      return NextResponse.json(
        { success: false, message: 'already_exists' },
        { status: 409 }
      );
    }

    playlist.songs.push({
      id: body.song.id,
      title: body.song.title,
      thumbnail: body.song.thumbnail,
      artist: body.song.artist,
      publishedAt: body.song.publishedAt,
      source: body.song.source || 'youtube',
      embedUrl: body.song.embedUrl,
      sourceUrl: body.song.sourceUrl,
    });

    await playlist.save();

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Playlist song POST error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

// DELETE /api/playlist/song — remove a song from a playlist
export async function DELETE(request) {
  try {
    const userId = await getRequestUserId({ allowGuest: true });
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }
    const body = await request.json();

    if (typeof body?.playlistId !== 'string' || !/^[a-f0-9]{24}$/i.test(body.playlistId) || typeof body?.songId !== 'string' || !body.songId) {
      return NextResponse.json(
        { success: false, message: 'Missing required fields.' },
        { status: 400 }
      );
    }

    await dbConnect();
    const result = await Playlist.updateOne(
      { _id: body.playlistId, userId },
      { $pull: { songs: { id: body.songId } } }
    );

    if (result.matchedCount === 0) {
      return NextResponse.json(
        { success: false, message: 'Playlist not found.' },
        { status: 404 }
      );
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Playlist song DELETE error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
