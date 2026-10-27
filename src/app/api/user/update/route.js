import { getRequestUserId } from '@/lib/request-user';
import { isAllowedAvatar } from '@/lib/avatar';
import dbConnect from '@/lib/mongodb';
import User from '@/models/User';
import { NextResponse } from 'next/server';

export async function POST(request) {
  try {
    const userId = await getRequestUserId();
    if (!userId) {
      return NextResponse.json({ success: false, message: 'Chưa đăng nhập.' }, { status: 401 });
    }
    const body = await request.json();
    const { displayName, image } = body || {};
    const updateData = {};
    if (displayName !== undefined) {
      if (typeof displayName !== 'string' || !displayName.trim() || displayName.trim().length > 50) {
        return NextResponse.json({ success: false, message: 'Tên hiển thị phải từ 1–50 ký tự.' }, { status: 400 });
      }
      updateData.displayName = displayName.trim();
    }
    if (image !== undefined) {
      if (typeof image !== 'string' || !isAllowedAvatar(image.trim())) {
        return NextResponse.json({ success: false, message: 'Ảnh phải là PNG, JPEG, GIF, WebP tối đa 2MB hoặc URL HTTPS bên ngoài.' }, { status: 400 });
      }
      updateData.image = image.trim();
    }
    if (!Object.keys(updateData).length) {
      return NextResponse.json({ success: false, message: 'Không có thông tin cập nhật.' }, { status: 400 });
    }

    await dbConnect();
    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { $set: updateData },
      { returnDocument: 'after', runValidators: true }
    );

    if (!updatedUser) {
      return NextResponse.json({ success: false, message: 'User not found.' }, { status: 404 });
    }

    return NextResponse.json({
      success: true,
      data: {
        id: updatedUser._id.toString(),
        displayName: updatedUser.displayName,
        image: updatedUser.image,
      },
    });
  } catch (error) {
    console.error('User update error:', error);
    return NextResponse.json({ success: false, message: 'Không thể cập nhật hồ sơ.' }, { status: 500 });
  }
}
