"use client";

import { useState } from 'react';
import { signIn, useSession } from 'next-auth/react';

export default function MobileSignIn({ state, challenge }) {
  const { data: session, status } = useSession();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [callback, setCallback] = useState('');
  const valid = Boolean(state && challenge);

  async function google() {
    setBusy(true);
    setError('');
    try {
      await signIn('google', { callbackUrl: window.location.href }, { prompt: 'select_account' });
    } catch {
      setError('Không mở được đăng nhập Google. Hãy thử lại.');
    } finally {
      setBusy(false);
    }
  }

  async function connect() {
    setBusy(true);
    setError('');
    try {
      const response = await fetch('/api/mobile/auth/authorize', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ state, challenge }),
      });
      const { code } = await response.json();
      if (!response.ok || !/^[A-Za-z0-9_-]{43}$/.test(code)) throw new Error();
      setCallback(`app.bcmusic.personal://account/complete?${new URLSearchParams({ code, state })}`);
    } catch {
      setError('Chưa xác nhận được phiên BCMusic. Hãy thử lại.');
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="mx-auto max-w-md px-5 py-10">
      <section className="surface-card space-y-4 rounded-3xl p-6">
        <h1 className="text-xl font-bold">Kết nối BCMusic Android</h1>
        {!valid ? (
          <p className="muted-text">Mở Đăng nhập bằng Google từ ứng dụng BCMusic để bắt đầu.</p>
        ) : callback ? (
          <a className="auth-submit block text-center" href={callback}>Quay lại BCMusic</a>
        ) : status === 'loading' ? (
          <p className="muted-text" role="status">Đang kiểm tra tài khoản…</p>
        ) : session?.user?.id ? (
          <>
            <p>Kết nối với tài khoản <strong>{session.user.name || session.user.username}</strong> trên điện thoại này?</p>
            <button className="auth-submit" type="button" disabled={busy} onClick={connect}>Xác nhận kết nối</button>
            <button className="auth-google-btn" type="button" disabled={busy} onClick={google}>Chọn tài khoản Google khác</button>
          </>
        ) : (
          <button className="auth-google-btn" type="button" disabled={busy} onClick={google}>Đăng nhập bằng Google</button>
        )}
        {error && <p role="alert" className="muted-text">{error}</p>}
      </section>
    </main>
  );
}
