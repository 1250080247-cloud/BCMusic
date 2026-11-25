import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import { getRequestUserId } from '@/lib/request-user';
import {
  YouTubeReconnectError,
  buildCollectionsPayload,
  isYouTubeCacheFresh,
  isYouTubeSyncAvailable,
  syncYouTubeConnection,
} from '@/lib/youtube-sync';
import YouTubeConnection from '@/models/YouTubeConnection';

export async function GET() {
  try {
    if (!isYouTubeSyncAvailable()) {
      return NextResponse.json(buildCollectionsPayload(null), {
        headers: { 'Cache-Control': 'no-store' },
      });
    }

    const userId = await getRequestUserId({ allowGuest: false });
    if (!userId) {
      return NextResponse.json(
        { success: false, message: 'Chưa đăng nhập.' },
        { status: 401, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    await dbConnect();
    let conn = await YouTubeConnection.findOne({ userId });
    if (conn && conn.status !== 'expired' && !isYouTubeCacheFresh(conn)) {
      try {
        conn = await syncYouTubeConnection(conn, {
          YouTubeConnectionModel: YouTubeConnection,
        });
      } catch (error) {
        if (error instanceof YouTubeReconnectError) {
          const plainConn = typeof conn?.toObject === 'function' ? conn.toObject() : conn;
          return NextResponse.json(
            buildCollectionsPayload({ ...plainConn, status: 'expired' }),
            { headers: { 'Cache-Control': 'no-store' } },
          );
        }
        // Serve stale cached collections if YouTube is temporarily unreachable.
      }
    }

    return NextResponse.json(buildCollectionsPayload(conn), {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    console.error('YouTube collections error:', error);
    return NextResponse.json(
      { success: false, message: 'Không tải được playlist YouTube.' },
      { status: 500, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
