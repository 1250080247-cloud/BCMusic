"use client";

import { ChevronDown, Heart, ListMusic, Music2, Pause, Play, Repeat, Repeat1, SkipBack, SkipForward, Volume2 } from 'lucide-react';
import Image from 'next/image';
import { useSession } from 'next-auth/react';
import { useEffect, useRef, useState } from 'react';
import { getDictionary } from '@/lib/i18n';
import { decodeSongTitle } from '@/lib/song-title';
import { useMusicStore, useSettingsStore } from '@/lib/store';
import LyricsPanel from '@/components/LyricsPanel';
import NowPlayingDetails from '@/components/NowPlayingDetails';

function formatTime(value) {
  const seconds = Math.max(0, Math.floor(Number(value) || 0));
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}

export default function NowPlayingPanel() {
  const { data: session } = useSession();
  const {
    currentSong, playlist, startPlayback, nowPlayingOpen, setNowPlayingOpen,
    favorites, addFavorite, removeFavorite, repeatMode, cycleRepeatMode,
  } = useMusicStore();
  const language = useSettingsStore(state => state.language);
  const volume = useSettingsStore(state => state.volume);
  const setVolume = useSettingsStore(state => state.setVolume);
  const t = getDictionary(language);
  const vi = language === 'vi';
  const [view, setView] = useState('lyrics');
  const [playState, setPlayState] = useState(null);
  const [timing, setTiming] = useState(null);
  const [playbackError, setPlaybackError] = useState(null);
  const dialog = useRef(null);
  const isSeeking = useRef(false);
  const hasSong = Boolean(currentSong);
  const isPlaying = playState?.songId === currentSong?.id && Boolean(playState?.isPlaying);
  const currentTime = timing && timing.songId === currentSong?.id ? timing.currentTime : 0;
  const duration = timing && timing.songId === currentSong?.id ? timing.duration : 0;

  useEffect(() => {
    const onPlayState = event => setPlayState(event.detail);
    const onTimeUpdate = event => { if (!isSeeking.current) setTiming(event.detail); };
    const onError = event => setPlaybackError(event.detail);
    window.addEventListener('bcmusic:playstate', onPlayState);
    window.addEventListener('bcmusic:timeupdate', onTimeUpdate);
    window.addEventListener('bcmusic:playerror', onError);
    return () => {
      window.removeEventListener('bcmusic:playstate', onPlayState);
      window.removeEventListener('bcmusic:timeupdate', onTimeUpdate);
      window.removeEventListener('bcmusic:playerror', onError);
    };
  }, []);

  useEffect(() => {
    if (!nowPlayingOpen || !hasSong || !dialog.current) return;
    const element = dialog.current;
    const previousFocus = document.activeElement;
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = 'hidden';
    if (!element.open) element.showModal();
    return () => {
      if (element.open) element.close();
      document.body.style.overflow = previousOverflow;
      if (previousFocus?.isConnected) previousFocus.focus({ preventScroll: true });
      isSeeking.current = false;
    };
  }, [nowPlayingOpen, hasSong]);

  const seek = event => {
    const time = Math.max(0, Math.min(duration || 0, Number(event.target.value) || 0));
    setTiming({ songId: currentSong?.id, currentTime: time, duration });
    window.dispatchEvent(new CustomEvent('bcmusic:seekto', { detail: { time } }));
  };
  const command = type => window.dispatchEvent(new CustomEvent(`bcmusic:${type}`));
  const isFavorited = favorites?.some(song => song.id === currentSong?.id);
  const favorite = async () => {
    if (!session?.user?.id) {
      alert(vi ? 'Vui lòng đăng nhập để lưu bài hát yêu thích!' : 'Please sign in to favorite songs!');
      return;
    }
    try {
      const result = await fetch(isFavorited ? `/api/favorites?songId=${encodeURIComponent(currentSong.id)}` : '/api/favorites', {
        method: isFavorited ? 'DELETE' : 'POST',
        ...(isFavorited ? {} : { headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ song: currentSong }) }),
      });
      if (result.ok) {
        if (isFavorited) removeFavorite(currentSong.id);
        else addFavorite(currentSong);
      }
    } catch (error) { console.error('Unable to update favorite', error); }
  };

  if (!currentSong || !nowPlayingOpen) return null;
  const title = decodeSongTitle(currentSong.title);
  const tabs = [
    ['lyrics', vi ? 'Lời bài hát' : 'Lyrics'],
    ['queue', vi ? 'Tiếp theo' : 'Up next'],
    ['info', vi ? 'Thông tin' : 'Details'],
  ];
  const close = () => setNowPlayingOpen(false);

  return (
    <dialog ref={dialog} className="focus-player" aria-label={vi ? 'Trình phát nhạc' : 'Music player'}
      onCancel={event => { event.preventDefault(); close(); }}>
      <div className="focus-player-background" aria-hidden="true">
        {currentSong.thumbnail && <Image key={currentSong.thumbnail} src={currentSong.thumbnail} alt="" fill sizes="640px" className="focus-background-image" />}
      </div>
      <div className="focus-player-shade" aria-hidden="true" />
      <header className="focus-player-header">
        <button type="button" className="focus-icon-button" aria-label={t.nowPlaying.close} onClick={close} autoFocus><ChevronDown size={23} /></button>
        <div className="focus-player-brand"><span>BCMusic</span><span>{t.nowPlaying.title}</span></div>
        <span className="focus-player-source">{currentSong.source === 'soundcloud' ? 'SoundCloud' : 'YouTube'}</span>
      </header>

      <div className="focus-player-stage">
        <section className="focus-player-record" aria-label={vi ? 'Điều khiển phát nhạc' : 'Playback controls'}>
          <div className="focus-player-artwork">
            {currentSong.thumbnail
              ? <Image key={currentSong.thumbnail} src={currentSong.thumbnail} alt={title} fill sizes="(max-width: 767px) 70vw, 350px" className="focus-cover-image" priority />
              : <Music2 size={72} strokeWidth={1} />}
            <button type="button" className={`focus-artwork-favorite${isFavorited ? ' focus-artwork-favorite--active' : ''}`}
              aria-label={vi ? 'Yêu thích' : 'Favourite'} aria-pressed={isFavorited} onClick={favorite}>
              <Heart size={17} fill={isFavorited ? 'currentColor' : 'none'} />
            </button>
          </div>
          <div className="focus-player-track"><h1>{title}</h1><p>{currentSong.artist}</p>
            {playbackError?.songId === currentSong.id && playbackError.code && <p className="focus-player-error" role="status">{vi ? 'YouTube không phát được video này. Hãy thử bài khác.' : 'YouTube cannot play this recording. Try another track.'}</p>}
          </div>
          <div className="focus-player-progress">
            <input type="range" min={0} max={duration || 1} step={0.1} disabled={!duration}
              value={Math.min(currentTime || 0, duration || 0)} aria-label={vi ? 'Vị trí phát' : 'Playback position'}
              aria-valuetext={`${formatTime(currentTime)} / ${formatTime(duration)}`}
              onPointerDown={() => { isSeeking.current = true; }} onPointerUp={() => { isSeeking.current = false; }}
              onPointerCancel={() => { isSeeking.current = false; }} onChange={seek}
              style={{ '--focus-progress': `${duration > 0 ? currentTime / duration * 100 : 0}%` }} />
            <div><span>{formatTime(currentTime)}</span><span>{formatTime(duration)}</span></div>
          </div>
          <div className="focus-player-controls">
            <button type="button" className="focus-icon-button" aria-label={t.player.previous} onClick={() => command('previous')}><SkipBack size={24} fill="currentColor" /></button>
            <button type="button" className="focus-play-button" aria-label={isPlaying ? t.player.pause : t.player.play} onClick={() => command('toggleplay')}>
              {isPlaying ? <Pause size={27} fill="currentColor" /> : <Play size={27} fill="currentColor" />}
            </button>
            <button type="button" className="focus-icon-button" aria-label={t.player.next} onClick={() => command('next')}><SkipForward size={24} fill="currentColor" /></button>
            <button type="button" className={`focus-icon-button focus-repeat${repeatMode !== 'off' ? ' focus-repeat--active' : ''}`}
              aria-label={repeatMode === 'off' ? t.player.repeatOff : repeatMode === 'all' ? t.player.repeatAll : t.player.repeatOne}
              aria-pressed={repeatMode !== 'off'} onClick={cycleRepeatMode}>
              {repeatMode === 'one' ? <Repeat1 size={19} /> : <Repeat size={19} />}
            </button>
          </div>
          <label className="focus-player-volume"><Volume2 size={16} /><span className="sr-only">{t.settings.volume}</span>
            <input type="range" min={0} max={100} value={volume ?? 80} onChange={event => setVolume(Number(event.target.value))} />
          </label>
        </section>

        <section className="focus-player-reading">
          <nav className="focus-player-tabs" aria-label={vi ? 'Nội dung trình phát' : 'Player view'}>
            {tabs.map(([id, label]) => <button type="button" key={id} aria-pressed={view === id} onClick={() => setView(id)}>{label}</button>)}
          </nav>
          {view === 'lyrics' ? <LyricsPanel key={currentSong.id} song={currentSong} duration={duration || 0} currentTime={currentTime || 0} language={language} />
            : view === 'info' ? <div className="focus-secondary-scroll"><NowPlayingDetails song={currentSong} language={language} /></div>
            : <div className="focus-secondary-scroll focus-queue"><h2><ListMusic size={21} />{vi ? 'Danh sách đang phát' : 'Play queue'}</h2>
              {(playlist?.length ? playlist : [currentSong]).map((song, index, queue) => (
                <button type="button" key={`${song.id}-${index}`} className="focus-queue-item" aria-current={song.id === currentSong.id ? 'true' : undefined} onClick={() => startPlayback(song, queue)}>
                  <span>{String(index + 1).padStart(2, '0')}</span><div><strong>{decodeSongTitle(song.title)}</strong><small>{song.artist}</small></div>
                  {song.id === currentSong.id && <Music2 size={18} />}
                </button>
              ))}
            </div>}
        </section>
      </div>
    </dialog>
  );
}
