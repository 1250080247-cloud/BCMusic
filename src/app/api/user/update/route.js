import dbConnect from '@/lib/mongodb';
import User from '@/models/User';
import { NextResponse } from 'next/server';

export async function POST(request) {
  try {
    await dbConnect();
    const body = await request.json();
    const { userId, displayName, image } = body;

    if (!userId) {
      return NextResponse.json({ success: false, message: 'Missing userId.' }, { status: 400 });
    }

    const updateData = {};
    if (displayName !== undefined) updateData.displayName = displayName.trim();
    if (image !== undefined) updateData.image = image.trim();

    const updatedUser = await User.findByIdAndUpdate(
      userId,
      { $set: updateData },
      { returnDocument: 'after' }
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
    return NextResponse.json({ success: false, message: error.message }, { status: 500 });
  }
}
