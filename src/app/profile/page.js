"use client";

import { useSession } from 'next-auth/react';
import { useEffect, useState } from 'react';
import { Heart, Music, Edit2, Check, X, Camera, Calendar, Play } from 'lucide-react';
import Link from 'next/link';
import { useMusicStore } from '@/lib/store';

export default function ProfilePage() {
  const { data: session, update: updateSession } = useSession();
  const [playlists, setPlaylists] = useState([]);
  const [loadingPlaylists, setLoadingPlaylists] = useState(true);
  const [editing, setEditing] = useState(false);
  const [form, setForm] = useState({ displayName: '', image: '' });
  const [updating, setUpdating] = useState(false);
  const [error, setError] = useState('');

  const { favorites, setCurrentSong, setPlaylist, setViewingSong } = useMusicStore();

  useEffect(() => {
    if (session?.user) {
      setForm({
        displayName: session.user.name || '',
        image: session.user.image || '',
      });
      // Fetch Playlists
      setLoadingPlaylists(true);
      fetch(`/api/playlist?userId=${session.user.id}`)
        .then((res) => res.json())
        .then((data) => {
          if (data.success) {
            setPlaylists(data.data || []);
          }
          setLoadingPlaylists(false);
        })
        .catch((err) => {
          console.error(err);
          setLoadingPlaylists(false);
        });
    }
  }, [session]);

  if (!session) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[60vh] px-4 text-center">
        <div className="p-4 rounded-full bg-pink-500/10 text-pink-500 mb-4 animate-pulse">
          <Heart size={48} fill="currentColor" />
        </div>
        <h2 className="text-xl font-bold mb-2">Bạn chưa đăng nhập</h2>
        <p className="text-sm text-[var(--muted-text)] mb-6 max-w-sm">
          Đăng nhập để xem hồ sơ cá nhân, đồng bộ bài hát yêu thích và quản lý danh sách phát của bạn.
        </p>
        <Link href="/" className="auth-submit px-6 py-2.5 rounded-full text-sm font-semibold max-w-xs text-center">
          Quay lại Trang Chủ
        </Link>
      </div>
    );
  }

  const handleFileChange = (e) => {
    const file = e.target.files[0];
    if (!file) return;

    if (file.size > 2 * 1024 * 1024) {
      setError('Kích thước ảnh phải nhỏ hơn 2MB.');
      return;
    }

    const reader = new FileReader();
    reader.onloadend = () => {
      setForm((prev) => ({ ...prev, image: reader.result }));
      setError('');
    };
    reader.readAsDataURL(file);
  };

  const handleSave = async (e) => {
    e.preventDefault();
    setUpdating(true);
    setError('');

    try {
      const res = await fetch('/api/user/update', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId: session.user.id,
          displayName: form.displayName,
          image: form.image,
        }),
      });

      const data = await res.json();
      if (!res.ok) {
        throw new Error(data.message || 'Cập nhật thất bại.');
      }

      // Update local NextAuth session cache without storing huge Base64 in cookie
      await updateSession({
        ...session,
        user: {
          ...session.user,
          name: form.displayName,
          image: `/api/user/avatar?userId=${session.user.id}&t=${Date.now()}`,
        },
      });

      // Force page reload or state sync
      window.location.reload();
      setEditing(false);
    } catch (err) {
      setError(err.message);
    } finally {
      setUpdating(false);
    }
  };

  const openSong = (song) => {
    // Single click: mở modal thông tin bài hát (giống trang chủ)
    setViewingSong(song);
    setPlaylist(favorites);
  };

  const playSong = (song) => {
    // Double click: phát ngay
    setCurrentSong(song);
    setPlaylist(favorites);
  };

  return (
    <div className="max-w-6xl mx-auto px-4 py-8 md:py-12">
      {/* Profile Header */}
      <div className="relative overflow-hidden rounded-3xl surface-card p-6 md:p-8 mb-8 flex flex-col md:flex-row items-center gap-6 md:gap-8">
        <div className="absolute top-0 right-0 w-64 h-64 bg-pink-500/10 rounded-full blur-3xl -z-10" />
        <div className="absolute bottom-0 left-0 w-64 h-64 bg-violet-500/10 rounded-full blur-3xl -z-10" />

        {/* Avatar */}
        <div className="relative group flex-shrink-0">
          <div className="w-28 h-28 md:w-32 md:h-32 rounded-full overflow-hidden border-4 border-pink-500/30 shadow-2xl relative bg-[var(--surface-strong)]">
            {form.image ? (
              // eslint-disable-next-line @next/next/no-img-element
              <img src={form.image} alt="" className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full flex items-center justify-center text-[var(--muted-text)]">
                <Camera size={40} />
              </div>
            )}
          </div>

          {editing && (
            <label className="absolute inset-0 bg-black/60 rounded-full flex flex-col items-center justify-center text-white cursor-pointer opacity-0 group-hover:opacity-100 transition-opacity duration-200">
              <Camera size={20} className="mb-1" />
              <span className="text-[10px] font-medium">Đổi ảnh</span>
              <input type="file" accept="image/*" onChange={handleFileChange} className="hidden" />
            </label>
          )}
        </div>

        {/* User details & Form */}
        <div className="flex-1 text-center md:text-left">
          {editing ? (
            <form onSubmit={handleSave} className="flex flex-col gap-3 max-w-md mx-auto md:mx-0">
              <div>
                <label className="block text-xs font-bold text-[var(--muted-text)] mb-1 uppercase tracking-wider">
                  Tên hiển thị
                </label>
                <input
                  type="text"
                  value={form.displayName}
                  onChange={(e) => setForm({ ...form, displayName: e.target.value })}
                  className="w-full px-4 py-2 rounded-xl bg-[var(--surface-strong)] border border-[var(--border)] outline-none focus:border-pink-500 text-sm"
                  required
                />
              </div>

              <div>
                <label className="block text-xs font-bold text-[var(--muted-text)] mb-1 uppercase tracking-wider">
                  Đường dẫn ảnh trực tiếp (URL)
                </label>
                <input
                  type="text"
                  value={form.image}
                  onChange={(e) => setForm({ ...form, image: e.target.value })}
                  placeholder="Hoặc điền link ảnh trực tiếp..."
                  className="w-full px-4 py-2 rounded-xl bg-[var(--surface-strong)] border border-[var(--border)] outline-none focus:border-pink-500 text-sm"
                />
              </div>

              {error && <p className="text-xs text-red-400 font-medium">{error}</p>}

              <div className="flex gap-2 mt-2 justify-center md:justify-start">
                <button
                  type="submit"
                  disabled={updating}
                  className="flex items-center gap-1.5 px-4 py-2 rounded-xl bg-pink-500 text-white text-xs font-bold hover:bg-pink-600 transition disabled:opacity-50"
                >
                  <Check size={14} />
                  {updating ? 'Đang lưu...' : 'Lưu'}
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setEditing(false);
                    setForm({
                      displayName: session.user.name || '',
                      image: session.user.image || '',
                    });
                  }}
                  className="flex items-center gap-1.5 px-4 py-2 rounded-xl bg-[var(--surface-strong)] border border-[var(--border)] text-xs font-bold hover:bg-[var(--surface-hover)] transition"
                >
                  <X size={14} />
                  Hủy
                </button>
              </div>
            </form>
          ) : (
            <div>
              <div className="flex items-center justify-center md:justify-start gap-3 mb-1">
                <h1 className="text-2xl md:text-3xl font-extrabold text-[var(--app-text)]">
                  {session.user.name || session.user.username}
                </h1>
                <button
                  onClick={() => setEditing(true)}
                  className="p-1.5 rounded-lg bg-[var(--surface-strong)] text-[var(--muted-text)] hover:text-[var(--app-text)] hover:bg-[var(--surface-hover)] transition"
                  title="Chỉnh sửa hồ sơ"
                >
                  <Edit2 size={14} />
                </button>
              </div>
              <p className="text-sm text-[var(--muted-text)] font-semibold mb-4">
                @{session.user.username || 'user'}
              </p>

              <div className="flex flex-wrap items-center justify-center md:justify-start gap-4 text-xs text-[var(--muted-text)] font-medium">
                <div className="flex items-center gap-1.5">
                  <Calendar size={14} />
                  <span>Tài khoản {session.user.email ? 'Google' : 'Thường'}</span>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>

      {/* Playlists and Favorites Grid */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
        {/* Favorited Songs (2/3 width on large screens) */}
        <div className="lg:col-span-2 flex flex-col gap-4">
          <div className="flex items-center justify-between">
            <h2 className="text-lg font-bold flex items-center gap-2">
              <Heart size={20} className="text-pink-500" fill="currentColor" />
              Bài nhạc đã tim ({favorites?.length || 0})
            </h2>
          </div>

          <div className="surface-card rounded-2xl p-4 flex flex-col gap-2 min-h-[300px]">
            {favorites?.length > 0 ? (
              <div className="flex flex-col gap-1 max-h-[500px] overflow-y-auto pr-1">
                {favorites.map((song, idx) => (
                  <div
                    key={song.id + idx}
                    onClick={() => openSong(song)}
                    onDoubleClick={() => playSong(song)}
                    className="flex items-center justify-between p-2 rounded-xl hover:bg-[var(--surface-hover)] transition cursor-pointer group"
                    title="Click để xem chi tiết · Double click để phát ngay"
                  >
                    <div className="flex items-center gap-3 min-w-0">
                      {/* Thumbnail */}
                      <div className="w-12 h-12 rounded-lg overflow-hidden relative flex-shrink-0 bg-[var(--surface-strong)]">
                        {song.thumbnail ? (
                          // eslint-disable-next-line @next/next/no-img-element
                          <img src={song.thumbnail} alt="" className="w-full h-full object-cover" />
                        ) : (
                          <div className="w-full h-full flex items-center justify-center text-[var(--muted-text)]">
                            <Music size={18} />
                          </div>
                        )}
                        <div className="absolute inset-0 bg-black/40 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity">
                          <Play size={16} className="text-white fill-white" />
                        </div>
                      </div>

                      {/* Song details */}
                      <div className="min-w-0">
                        <p
                          className="text-sm font-bold text-[var(--app-text)] truncate"
                          dangerouslySetInnerHTML={{ __html: song.title }}
                        />
                        <p className="text-xs text-[var(--muted-text)] truncate mt-0.5">
                          {song.artist}
                        </p>
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            ) : (
              <div className="flex-1 flex flex-col items-center justify-center text-center p-8">
                <Heart size={32} className="text-[var(--muted-text)]/40 mb-3" />
                <p className="text-sm font-bold text-[var(--muted-text)]">Chưa có bài hát nào được tim</p>
                <p className="text-xs text-[var(--muted-text)] mt-1 max-w-[240px]">
                  Bấm nút tim khi nghe nhạc để lưu bài hát yêu thích của bạn tại đây.
                </p>
              </div>
            )}
          </div>
        </div>

        {/* Playlists (1/3 width) */}
        <div className="flex flex-col gap-4">
          <h2 className="text-lg font-bold flex items-center gap-2">
            <Music size={20} className="text-pink-500" />
            Playlist của bạn ({playlists.length})
          </h2>

          <div className="surface-card rounded-2xl p-4 flex flex-col gap-2 min-h-[300px]">
            {loadingPlaylists ? (
              <div className="flex-1 flex items-center justify-center">
                <div className="auth-spinner" />
              </div>
            ) : playlists.length > 0 ? (
              <div className="flex flex-col gap-1 max-h-[500px] overflow-y-auto pr-1">
                {playlists.map((playlist) => (
                  <Link
                    key={playlist.id}
                    href="/playlist" // Vì library / playlist page hiển thị ở đây
                    className="flex items-center gap-3 p-2.5 rounded-xl hover:bg-[var(--surface-hover)] transition cursor-pointer"
                  >
                    <div className="w-12 h-12 rounded-lg bg-pink-500/10 text-pink-500 flex items-center justify-center flex-shrink-0">
                      <Music size={20} />
                    </div>
                    <div className="min-w-0">
                      <p className="text-sm font-bold text-[var(--app-text)] truncate">
                        {playlist.name}
                      </p>
                      <p className="text-xs text-[var(--muted-text)] mt-0.5">
                        {playlist.songs?.length || 0} bài hát
                      </p>
                    </div>
                  </Link>
                ))}
              </div>
            ) : (
              <div className="flex-1 flex flex-col items-center justify-center text-center p-8">
                <Music size={32} className="text-[var(--muted-text)]/40 mb-3" />
                <p className="text-sm font-bold text-[var(--muted-text)]">Chưa có playlist nào</p>
                <p className="text-xs text-[var(--muted-text)] mt-1 max-w-[200px]">
                  Tạo danh sách phát mới trong thư viện của bạn.
                </p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
