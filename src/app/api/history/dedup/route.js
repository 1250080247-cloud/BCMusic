import { getServerSession } from 'next-auth';
import dbConnect from '@/lib/mongodb';
import History from '@/models/History';
import { authOptions } from '@/app/api/auth/[...nextauth]/route';
import { NextResponse } from 'next/server';

// Xóa các bản ghi duplicate trong history của user hiện tại
// Giữ lại bản ghi có listenedAt mới nhất cho mỗi (userId, songId)
export async function POST(request) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user?.id) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }

    await dbConnect();
    const userId = session.user.id;

    // Lấy tất cả history của user, sort by listenedAt desc
    const all = await History.find({ userId }).sort({ listenedAt: -1 }).lean();

    // Group by songId — giữ cái đầu tiên (newest), xóa phần còn lại
    const seen = new Set();
    const toDelete = [];
    for (const doc of all) {
      if (seen.has(doc.songId)) {
        toDelete.push(doc._id);
      } else {
        seen.add(doc.songId);
      }
    }

    let deleted = 0;
    if (toDelete.length > 0) {
      const result = await History.deleteMany({ _id: { $in: toDelete } });
      deleted = result.deletedCount;
    }

    return NextResponse.json({
      success: true,
      message: `Đã xóa ${deleted} bản ghi trùng lặp.`,
      deleted,
    });
  } catch (error) {
    console.error('Dedup error:', error);
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
