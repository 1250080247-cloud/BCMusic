import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import { getRequestUserId } from '@/lib/request-user';
import {
  YouTubeReconnectError,
  buildForYouPayload,
  isYouTubeCacheFresh,
  isYouTubeSyncAvailable,
  syncYouTubeConnection,
} from '@/lib/youtube-sync';
import YouTubeConnection from '@/models/YouTubeConnection';

export async function GET() {
  try {
    if (!isYouTubeSyncAvailable()) {
      return NextResponse.json(
        { connected: false, needsReconnect: false, sections: [] },
        { headers: { 'Cache-Control': 'no-store' } },
      );
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
          return NextResponse.json(
            { connected: false, needsReconnect: true, sections: [] },
            { headers: { 'Cache-Control': 'no-store' } },
          );
        }
      }
    }

    const payload = await buildForYouPayload(conn);
    return NextResponse.json(payload, {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    console.error('YouTube for-you error:', error);
    return NextResponse.json(
      { success: false, message: 'Không tải được gợi ý từ YouTube.' },
      { status: 500, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
