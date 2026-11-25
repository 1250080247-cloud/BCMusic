import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import { getRequestUserId } from '@/lib/request-user';
import {
  decryptToken,
  formatYouTubeStatus,
  isYouTubeSyncAvailable,
  revokeYouTubeToken,
} from '@/lib/youtube-sync';
import YouTubeConnection from '@/models/YouTubeConnection';

export async function POST() {
  try {
    const available = isYouTubeSyncAvailable();
    const userId = await getRequestUserId({ allowGuest: false });
    if (!userId) {
      return NextResponse.json(
        { success: false, message: 'Chưa đăng nhập.' },
        { status: 401, headers: { 'Cache-Control': 'no-store' } },
      );
    }

    await dbConnect();
    const existing = await YouTubeConnection.findOne({ userId }).lean();
    if (existing && available) {
      const tokenToRevoke = existing.encryptedRefreshToken || existing.encryptedAccessToken;
      if (tokenToRevoke) {
        try {
          const plain = decryptToken(tokenToRevoke);
          await revokeYouTubeToken(plain);
        } catch {
          // Proceed with deleting local connection even if decrypt/revoke fails.
        }
      }
    }

    await YouTubeConnection.deleteOne({ userId });
    return NextResponse.json(
      { success: true, ...formatYouTubeStatus(null, available) },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch (error) {
    console.error('YouTube disconnect error:', error);
    return NextResponse.json(
      { success: false, message: 'Không thể ngắt kết nối YouTube lúc này.' },
      { status: 500, headers: { 'Cache-Control': 'no-store' } },
    );
  }
}
