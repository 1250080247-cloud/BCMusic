import bcrypt from 'bcryptjs';
import dbConnect from '@/lib/mongodb';
import User from '@/models/User';
import { NextResponse } from 'next/server';
import { boundedText, readJsonBody } from '@/lib/input';
import { clientKey, consumeRateLimit } from '@/lib/rate-limit';

// Lowercase letters, digits, underscore and dot. Matches the usernames Google sign-in creates.
const USERNAME_PATTERN = /^[a-z0-9_.]{3,30}$/;

export async function POST(request) {
  try {
    if (!(await consumeRateLimit(`register:${clientKey(request)}`, { limit: 5, windowMs: 60 * 60_000 }))) {
      return NextResponse.json({ message: 'Bạn đã đăng ký quá nhiều lần. Thử lại sau.' }, { status: 429, headers: { 'Retry-After': '3600' } });
    }

    const body = await readJsonBody(request);
    if (body === undefined) {
      return NextResponse.json({ message: 'Unsupported content type.' }, { status: 415 });
    }
    const { username, password, displayName } = body || {};

    if (typeof username !== 'string' || typeof password !== 'string' || !username || !password) {
      return NextResponse.json({ message: 'Tên đăng nhập và mật khẩu là bắt buộc.' }, { status: 400 });
    }
    const normalized = username.toLowerCase().trim();
    if (!USERNAME_PATTERN.test(normalized)) {
      return NextResponse.json({ message: 'Tên đăng nhập phải từ 3-30 ký tự: chữ thường không dấu, số, _ hoặc .' }, { status: 400 });
    }
    if (password.length < 6) {
      return NextResponse.json({ message: 'Mật khẩu phải ít nhất 6 ký tự.' }, { status: 400 });
    }
    // bcrypt ignores bytes after 72, so a longer password would silently match a shorter one.
    if (Buffer.byteLength(password, 'utf8') > 72) {
      return NextResponse.json({ message: 'Mật khẩu tối đa 72 byte.' }, { status: 400 });
    }

    await dbConnect();

    const existing = await User.findOne({ username: normalized });
    if (existing) {
      return NextResponse.json({ message: 'Tên đăng nhập đã tồn tại.' }, { status: 409 });
    }

    const hashedPassword = await bcrypt.hash(password, 10);
    try {
      await User.create({
        username: normalized,
        displayName: boundedText(displayName, 50) || username.trim(),
        password: hashedPassword,
      });
    } catch (error) {
      if (error.code === 11000) {
        return NextResponse.json({ message: 'Tên đăng nhập đã tồn tại.' }, { status: 409 });
      }
      throw error;
    }

    return NextResponse.json({ success: true });
  } catch (error) {
    console.error('Register error:', error);
    return NextResponse.json({ message: 'Lỗi máy chủ.' }, { status: 500 });
  }
}
