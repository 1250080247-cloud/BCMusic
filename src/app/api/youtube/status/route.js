import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import { getRequestUserId } from '@/lib/request-user';
import { formatYouTubeStatus, isYouTubeSyncAvailable } from '@/lib/youtube-sync';
import YouTubeConnection from '@/models/YouTubeConnection';

export async function GET() {
  try {
    const available = isYouTubeSyncAvailable();
    if (!available) {
      return NextResponse.json(formatYouTubeStatus(null, false), {
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
    const conn = await YouTubeConnection.findOne({ userId }).lean();
    return NextResponse.json(formatYouTubeStatus(conn, true), {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    console.error('YouTube status error:', error);
    return NextResponse.json(
      { success: false, message: 'Không kiểm tra được trạng thái YouTube.' },
      { status: 500, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
