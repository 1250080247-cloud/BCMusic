import bcrypt from 'bcryptjs';
import dbConnect from '@/lib/mongodb';
import User from '@/models/User';
import { NextResponse } from 'next/server';

export async function POST(request) {
  try {
    const { username, password, displayName } = await request.json();

    if (!username || !password) {
      return NextResponse.json({ message: 'Tên đăng nhập và mật khẩu là bắt buộc.' }, { status: 400 });
    }
    if (username.length < 3 || username.length > 30) {
      return NextResponse.json({ message: 'Tên đăng nhập phải từ 3-30 ký tự.' }, { status: 400 });
    }
    if (password.length < 6) {
      return NextResponse.json({ message: 'Mật khẩu phải ít nhất 6 ký tự.' }, { status: 400 });
    }

    await dbConnect();

    const existing = await User.findOne({ username: username.toLowerCase().trim() });
    if (existing) {
      return NextResponse.json({ message: 'Tên đăng nhập đã tồn tại.' }, { status: 409 });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    await User.create({
      username: username.toLowerCase().trim(),
      displayName: displayName?.trim() || username.trim(),
      password: hashedPassword,
    });

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Register error:', error);
    return NextResponse.json({ message: 'Lỗi máy chủ.' }, { status: 500 });
  }
}
