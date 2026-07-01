"use client";

import { useState } from 'react';
import { createPortal } from 'react-dom';
import { signIn, signOut, useSession } from 'next-auth/react';
import Link from 'next/link';
import { Eye, EyeOff, LogIn, LogOut, UserPlus, X, User, Music2 } from 'lucide-react';

/* ── Google icon SVG ──────────────────────────────── */
function GoogleIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">
      <path fill="#4285F4" d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" />
      <path fill="#34A853" d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" />
      <path fill="#FBBC05" d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" />
      <path fill="#EA4335" d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" />
    </svg>
  );
}

/* ── Auth Dialog (Portal) ─────────────────────────── */
function AuthModalDialog({ mode, setMode, onClose }) {
  const [form, setForm] = useState({ username: '', password: '', displayName: '' });
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [googleLoading, setGoogleLoading] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  const isLogin = mode === 'login';

  const handleChange = (e) => {
    setForm((p) => ({ ...p, [e.target.name]: e.target.value }));
    setError('');
  };

  const handleGoogleSignIn = async () => {
    setGoogleLoading(true);
    await signIn('google', { callbackUrl: window.location.href });
    // page will redirect, no need to setLoading(false)
  };

  const handleLogin = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    const res = await signIn('credentials', {
      username: form.username,
      password: form.password,
      redirect: false,
    });
    setLoading(false);
    if (res?.error) {
      setError('Sai tên đăng nhập hoặc mật khẩu.');
    } else {
      onClose();
    }
  };

  const handleRegister = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    const res = await fetch('/api/auth/register', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(form),
    });
    const data = await res.json();
    if (!res.ok) {
      setLoading(false);
      setError(data.message || 'Đăng ký thất bại.');
      return;
    }
    await signIn('credentials', { username: form.username, password: form.password, redirect: false });
    setLoading(false);
    onClose();
  };

  const switchMode = () => {
    setMode(isLogin ? 'register' : 'login');
    setError('');
    setForm({ username: '', password: '', displayName: '' });
  };

  return createPortal(
    <>
      <div className="auth-overlay" onClick={onClose} />
      <div className="auth-modal" role="dialog" aria-modal="true">

        {/* Brand deco */}
        <div className="auth-modal-deco">
          <div className="auth-modal-deco-icon">
            <Music2 size={24} />
          </div>
          <span className="auth-modal-deco-brand">BCMusic</span>
        </div>

        {/* Title + close */}
        <div className="auth-modal-header">
          <h2 className="auth-modal-title">
            {isLogin ? 'Chào mừng trở lại 👋' : 'Tạo tài khoản mới ✨'}
          </h2>
          <p className="auth-modal-subtitle">
            {isLogin
              ? 'Đăng nhập để lưu lịch sử nghe nhạc'
              : 'Miễn phí · Lưu nhạc vĩnh viễn · Đồng bộ mọi thiết bị'}
          </p>
          <button onClick={onClose} className="auth-modal-close" aria-label="Đóng">
            <X size={17} />
          </button>
        </div>

        {/* Google button */}
        <button
          type="button"
          className="auth-google-btn"
          onClick={handleGoogleSignIn}
          disabled={googleLoading}
        >
          {googleLoading ? (
            <span className="auth-spinner" />
          ) : (
            <GoogleIcon />
          )}
          <span>{isLogin ? 'Đăng nhập bằng Google' : 'Đăng ký bằng Google'}</span>
        </button>

        {/* Divider */}
        <div className="auth-divider">
          <span />
          <p>hoặc dùng tài khoản BCMusic</p>
          <span />
        </div>

        {/* Credentials form */}
        <form onSubmit={isLogin ? handleLogin : handleRegister} className="auth-form">
          {!isLogin && (
            <div className="auth-field">
              <label htmlFor="displayName">Tên hiển thị</label>
              <input
                id="displayName"
                name="displayName"
                type="text"
                value={form.displayName}
                onChange={handleChange}
                placeholder="Tên của bạn (tuỳ chọn)"
                autoComplete="name"
              />
            </div>
          )}

          <div className="auth-field">
            <label htmlFor="username">Tên đăng nhập</label>
            <input
              id="username"
              name="username"
              type="text"
              value={form.username}
              onChange={handleChange}
              placeholder="Ít nhất 3 ký tự"
              required
              autoComplete="username"
            />
          </div>

          <div className="auth-field">
            <label htmlFor="password">Mật khẩu</label>
            <div className="auth-password-wrapper">
              <input
                id="password"
                name="password"
                type={showPassword ? 'text' : 'password'}
                value={form.password}
                onChange={handleChange}
                placeholder={isLogin ? '••••••••' : 'Ít nhất 6 ký tự'}
                required
                autoComplete={isLogin ? 'current-password' : 'new-password'}
              />
              <button
                type="button"
                className="auth-password-toggle"
                onClick={() => setShowPassword((v) => !v)}
                aria-label={showPassword ? 'Ẩn mật khẩu' : 'Hiện mật khẩu'}
                tabIndex={-1}
              >
                {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
              </button>
            </div>
          </div>

          {error && <div className="auth-error" role="alert">{error}</div>}

          <button type="submit" className="auth-submit" disabled={loading}>
            {loading
              ? 'Đang xử lý...'
              : isLogin ? 'Đăng nhập' : 'Tạo tài khoản'}
          </button>
        </form>

        {/* Switch mode */}
        <div className="auth-divider" style={{ marginTop: '1rem', marginBottom: '0.75rem' }}>
          <span />
          <p>{isLogin ? 'Chưa có tài khoản?' : 'Đã có tài khoản?'}</p>
          <span />
        </div>
        <button type="button" className="auth-switch-btn" onClick={switchMode}>
          {isLogin ? 'Đăng ký ngay' : 'Đăng nhập'}
        </button>
      </div>
    </>,
    document.body
  );
}

/* ── Sidebar trigger ──────────────────────────────── */
export default function AuthModal() {
  const { data: session, status } = useSession();
  const [mode, setMode] = useState(null);

  if (status === 'loading') return null;

  // Logged in
  if (session) {
    const avatar = session.user.image;
    return (
      <div className="auth-user-info">
        <Link href="/profile" className="flex flex-col items-center gap-1 group" title="Xem hồ sơ">
          {avatar ? (
            // eslint-disable-next-line @next/next/no-img-element
            <img
              src={avatar}
              alt=""
              className="auth-user-avatar auth-user-avatar--img group-hover:scale-105 transition-transform duration-200"
            />
          ) : (
            <div className="auth-user-avatar group-hover:scale-105 transition-transform duration-200">
              <User size={16} />
            </div>
          )}
          <span className="auth-user-name group-hover:text-pink-500 transition-colors">
            {session.user.username || session.user.name}
          </span>
        </Link>
        <button
          onClick={() => signOut({ redirect: false })}
          className="auth-logout-btn"
          title="Đăng xuất"
          aria-label="Đăng xuất"
        >
          <LogOut size={14} />
        </button>
      </div>
    );
  }

  // Not logged in
  return (
    <>
      <div className="auth-icon-buttons">
        <button
          className="auth-icon-btn"
          onClick={() => setMode('login')}
          title="Đăng nhập"
          aria-label="Đăng nhập"
        >
          <LogIn size={18} />
        </button>
        <button
          className="auth-icon-btn auth-icon-btn--accent"
          onClick={() => setMode('register')}
          title="Đăng ký"
          aria-label="Đăng ký"
        >
          <UserPlus size={18} />
        </button>
      </div>

      {mode && <AuthModalDialog mode={mode} setMode={setMode} onClose={() => setMode(null)} />}
    </>
  );
}
