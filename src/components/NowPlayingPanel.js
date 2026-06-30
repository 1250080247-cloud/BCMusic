"use client";

import { Heart, MoreVertical, X } from 'lucide-react';
import Image from 'next/image';
import { useSession } from 'next-auth/react';
import { getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore } from '@/lib/store';

export default function NowPlayingPanel() {
  const { data: session } = useSession();
  const {
    currentSong,
    nowPlayingOpen,
    setNowPlayingOpen,
    favorites,
    addFavorite,
    removeFavorite,
  } = useMusicStore();
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  if (!currentSong || !nowPlayingOpen) return null;

  const isFavorited = favorites?.some((s) => s.id === currentSong.id);

  const handleFavoriteToggle = async () => {
    if (!session?.user?.id) {
      alert(language === 'vi' ? 'Vui lòng đăng nhập để lưu bài hát yêu thích!' : 'Please sign in to favorite songs!');
      return;
    }

    const userId = session.user.id;
    if (isFavorited) {
      try {
        const res = await fetch(`/api/favorites?userId=${userId}&songId=${currentSong.id}`, {
          method: 'DELETE',
        });
        if (res.ok) {
          removeFavorite(currentSong.id);
        }
      } catch (err) {
        console.error('Error removing favorite:', err);
      }
    } else {
      try {
        const res = await fetch('/api/favorites', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            userId,
            song: currentSong,
          }),
        });
        if (res.ok) {
          addFavorite(currentSong);
        }
      } catch (err) {
        console.error('Error adding favorite:', err);
      }
    }
  };

  return (
    <aside className="now-playing-panel">
      {/* Header */}
      <div className="now-playing-header">
        <div className="now-playing-header-left">
          <span className="now-playing-label">{t.nowPlaying.title}</span>
          <div className="now-playing-header-title-marquee">
            <div className="now-playing-header-title-track">
              <span
                className="now-playing-header-title-copy"
                dangerouslySetInnerHTML={{ __html: currentSong.title }}
              />
              <span
                className="now-playing-header-title-copy"
                aria-hidden="true"
                dangerouslySetInnerHTML={{ __html: currentSong.title }}
              />
            </div>
          </div>
        </div>
        <div className="now-playing-header-actions">
          <button
            type="button"
            aria-label="More options"
            className="now-playing-icon-btn"
          >
            <MoreVertical size={18} />
          </button>
          <button
            type="button"
            aria-label={t.nowPlaying.close}
            onClick={() => setNowPlayingOpen(false)}
            className="now-playing-icon-btn"
          >
            <X size={18} />
          </button>
        </div>
      </div>

      {/* Large Thumbnail */}
      <div className="now-playing-artwork">
        {currentSong.thumbnail && (
          <Image
            src={currentSong.thumbnail}
            alt=""
            fill
            sizes="(max-width: 768px) 100vw, 360px"
            className="object-cover"
            priority
          />
        )}
        <div className="now-playing-artwork-overlay" />
      </div>

      {/* Footer */}
      <div className="now-playing-footer">
        <div className="now-playing-footer-info">
          <h3
            className="now-playing-footer-title"
            dangerouslySetInnerHTML={{ __html: currentSong.title }}
          />
          <p className="now-playing-footer-artist">{currentSong.artist}</p>
        </div>
        <button
          type="button"
          aria-label="Favorite"
          onClick={handleFavoriteToggle}
          className={`now-playing-icon-btn now-playing-fav-btn ${isFavorited ? 'text-pink-500 hover:text-pink-600' : ''}`}
        >
          <Heart size={22} fill={isFavorited ? 'currentColor' : 'none'} />
        </button>
      </div>
    </aside>
  );
}
