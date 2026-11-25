import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import { consumeRateLimit } from '@/lib/rate-limit';
import { getRequestUserId } from '@/lib/request-user';
import {
  YouTubeReconnectError,
  formatYouTubeStatus,
  isYouTubeSyncAvailable,
  syncYouTubeConnection,
} from '@/lib/youtube-sync';
import YouTubeConnection from '@/models/YouTubeConnection';

export async function POST() {
  try {
    if (!isYouTubeSyncAvailable()) {
      return NextResponse.json(
        { success: false, available: false, message: 'Tính năng đồng bộ YouTube chưa được bật.' },
        { status: 503, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    const userId = await getRequestUserId({ allowGuest: false });
    if (!userId) {
      return NextResponse.json(
        { success: false, message: 'Chưa đăng nhập.' },
        { status: 401, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    const allowed = await consumeRateLimit(`youtube-sync:${userId}`, {
      limit: 3,
      windowMs: 60 * 60 * 1000,
    });
    if (!allowed) {
      return NextResponse.json(
        { success: false, message: 'Bạn chỉ có thể đồng bộ thủ công tối đa 3 lần mỗi giờ.' },
        { status: 429, headers: { 'Cache-Control': 'no-store', 'Retry-After': '3600' } },
      );
    }

    await dbConnect();
    const conn = await YouTubeConnection.findOne({ userId });
    if (!conn) {
      return NextResponse.json(
        { success: false, message: 'Bạn chưa kết nối tài khoản YouTube.' },
        { status: 404, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    try {
      const updated = await syncYouTubeConnection(conn, {
        YouTubeConnectionModel: YouTubeConnection,
      });
      return NextResponse.json(
        { success: true, ...formatYouTubeStatus(updated, true) },
        { headers: { 'Cache-Control': 'no-store' } },
      );
    } catch (error) {
      if (error instanceof YouTubeReconnectError) {
        return NextResponse.json(
          {
            success: false,
            message: error.message,
            ...formatYouTubeStatus({ ...conn, status: 'expired' }, true),
          },
          { status: 200, headers: { 'Cache-Control': 'no-store' } },
        );
      }
      throw error;
    }
  } catch (error) {
    console.error('YouTube sync error:', error);
    return NextResponse.json(
      { success: false, message: 'Không thể đồng bộ dữ liệu YouTube lúc này.' },
      { status: 500, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
