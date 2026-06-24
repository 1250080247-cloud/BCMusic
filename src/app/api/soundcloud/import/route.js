import dbConnect from '@/lib/mongodb';
import { resolveSoundCloudUrl } from '@/lib/soundcloud';
import SoundCloudTrack from '@/models/SoundCloudTrack';
import { NextResponse } from 'next/server';

/**
 * POST /api/soundcloud/import
 * Body: { userId: string, url: string }
 *
 * Resolves a SoundCloud URL via oEmbed, saves the track metadata to MongoDB.
 */
export async function POST(request) {
  try {
    const body = await request.json();

    if (!body?.userId || !body?.url?.trim()) {
      return NextResponse.json(
        { success: false, message: 'Missing userId or SoundCloud URL.' },
        { status: 400 }
      );
    }

    const scUrl = body.url.trim();

    // Validate that it looks like a SoundCloud URL
    if (!scUrl.includes('soundcloud.com/')) {
      return NextResponse.json(
        { success: false, message: 'invalid_url' },
        { status: 400 }
      );
    }

    // Resolve metadata via oEmbed
    const trackData = await resolveSoundCloudUrl(scUrl);

    await dbConnect();

    // Check if already imported by this user
    const existing = await SoundCloudTrack.findOne({
      userId: body.userId,
      scId: trackData.id,
    }).lean();

    if (existing) {
      return NextResponse.json(
        { success: false, message: 'already_imported' },
        { status: 409 }
      );
    }

    // Save to MongoDB
    const newTrack = await SoundCloudTrack.create({
      scId: trackData.id,
      scTrackId: trackData.scTrackId,
      title: trackData.title,
      artist: trackData.artist,
      thumbnail: trackData.thumbnail,
      sourceUrl: scUrl,
      embedUrl: trackData.embedUrl,
      userId: body.userId,
    });

    return NextResponse.json({
      success: true,
      data: {
        id: trackData.id,
        title: trackData.title,
        artist: trackData.artist,
        thumbnail: trackData.thumbnail,
        sourceUrl: scUrl,
        embedUrl: trackData.embedUrl,
        source: 'soundcloud',
        importedAt: newTrack.importedAt.toISOString(),
      },
    });
  } catch (error) {
    console.error('SoundCloud import error:', error);

    const statusCode = error.message?.includes('oEmbed failed') ? 422 : 500;
    return NextResponse.json(
      { success: false, message: error.message },
      { status: statusCode }
    );
  }
}

/**
 * GET /api/soundcloud/import?userId=xxx
 *
 * Returns all SoundCloud tracks imported by a user.
 */
export async function GET(request) {
  try {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get('userId');

    if (!userId) {
      return NextResponse.json(
        { success: false, message: 'Missing userId.' },
        { status: 400 }
      );
    }

    await dbConnect();

    const tracks = await SoundCloudTrack.find({ userId })
      .sort({ importedAt: -1 })
      .lean();

    const formatted = tracks.map((t) => ({
      id: t.scId,
      title: t.title,
      artist: t.artist,
      thumbnail: t.thumbnail,
      sourceUrl: t.sourceUrl,
      embedUrl: t.embedUrl,
      source: 'soundcloud',
      importedAt: t.importedAt ? new Date(t.importedAt).toISOString() : null,
    }));

    return NextResponse.json({ success: true, data: formatted });
  } catch (error) {
    console.error('SoundCloud tracks GET error:', error);
    return NextResponse.json(
      { success: false, message: error.message },
      { status: 500 }
    );
  }
}

/**
 * DELETE /api/soundcloud/import
 * Body: { userId: string, scId: string }
 *
 * Removes an imported SoundCloud track.
 */
export async function DELETE(request) {
  try {
    const body = await request.json();

    if (!body?.userId || !body?.scId) {
      return NextResponse.json(
        { success: false, message: 'Missing userId or scId.' },
        { status: 400 }
      );
    }

    await dbConnect();

    const result = await SoundCloudTrack.deleteOne({
      userId: body.userId,
      scId: body.scId,
    });

    if (result.deletedCount === 0) {
      return NextResponse.json(
        { success: false, message: 'Track not found.' },
        { status: 404 }
      );
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('SoundCloud track DELETE error:', error);
    return NextResponse.json(
      { success: false, message: error.message },
      { status: 500 }
    );
  }
}
