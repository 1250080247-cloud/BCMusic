import { getRequestUserId } from '@/lib/request-user';
import dbConnect from '@/lib/mongodb';
import Playlist from '@/models/Playlist';
import { NextResponse } from 'next/server';
import { LIMITS, boundedText, isObjectIdString, readJsonBody } from '@/lib/input';

const unsupported = () => NextResponse.json({ success: false, message: 'Unsupported content type.' }, { status: 415 });

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
      isPublic: Boolean(p.isPublic),
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
    const body = await readJsonBody(request);
    if (body === undefined) return unsupported();

    const name = boundedText(body?.name, LIMITS.name);
    if (!name) {
      return NextResponse.json({ success: false, message: 'Missing playlist name.' }, { status: 400 });
    }

    await dbConnect();
    const newPlaylist = await Playlist.create({ userId, name });

    return NextResponse.json({
      success: true,
      data: {
        id: newPlaylist._id.toString(),
        name: newPlaylist.name,
        songs: [],
        isPublic: false,
        createdAt: newPlaylist.createdAt.toISOString(),
      },
    });
  } catch (error) {
    console.error('Playlist POST error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}

// PATCH /api/playlist — rename, change visibility, or reorder songs
// Body: { playlistId, name?, isPublic?, songOrder? } where songOrder lists every song id once.
export async function PATCH(request) {
  try {
    const userId = await getRequestUserId({ allowGuest: true });
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }
    const body = await readJsonBody(request);
    if (body === undefined) return unsupported();
    if (!isObjectIdString(body?.playlistId)) {
      return NextResponse.json({ success: false, message: 'Missing playlistId.' }, { status: 400 });
    }

    const update = {};
    if (body.name !== undefined) {
      const name = boundedText(body.name, LIMITS.name);
      if (!name) return NextResponse.json({ success: false, message: 'Invalid playlist name.' }, { status: 400 });
      update.name = name;
    }
    if (body.isPublic !== undefined) {
      if (typeof body.isPublic !== 'boolean') {
        return NextResponse.json({ success: false, message: 'Invalid visibility.' }, { status: 400 });
      }
      update.isPublic = body.isPublic;
    }
    const reorder = body.songOrder !== undefined;
    if (reorder && (!Array.isArray(body.songOrder) || body.songOrder.length > LIMITS.playlistSongs
      || !body.songOrder.every((id) => typeof id === 'string' && id.length > 0 && id.length <= LIMITS.id))) {
      return NextResponse.json({ success: false, message: 'Invalid song order.' }, { status: 400 });
    }
    if (!reorder && !Object.keys(update).length) {
      return NextResponse.json({ success: false, message: 'Nothing to update.' }, { status: 400 });
    }

    await dbConnect();
    const playlist = await Playlist.findOne({ _id: body.playlistId, userId });
    if (!playlist) {
      return NextResponse.json({ success: false, message: 'Playlist not found.' }, { status: 404 });
    }

    const filter = { _id: body.playlistId, userId };
    if (reorder) {
      const byId = new Map(playlist.songs.map((song) => [song.id, song]));
      const order = body.songOrder;
      if (order.length !== playlist.songs.length || new Set(order).size !== order.length || order.some((id) => !byId.has(id))) {
        return NextResponse.json({ success: false, message: 'Song order must list every song once.' }, { status: 400 });
      }
      update.songs = order.map((id) => byId.get(id));
      // Reject the write if songs were added or removed after the read above.
      filter.songs = { $size: playlist.songs.length };
    }

    const result = await Playlist.updateOne(filter, { $set: update });
    if (result.matchedCount === 0) {
      return NextResponse.json({ success: false, message: 'Playlist changed. Reload and try again.' }, { status: 409 });
    }
    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Playlist PATCH error:', error);
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
    const body = await readJsonBody(request);
    if (body === undefined) return unsupported();

    if (!isObjectIdString(body?.playlistId)) {
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
