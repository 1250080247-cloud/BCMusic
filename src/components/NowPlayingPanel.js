"use client";

import { Heart, Loader2, MoreVertical, Music2, Radio, X } from 'lucide-react';
import Image from 'next/image';
import { useSession } from 'next-auth/react';
import { useEffect, useRef, useState, useCallback } from 'react';
import { getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore } from '@/lib/store';

/* ════════════════════════════════════════════════════════
   AudioVisualizer
   ════════════════════════════════════════════════════════ */
const NUM_BARS = 40;

function AudioVisualizer({ isPlaying }) {
  const barsRef = useRef(
    Array.from({ length: NUM_BARS }, (_, i) => ({
      height: 0.05,
      target: Math.random() * 0.3 + 0.05,
      velocity: 0,
      phase: (i / NUM_BARS) * Math.PI * 2,
    }))
  );
  const containerRef = useRef(null);
  const animRef = useRef(null);
  const tickRef = useRef(0);

  const animate = useCallback(() => {
    tickRef.current += 1;
    const t = tickRef.current;
    const bars = barsRef.current;
    const container = containerRef.current;
    if (!container) return;

    const els = container.querySelectorAll('.np-vbar');

    bars.forEach((bar, i) => {
      if (isPlaying) {
        const wave = Math.sin(t * 0.04 + bar.phase) * 0.15;
        const wave2 = Math.sin(t * 0.07 + bar.phase * 1.3) * 0.1;
        bar.target = Math.max(0.05, Math.min(0.95, bar.target + wave * 0.04 + wave2 * 0.03));
        if (Math.random() < 0.015) bar.target = Math.random() * 0.75 + 0.2;
        bar.velocity += (bar.target - bar.height) * 0.18;
        bar.velocity *= 0.72;
        bar.height = Math.max(0.04, Math.min(1, bar.height + bar.velocity));
      } else {
        bar.height += (0.04 - bar.height) * 0.06;
        bar.velocity = 0;
        bar.target = 0.04;
      }
      const el = els[i];
      if (el) el.style.height = `${Math.round(bar.height * 100)}%`;
    });

    animRef.current = requestAnimationFrame(animate);
  }, [isPlaying]);

  useEffect(() => {
    animRef.current = requestAnimationFrame(animate);
    return () => { if (animRef.current) cancelAnimationFrame(animRef.current); };
  }, [animate]);

  return (
    <div ref={containerRef} className="np-visualizer-bars" aria-hidden="true">
      {Array.from({ length: NUM_BARS }, (_, i) => (
        <span key={i} className="np-vbar" />
      ))}
    </div>
  );
}

/* ════════════════════════════════════════════════════════
   SimilarSongs — gợi ý bản nhạc tương tự
   ════════════════════════════════════════════════════════ */
function SimilarSongs({ currentSong }) {
  const [songs, setSongs] = useState([]);
  const [loading, setLoading] = useState(false);
  const { setCurrentSong, setViewingSong, setPlaylist } = useMusicStore();
  const prevIdRef = useRef(null);

  useEffect(() => {
    if (!currentSong?.id) return;
    // Không refetch nếu bài không đổi
    if (prevIdRef.current === currentSong.id) return;
    prevIdRef.current = currentSong.id;

    setLoading(true);
    setSongs([]);

    // Tạo query từ artist + từ khóa bài hát (loại bỏ các ký tự đặc biệt)
    const rawTitle = currentSong.title?.replace(/<[^>]*>/g, '') || '';
    // Lấy từ đầu của tiêu đề (tối đa 4 từ) + artist
    const titleWords = rawTitle.split(/[\s\-–|]+/).slice(0, 4).join(' ');
    const artist = currentSong.artist || '';
    const query = artist ? `${artist} ${titleWords}` : titleWords;

    fetch(`/api/explore?q=${encodeURIComponent(query)}&order=relevance`)
      .then(r => r.json())
      .then(data => {
        // Lọc bỏ bài đang phát
        const filtered = (data.items || []).filter(s => s.id !== currentSong.id);
        setSongs(filtered.slice(0, 6));
      })
      .catch(() => setSongs([]))
      .finally(() => setLoading(false));
  }, [currentSong?.id]);

  if (!loading && songs.length === 0) return null;

  return (
    <div className="np-similar-section">
      {/* Header */}
      <div className="np-similar-header">
        <Radio size={14} className="np-similar-icon" />
        <span>Gợi ý tương tự</span>
      </div>

      {loading ? (
        <div className="np-similar-loading">
          <Loader2 size={18} className="np-similar-spinner" />
          <span>Đang tìm bản nhạc phù hợp...</span>
        </div>
      ) : (
        <div className="np-similar-list">
          {songs.map((song) => (
            <button
              key={song.id}
              type="button"
              className="np-similar-item"
              onClick={() => { setViewingSong(song); setPlaylist(songs); }}
              onDoubleClick={() => { setCurrentSong(song); setPlaylist(songs); }}
              title="Click xem chi tiết · Double click phát ngay"
            >
              {/* Thumbnail */}
              <div className="np-similar-thumb">
                {song.thumbnail && (
                  <Image src={song.thumbnail} alt="" fill sizes="44px" className="object-cover" />
                )}
                <div className="np-similar-thumb-overlay">
                  <Music2 size={14} />
                </div>
              </div>

              {/* Info */}
              <div className="np-similar-info">
                <p
                  className="np-similar-title"
                  dangerouslySetInnerHTML={{ __html: song.title }}
                />
                <p className="np-similar-artist">{song.artist}</p>
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

/* ════════════════════════════════════════════════════════
   Main NowPlayingPanel
   ════════════════════════════════════════════════════════ */
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
  const [isPlaying, setIsPlaying] = useState(false);

  useEffect(() => {
    const handler = (e) => setIsPlaying(e.detail?.isPlaying ?? false);
    window.addEventListener('bcmusic:playstate', handler);
    return () => window.removeEventListener('bcmusic:playstate', handler);
  }, []);

  if (!currentSong || !nowPlayingOpen) return null;

  const isFavorited = favorites?.some((s) => s.id === currentSong.id);
  const isSoundCloud = currentSong.source === 'soundcloud';

  const handleFavoriteToggle = async () => {
    if (!session?.user?.id) {
      alert(language === 'vi'
        ? 'Vui lòng đăng nhập để lưu bài hát yêu thích!'
        : 'Please sign in to favorite songs!');
      return;
    }
    const userId = session.user.id;
    if (isFavorited) {
      try {
        const res = await fetch(`/api/favorites?userId=${userId}&songId=${currentSong.id}`, { method: 'DELETE' });
        if (res.ok) removeFavorite(currentSong.id);
      } catch (err) { console.error(err); }
    } else {
      try {
        const res = await fetch('/api/favorites', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ userId, song: currentSong }),
        });
        if (res.ok) addFavorite(currentSong);
      } catch (err) { console.error(err); }
    }
  };

  return (
    <aside className="now-playing-panel">

      {/* ── Header ─────────────────────────────── */}
      <div className="now-playing-header">
        <div className="now-playing-header-left">
          <span className="now-playing-label">{t.nowPlaying.title}</span>
          <div className="now-playing-header-title-marquee">
            <div className="now-playing-header-title-track">
              <span className="now-playing-header-title-copy" dangerouslySetInnerHTML={{ __html: currentSong.title }} />
              <span className="now-playing-header-title-copy" aria-hidden="true" dangerouslySetInnerHTML={{ __html: currentSong.title }} />
            </div>
          </div>
        </div>
        <div className="now-playing-header-actions">
          <button type="button" aria-label="More options" className="now-playing-icon-btn">
            <MoreVertical size={18} />
          </button>
          <button type="button" aria-label={t.nowPlaying.close} onClick={() => setNowPlayingOpen(false)} className="now-playing-icon-btn">
            <X size={18} />
          </button>
        </div>
      </div>

      {/* ── Vinyl Disc ─────────────────────────── */}
      <div className="np-vinyl-wrapper">
        <div className={`np-vinyl-glow${isPlaying ? ' np-vinyl-glow--active' : ''}`} />
        <div className={`np-vinyl-disc${isPlaying ? ' np-vinyl-spin' : ''}`}>
          <div className="np-vinyl-grooves" />
          <div className="np-vinyl-art">
            {currentSong.thumbnail
              ? <Image src={currentSong.thumbnail} alt="" fill sizes="140px" className="object-cover" priority />
              : <div className="np-vinyl-art-fallback"><Music2 size={28} /></div>
            }
          </div>
          <div className="np-vinyl-hole" />
        </div>
        <div className={`np-tonearm${isPlaying ? ' np-tonearm--playing' : ''}`}>
          <div className="np-tonearm-pivot" />
          <div className="np-tonearm-arm" />
          <div className="np-tonearm-head" />
        </div>
      </div>

      {/* ── Track Info ─────────────────────────── */}
      <div className="np-track-info">
        <h3 className="np-track-title" dangerouslySetInnerHTML={{ __html: currentSong.title }} />
        <p className="np-track-artist">{currentSong.artist}</p>
        <div className="np-track-meta">
          {isSoundCloud
            ? <span className="np-track-badge np-track-badge--sc">SoundCloud</span>
            : <span className="np-track-badge np-track-badge--yt">YouTube</span>
          }
          {currentSong.publishedAt && (
            <span className="np-track-year">{new Date(currentSong.publishedAt).getFullYear()}</span>
          )}
          <button
            type="button"
            aria-label="Favourite"
            onClick={handleFavoriteToggle}
            className={`np-fav-pill${isFavorited ? ' np-fav-pill--active' : ''}`}
          >
            <Heart size={13} fill={isFavorited ? 'currentColor' : 'none'} />
            {isFavorited ? 'Đã thích' : 'Yêu thích'}
          </button>
        </div>
      </div>

      {/* ── Visualizer ─────────────────────────── */}
      <div className="np-visualizer-wrapper">
        <AudioVisualizer isPlaying={isPlaying} />
      </div>

      {/* ── Similar Songs ──────────────────────── */}
      <SimilarSongs currentSong={currentSong} />

    </aside>
  );
}
