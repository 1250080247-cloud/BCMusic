"use client";

import {
  ChevronDown, Heart, ListMusic, Loader2, MoreVertical,
  Music2, Pause, Play, Plus, Radio, Repeat, Repeat1,
  Shuffle, SkipBack, SkipForward,
} from 'lucide-react';
import Image from 'next/image';
import { useSession } from 'next-auth/react';
import { useCallback, useEffect, useRef, useState } from 'react';
import { getDictionary, formatDate } from '@/lib/i18n';
import { useMusicStore, useSettingsStore } from '@/lib/store';

/* ════════════════════════════════════════════════════════
   SimilarSongs
   ════════════════════════════════════════════════════════ */
function SimilarSongs({ currentSong }) {
  const [songs, setSongs] = useState([]);
  const [loading, setLoading] = useState(false);
  const { setCurrentSong, setViewingSong, setPlaylist } = useMusicStore();
  const prevIdRef = useRef(null);

  useEffect(() => {
    if (!currentSong?.id) return;
    if (prevIdRef.current === currentSong.id) return;
    prevIdRef.current = currentSong.id;

    setLoading(true);
    setSongs([]);

    const rawTitle = currentSong.title?.replace(/<[^>]*>/g, '') || '';
    const titleWords = rawTitle.split(/[\s\-–|]+/).slice(0, 4).join(' ');
    const artist = currentSong.artist || '';
    const query = artist ? `${artist} ${titleWords}` : titleWords;

    fetch(`/api/explore?q=${encodeURIComponent(query)}&order=relevance`)
      .then(r => r.json())
      .then(data => {
        const filtered = (data.items || []).filter(s => s.id !== currentSong.id);
        setSongs(filtered.slice(0, 6));
      })
      .catch(() => setSongs([]))
      .finally(() => setLoading(false));
  }, [currentSong?.id]);

  if (!loading && songs.length === 0) return null;

  return (
    <div className="np-similar-section">
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
              <div className="np-similar-thumb">
                {song.thumbnail && (
                  <Image src={song.thumbnail} alt="" fill sizes="44px" className="object-cover" />
                )}
                <div className="np-similar-thumb-overlay">
                  <Music2 size={14} />
                </div>
              </div>
              <div className="np-similar-info">
                <p className="np-similar-title" dangerouslySetInnerHTML={{ __html: song.title }} />
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
   LyricsSection
   ════════════════════════════════════════════════════════ */
function LyricsSection({ lyrics, language }) {
  if (!lyrics) return null;
  return (
    <div className="np-lyrics-section">
      <div className="np-info-section-header">
        <span className="np-info-section-label">
          {language === 'vi' ? 'Lời bài hát' : 'Lyrics'}
        </span>
      </div>
      <div className="np-lyrics-text">{lyrics}</div>
    </div>
  );
}

/* ════════════════════════════════════════════════════════
   SongStats — publish date + source badge
   ════════════════════════════════════════════════════════ */
function SongStats({ song, language }) {
  if (!song) return null;
  const isSoundCloud = song.source === 'soundcloud';

  return (
    <div className="np-stats-section">
      <div className="np-info-section-header">
        <span className="np-info-section-label">
          {language === 'vi' ? 'Thông tin' : 'Info'}
        </span>
      </div>
      <div className="np-stats-grid">
        {song.publishedAt && (
          <div className="np-stats-item">
            <span className="np-stats-item-label">
              {language === 'vi' ? 'Phát hành' : 'Released'}
            </span>
            <span className="np-stats-item-value">
              {formatDate(song.publishedAt, language)}
            </span>
          </div>
        )}
        <div className="np-stats-item">
          <span className="np-stats-item-label">
            {language === 'vi' ? 'Nguồn' : 'Source'}
          </span>
          <span className={`np-track-badge ${isSoundCloud ? 'np-track-badge--sc' : 'np-track-badge--yt'}`}>
            {isSoundCloud ? 'SoundCloud' : 'YouTube'}
          </span>
        </div>
        {song.id && !isSoundCloud && (
          <div className="np-stats-item">
            <span className="np-stats-item-label">Video ID</span>
            <a
              href={`https://youtube.com/watch?v=${song.id}`}
              target="_blank"
              rel="noopener noreferrer"
              className="np-stats-link"
            >
              {song.id}
            </a>
          </div>
        )}
      </div>
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
    playlist,
    setCurrentSong,
    repeatMode,
    cycleRepeatMode,
  } = useMusicStore();
  const language = useSettingsStore((s) => s.language);
  const t = getDictionary(language);

  /* ── Playback state (synced from Player via events) ─── */
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const isSeeking = useRef(false);

  useEffect(() => {
    const onPlayState = (e) => setIsPlaying(e.detail?.isPlaying ?? false);
    const onTimeUpdate = (e) => {
      if (isSeeking.current) return;
      setCurrentTime(e.detail?.currentTime ?? 0);
      setDuration(e.detail?.duration ?? 0);
    };
    window.addEventListener('bcmusic:playstate', onPlayState);
    window.addEventListener('bcmusic:timeupdate', onTimeUpdate);
    return () => {
      window.removeEventListener('bcmusic:playstate', onPlayState);
      window.removeEventListener('bcmusic:timeupdate', onTimeUpdate);
    };
  }, []);

  // Reset time when song changes
  useEffect(() => {
    setCurrentTime(0);
    setDuration(0);
  }, [currentSong?.id]);

  /* ── Controls ───────────────────────────────────────── */
  const togglePlay = () =>
    window.dispatchEvent(new CustomEvent('bcmusic:toggleplay'));

  const handleSeek = (e) => {
    const val = Number(e.target.value);
    setCurrentTime(val);
    window.dispatchEvent(new CustomEvent('bcmusic:seekto', { detail: { time: val } }));
  };

  const playNext = useCallback(() => {
    if (!playlist.length || !currentSong) return;
    const idx = playlist.findIndex((s) => s.id === currentSong.id);
    const next = repeatMode === 'off'
      ? (idx + 1 < playlist.length ? playlist[idx + 1] : null)
      : playlist[(idx + 1) % playlist.length];
    if (next) setCurrentSong(next);
  }, [playlist, currentSong, setCurrentSong, repeatMode]);

  const playPrev = useCallback(() => {
    if (!playlist.length || !currentSong) return;
    const idx = playlist.findIndex((s) => s.id === currentSong.id);
    const prev = playlist[(idx - 1 + playlist.length) % playlist.length];
    if (prev) setCurrentSong(prev);
  }, [playlist, currentSong, setCurrentSong]);

  /* ── Favorite ───────────────────────────────────────── */
  const isFavorited = favorites?.some((s) => s.id === currentSong?.id);

  const handleFavoriteToggle = async () => {
    if (!currentSong) return;
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

  /* ── Time format ────────────────────────────────────── */
  const fmt = (sec) => {
    if (!sec || isNaN(sec)) return '0:00';
    const m = Math.floor(sec / 60);
    const s = Math.floor(sec % 60);
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  };

  const progressPct = duration > 0 ? (currentTime / duration) * 100 : 0;

  /* ── Guard ──────────────────────────────────────────── */
  if (!currentSong || !nowPlayingOpen) return null;

  const isSoundCloud = currentSong.source === 'soundcloud';

  /* ════════════════════════════════════════════════════
     Render
     ════════════════════════════════════════════════════ */
  return (
    <aside className="now-playing-panel">

      {/* ── Header ────────────────────────────────────── */}
      <div className="np-header">
        <button
          type="button"
          aria-label={t.nowPlaying.close}
          onClick={() => setNowPlayingOpen(false)}
          className="np-header-chevron"
        >
          <ChevronDown size={24} />
        </button>

        <div className="np-header-center">
          <span className="np-header-label">{t.nowPlaying.title}</span>
          <div className="np-header-title-marquee">
            <div className="np-header-title-track">
              <span className="np-header-title-copy" dangerouslySetInnerHTML={{ __html: currentSong.title }} />
              <span className="np-header-title-copy" aria-hidden="true" dangerouslySetInnerHTML={{ __html: currentSong.title }} />
            </div>
          </div>
        </div>

        <button type="button" aria-label="More options" className="np-header-more">
          <MoreVertical size={20} />
        </button>
      </div>

      {/* ── Artwork ───────────────────────────────────── */}
      <div className="np-artwork-wrapper">
        <div className={`np-artwork-glow${isPlaying ? ' np-artwork-glow--active' : ''}`} />
        <div className={`np-artwork-card${isPlaying ? ' np-artwork-card--playing' : ''}`}>
          {currentSong.thumbnail
            ? <Image
                src={currentSong.thumbnail}
                alt={currentSong.title?.replace(/<[^>]*>/g, '') || 'Cover'}
                fill
                sizes="(max-width:767px) 90vw, 340px"
                className="object-cover"
                priority
              />
            : <div className="np-artwork-fallback"><Music2 size={48} /></div>
          }
        </div>
      </div>

      {/* ── Song info + actions ───────────────────────── */}
      <div className="np-song-row">
        <div className="np-song-text">
          <div className="np-song-title-marquee">
            <div className="np-song-title-track">
              <span className="np-song-title-copy" dangerouslySetInnerHTML={{ __html: currentSong.title }} />
              <span className="np-song-title-copy" aria-hidden="true" dangerouslySetInnerHTML={{ __html: currentSong.title }} />
            </div>
          </div>
          <p className="np-song-artist">
            {currentSong.artist}
            {isSoundCloud && (
              <span className="np-sc-badge">SC</span>
            )}
          </p>
        </div>
        <div className="np-song-actions">
          <button
            type="button"
            aria-label="Add to playlist"
            className="np-action-btn"
          >
            <Plus size={20} />
          </button>
          <button
            type="button"
            aria-label="Favourite"
            onClick={handleFavoriteToggle}
            className={`np-action-btn ${isFavorited ? 'np-action-btn--active' : ''}`}
          >
            <Heart size={20} fill={isFavorited ? 'currentColor' : 'none'} />
          </button>
        </div>
      </div>

      {/* ── Progress ──────────────────────────────────── */}
      <div className="np-progress-section">
        <div className="np-progress-bar-wrapper">
          <input
            type="range"
            min={0}
            max={duration || 100}
            step={0.5}
            value={currentTime}
            onMouseDown={() => { isSeeking.current = true; }}
            onTouchStart={() => { isSeeking.current = true; }}
            onMouseUp={(e) => { isSeeking.current = false; handleSeek(e); }}
            onTouchEnd={(e) => {
              isSeeking.current = false;
              // Synthetic event workaround for touch
              const val = Number(e.currentTarget.value);
              setCurrentTime(val);
              window.dispatchEvent(new CustomEvent('bcmusic:seekto', { detail: { time: val } }));
            }}
            onChange={(e) => {
              if (isSeeking.current) setCurrentTime(Number(e.target.value));
            }}
            className="np-range"
            style={{ '--np-pct': `${progressPct}%` }}
          />
        </div>
        <div className="np-progress-times">
          <span>{fmt(currentTime)}</span>
          <span>{fmt(duration)}</span>
        </div>
      </div>

      {/* ── Controls ──────────────────────────────────── */}
      <div className="np-controls">
        {/* Shuffle (decorative) */}
        <button type="button" aria-label="Shuffle" className="np-ctrl-btn np-ctrl-btn--secondary">
          <Shuffle size={18} />
        </button>

        {/* Prev */}
        <button type="button" aria-label={t.player.previous} onClick={playPrev} className="np-ctrl-btn np-ctrl-btn--secondary">
          <SkipBack size={22} />
        </button>

        {/* Play / Pause (large) */}
        <button
          type="button"
          aria-label={isPlaying ? t.player.pause : t.player.play}
          onClick={togglePlay}
          className="np-play-btn"
        >
          {isPlaying ? <Pause size={26} /> : <Play size={26} className="ml-0.5" />}
        </button>

        {/* Next */}
        <button type="button" aria-label={t.player.next} onClick={playNext} className="np-ctrl-btn np-ctrl-btn--secondary">
          <SkipForward size={22} />
        </button>

        {/* Repeat */}
        <button
          type="button"
          aria-label={
            repeatMode === 'off' ? t.player.repeatOff
            : repeatMode === 'all' ? t.player.repeatAll
            : t.player.repeatOne
          }
          onClick={cycleRepeatMode}
          className={`np-ctrl-btn np-ctrl-btn--secondary relative ${repeatMode !== 'off' ? 'np-ctrl-btn--accent' : ''}`}
        >
          {repeatMode === 'one' ? <Repeat1 size={18} /> : <Repeat size={18} />}
          {repeatMode !== 'off' && (
            <span className="np-repeat-dot" />
          )}
        </button>
      </div>

      {/* ── Bottom row ────────────────────────────────── */}
      <div className="np-bottom-row">
        <button type="button" aria-label="Song info" className="np-bottom-btn">
          <Music2 size={18} />
        </button>
        <div className="np-bottom-spacer" />
        <button type="button" aria-label="Add to queue" className="np-bottom-btn">
          <Plus size={18} />
        </button>
        <button type="button" aria-label="Queue" className="np-bottom-btn">
          <ListMusic size={18} />
        </button>
      </div>

      {/* ── Divider ───────────────────────────────────── */}
      <div className="np-divider" />

      {/* ── Scrollable info ───────────────────────────── */}
      <div className="np-scroll-section">
        <LyricsSection lyrics={currentSong.lyrics} language={language} />
        <SongStats song={currentSong} language={language} />
        <SimilarSongs currentSong={currentSong} />
      </div>

    </aside>
  );
}
