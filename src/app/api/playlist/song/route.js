import dbConnect from '@/lib/mongodb';
import Playlist from '@/models/Playlist';
import { NextResponse } from 'next/server';

// POST /api/playlist/song — add a song to a playlist
export async function POST(request) {
  try {
    await dbConnect();
    const body = await request.json();

    if (!body?.userId || !body?.playlistId || !body?.song?.id || !body?.song?.title) {
      return NextResponse.json(
        { success: false, message: 'Missing required fields.' },
        { status: 400 }
      );
    }

    const playlist = await Playlist.findOne({ _id: body.playlistId, userId: body.userId });

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
    await dbConnect();
    const body = await request.json();

    if (!body?.userId || !body?.playlistId || !body?.songId) {
      return NextResponse.json(
        { success: false, message: 'Missing required fields.' },
        { status: 400 }
      );
    }

    const result = await Playlist.updateOne(
      { _id: body.playlistId, userId: body.userId },
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
