import { getRequestUserId } from '@/lib/request-user';
import dbConnect from '@/lib/mongodb';
import Playlist from '@/models/Playlist';
import { NextResponse } from 'next/server';
import { LIMITS, boundedText, isObjectIdString, optionalText, readJsonBody } from '@/lib/input';
import { cleanTrackUrls, safeHttpsUrl } from '@/lib/url-policy';

const SOURCES = ['youtube', 'soundcloud'];
const unsupported = () => NextResponse.json({ success: false, message: 'Unsupported content type.' }, { status: 415 });

// POST /api/playlist/song — add a song to a playlist
export async function POST(request) {
  try {
    const userId = await getRequestUserId({ allowGuest: true });
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }
    const body = await readJsonBody(request);
    if (body === undefined) return unsupported();

    const song = body?.song;
    const songId = boundedText(song?.id, LIMITS.id);
    const title = boundedText(song?.title, LIMITS.text);
    if (!isObjectIdString(body?.playlistId) || !songId || !title) {
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

    if (playlist.songs.some((s) => s.id === songId)) {
      return NextResponse.json({ success: false, message: 'already_exists' }, { status: 409 });
    }
    if (playlist.songs.length >= LIMITS.playlistSongs) {
      return NextResponse.json({ success: false, message: 'playlist_full' }, { status: 409 });
    }

    const urls = cleanTrackUrls(song);
    // One atomic write: the filter repeats the duplicate and size checks, so concurrent requests cannot both add the song.
    const result = await Playlist.updateOne(
      {
        _id: body.playlistId,
        userId,
        'songs.id': { $ne: songId },
        [`songs.${LIMITS.playlistSongs - 1}`]: { $exists: false },
      },
      {
        $push: {
          songs: {
            id: songId,
            title,
            thumbnail: safeHttpsUrl(song.thumbnail) ?? undefined,
            artist: optionalText(song.artist, LIMITS.text),
            publishedAt: optionalText(song.publishedAt, 64),
            source: SOURCES.includes(song.source) ? song.source : 'youtube',
            embedUrl: urls.embedUrl,
            sourceUrl: urls.sourceUrl,
          },
        },
      }
    );

    if (result.matchedCount === 0) {
      return NextResponse.json({ success: false, message: 'conflict' }, { status: 409 });
    }
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
    const body = await readJsonBody(request);
    if (body === undefined) return unsupported();

    if (!isObjectIdString(body?.playlistId) || typeof body?.songId !== 'string' || !body.songId) {
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
