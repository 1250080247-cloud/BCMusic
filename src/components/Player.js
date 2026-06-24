"use client";

import { FileText, Pause, Play, Repeat, Repeat1, SkipBack, SkipForward, X } from 'lucide-react';
import Image from 'next/image';
import { useEffect, useRef, useState, useCallback } from 'react';
import YouTube from 'react-youtube';
import { getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore } from '@/lib/store';

export default function Player() {
  const [isPlaying, setIsPlaying] = useState(false);
  const [isLyricsOpen, setIsLyricsOpen] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const ytPlayerRef = useRef(null);
  const scWidgetRef = useRef(null);
  const scIframeRef = useRef(null);
  const lastSongIdRef = useRef(null);
  const scApiLoadedRef = useRef(false);
  const handleTrackEndRef = useRef(null);
  const { currentSong, playlist, setCurrentSong, setViewingSong, repeatMode, cycleRepeatMode } = useMusicStore();
  const language = useSettingsStore((state) => state.language);
  const volume = useSettingsStore((state) => state.volume);
  const playbackRate = useSettingsStore((state) => state.playbackRate);
  const t = getDictionary(language);

  const isSoundCloud = currentSong?.source === 'soundcloud';

  // Save to history whenever currentSong changes
  useEffect(() => {
    if (!currentSong) return;

    fetch('/api/history', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        id: currentSong.id,
        title: currentSong.title,
        thumbnail: currentSong.thumbnail,
        artist: currentSong.artist,
        publishedAt: currentSong.publishedAt,
        lyrics: currentSong.lyrics,
        source: currentSong.source || 'youtube',
      }),
    }).catch((error) => console.log('Unable to save listening history', error));
  }, [currentSong]);

  // ─── YouTube: Volume sync ──────────────────────────────
  useEffect(() => {
    if (isSoundCloud) return;
    if (ytPlayerRef.current?.setVolume) {
      ytPlayerRef.current.setVolume(volume);
    }
  }, [volume, isSoundCloud]);

  // ─── YouTube: Playback rate sync ───────────────────────
  useEffect(() => {
    if (isSoundCloud) return;
    if (ytPlayerRef.current?.setPlaybackRate) {
      try {
        ytPlayerRef.current.setPlaybackRate(playbackRate);
      } catch {
        setTimeout(() => ytPlayerRef.current?.setPlaybackRate?.(playbackRate), 500);
      }
    }
  }, [playbackRate, currentSong, isSoundCloud]);

  // ─── YouTube: Time tracking ────────────────────────────
  useEffect(() => {
    if (isSoundCloud) return;
    let interval;

    if (isPlaying) {
      interval = setInterval(async () => {
        if (ytPlayerRef.current && typeof ytPlayerRef.current.getCurrentTime === 'function') {
          try {
            const time = await ytPlayerRef.current.getCurrentTime();
            const videoDuration = await ytPlayerRef.current.getDuration();
            if (time !== undefined) setCurrentTime(time);
            if (videoDuration !== undefined) setDuration(videoDuration);
          } catch {
          }
        }
      }, 1000);
    }

    return () => clearInterval(interval);
  }, [isPlaying, isSoundCloud]);

  // ─── SoundCloud: Load Widget API script ────────────────
  useEffect(() => {
    if (scApiLoadedRef.current) return;
    if (typeof window === 'undefined') return;

    // Check if already loaded
    if (window.SC?.Widget) {
      scApiLoadedRef.current = true;
      return;
    }

    const script = document.createElement('script');
    script.src = 'https://w.soundcloud.com/player/api.js';
    script.async = true;
    script.onload = () => {
      scApiLoadedRef.current = true;
    };
    document.head.appendChild(script);
  }, []);

  // ─── SoundCloud: Initialize widget when song changes ───
  useEffect(() => {
    if (!isSoundCloud || !currentSong?.embedUrl) return;
    if (!scIframeRef.current) return;

    const initWidget = () => {
      if (!window.SC?.Widget || !scIframeRef.current) return;

      const widget = window.SC.Widget(scIframeRef.current);
      scWidgetRef.current = widget;

      widget.bind(window.SC.Widget.Events.READY, () => {
        // Set volume (SC widget volume: 0–100)
        widget.setVolume(volume);

        // Auto-play
        widget.play();

        // Get duration
        widget.getDuration((dur) => {
          if (dur) setDuration(dur / 1000); // ms → seconds
        });

        // Reset time tracking
        if (lastSongIdRef.current !== currentSong.id) {
          lastSongIdRef.current = currentSong.id;
          setCurrentTime(0);
          setDuration(0);
        }
      });

      widget.bind(window.SC.Widget.Events.PLAY, () => {
        setIsPlaying(true);
      });

      widget.bind(window.SC.Widget.Events.PAUSE, () => {
        setIsPlaying(false);
      });

      widget.bind(window.SC.Widget.Events.FINISH, () => {
        handleTrackEndRef.current?.();
      });

      widget.bind(window.SC.Widget.Events.PLAY_PROGRESS, (data) => {
        if (data?.currentPosition !== undefined) {
          setCurrentTime(data.currentPosition / 1000); // ms → seconds
        }
      });
    };

    // Wait for SC API to be available
    if (window.SC?.Widget) {
      initWidget();
    } else {
      const checkInterval = setInterval(() => {
        if (window.SC?.Widget) {
          clearInterval(checkInterval);
          initWidget();
        }
      }, 200);

      return () => clearInterval(checkInterval);
    }
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [currentSong?.id, currentSong?.embedUrl, isSoundCloud]);

  // ─── SoundCloud: Volume sync ───────────────────────────
  useEffect(() => {
    if (!isSoundCloud || !scWidgetRef.current) return;
    try {
      scWidgetRef.current.setVolume(volume);
    } catch {
      // widget not ready yet
    }
  }, [volume, isSoundCloud]);

  // ─── Navigation ────────────────────────────────────────
  const playNext = useCallback(() => {
    if (!playlist.length || !currentSong) return;
    const currentIndex = playlist.findIndex((song) => song.id === currentSong.id);
    if (repeatMode === 'off') {
      // Stop at end of playlist
      const nextIndex = currentIndex + 1;
      if (nextIndex >= playlist.length) {
        setIsPlaying(false);
        return;
      }
      setCurrentSong(playlist[nextIndex]);
    } else {
      // repeat 'all': wrap around
      const nextIndex = currentIndex === -1 ? 0 : (currentIndex + 1) % playlist.length;
      setCurrentSong(playlist[nextIndex]);
    }
  }, [playlist, currentSong, setCurrentSong, repeatMode]);

  const playPrev = () => {
    if (!playlist.length || !currentSong) return;
    const currentIndex = playlist.findIndex((song) => song.id === currentSong.id);
    const prevIndex = currentIndex === -1 ? 0 : (currentIndex - 1 + playlist.length) % playlist.length;
    setCurrentSong(playlist[prevIndex]);
  };

  // Handle end-of-track (called by both YouTube and SoundCloud)
  const handleTrackEnd = useCallback(() => {
    if (repeatMode === 'one') {
      // Replay the same track
      if (isSoundCloud && scWidgetRef.current) {
        scWidgetRef.current.seekTo(0);
        scWidgetRef.current.play();
      } else if (ytPlayerRef.current) {
        ytPlayerRef.current.seekTo(0, true);
        ytPlayerRef.current.playVideo();
      }
      setCurrentTime(0);
    } else {
      setIsPlaying(false);
      playNext();
    }
  }, [repeatMode, isSoundCloud, playNext]);

  // Keep ref in sync so event-listener closures always call the latest version
  useEffect(() => {
    handleTrackEndRef.current = handleTrackEnd;
  }, [handleTrackEnd]);

  // ─── YouTube: Player ready ─────────────────────────────
  const onPlayerReady = (event) => {
    ytPlayerRef.current = event.target;
    event.target.setVolume(volume);
    event.target.setPlaybackRate?.(playbackRate);
    if (currentSong) event.target.playVideo();
  };

  // ─── Toggle play/pause (dual source) ──────────────────
  const togglePlay = () => {
    if (isSoundCloud) {
      if (!scWidgetRef.current) return;
      try {
        scWidgetRef.current.isPaused((paused) => {
          if (paused) {
            scWidgetRef.current.play();
          } else {
            scWidgetRef.current.pause();
          }
        });
      } catch {
        // If isPaused fails, try toggle
        if (isPlaying) {
          scWidgetRef.current.pause();
        } else {
          scWidgetRef.current.play();
        }
        setIsPlaying(!isPlaying);
      }
    } else {
      if (!ytPlayerRef.current || typeof ytPlayerRef.current.playVideo !== 'function') return;

      if (isPlaying) {
        ytPlayerRef.current.pauseVideo();
      } else {
        ytPlayerRef.current.playVideo();
      }

      setIsPlaying(!isPlaying);
    }
  };

  const formatTime = (time) => {
    if (!time) return "0:00";
    const minutes = Math.floor(time / 60);
    const seconds = Math.floor(time % 60);
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  };

  if (!currentSong) return null;

  return (
    <div className="player-shell fixed bottom-16 left-0 right-0 z-50 p-4">
      {isLyricsOpen && (
        <section className="lyrics-panel fixed bottom-40 right-4 z-[60] max-h-[50vh] w-[min(24rem,calc(100vw-2rem))] overflow-hidden rounded-3xl p-5">
          <div className="mb-4 flex items-start justify-between gap-4">
            <div>
              <p className="text-sm font-semibold uppercase tracking-[0.25em] text-pink-400">
                {t.lyrics.title}
              </p>
              <h2
                className="mt-1 line-clamp-2 text-lg font-bold"
                dangerouslySetInnerHTML={{ __html: currentSong.title }}
              />
            </div>
            <button
              type="button"
              aria-label={t.lyrics.close}
              onClick={() => setIsLyricsOpen(false)}
              className="rounded-full p-2 text-[var(--muted-text)] transition hover:bg-[var(--surface-hover)] hover:text-[var(--app-text)]"
            >
              <X size={18} />
            </button>
          </div>

          {currentSong.lyrics ? (
            <div className="max-h-[42vh] overflow-y-auto whitespace-pre-line text-sm leading-7 text-[var(--app-text)]">
              {currentSong.lyrics}
            </div>
          ) : (
            <div className="rounded-2xl border border-dashed border-pink-400/35 bg-pink-500/10 p-4">
              <p className="font-bold text-pink-400">{t.lyrics.unavailableTitle}</p>
              <p className="muted-text mt-2 text-sm leading-6">{t.lyrics.unavailableDescription}</p>
              <p className="mt-3 text-xs font-semibold text-cyan-400">{t.lyrics.hint}</p>
            </div>
          )}
        </section>
      )}

      {/* ─── Hidden Players ──────────────────────────────── */}

      {/* YouTube Player (only rendered for YouTube tracks) */}
      {!isSoundCloud && (
        <div className="hidden">
          <YouTube
            videoId={currentSong.id}
            opts={{ playerVars: { autoplay: 1, controls: 0, rel: 0 } }}
            onReady={onPlayerReady}
            onStateChange={(event) => {
              if (event.data === 1) {
                if (lastSongIdRef.current !== currentSong.id) {
                  lastSongIdRef.current = currentSong.id;
                  setCurrentTime(0);
                  setDuration(0);
                }
                setIsPlaying(true);
              }
              if (event.data === 2) setIsPlaying(false);
              if (event.data === 0) handleTrackEndRef.current?.();
            }}
          />
        </div>
      )}

      {/* SoundCloud Widget (only rendered for SoundCloud tracks) */}
      {isSoundCloud && currentSong.embedUrl && (
        <div className="hidden">
          <iframe
            ref={scIframeRef}
            key={currentSong.id}
            id="sc-widget"
            title="SoundCloud Player"
            width="100%"
            height="166"
            allow="autoplay"
            src={currentSong.embedUrl}
          />
        </div>
      )}

      {/* ─── Visible Player UI (shared for both sources) ─ */}
      <div className="mx-auto flex max-w-screen-xl items-center justify-between gap-4">
        <button
          type="button"
          aria-label={t.player.showDetails}
          onClick={() => setViewingSong(currentSong)}
          className="flex min-w-0 w-1/4 items-center gap-4 text-left md:w-1/3"
        >
          <div className="hidden h-14 w-14 flex-shrink-0 overflow-hidden rounded-xl bg-[var(--surface-strong)] sm:block">
            {currentSong.thumbnail && (
              <Image
                src={currentSong.thumbnail}
                alt={t.player.coverAlt}
                width={56}
                height={56}
                className="h-full w-full object-cover"
              />
            )}
          </div>
          <div className="min-w-0 flex-1">
            <div className="player-title-marquee font-semibold text-[var(--app-text)]">
              <div className="player-title-track">
                <span className="player-title-copy" dangerouslySetInnerHTML={{ __html: currentSong.title }} />
                <span className="player-title-copy" aria-hidden="true" dangerouslySetInnerHTML={{ __html: currentSong.title }} />
              </div>
            </div>
            <p className="muted-text truncate text-sm">
              {currentSong.artist}
              {isSoundCloud && (
                <span className="ml-2 inline-flex items-center rounded bg-orange-500/15 px-1.5 py-0.5 text-[10px] font-bold text-orange-400">
                  SC
                </span>
              )}
            </p>
          </div>
        </button>

        <div className="flex w-2/4 flex-col items-center justify-center md:w-1/3">
          <div className="mb-2 flex items-center justify-center gap-4">
            <button
              type="button"
              aria-label={
                repeatMode === 'off' ? t.player.repeatOff
                : repeatMode === 'all' ? t.player.repeatAll
                : t.player.repeatOne
              }
              title={
                repeatMode === 'off' ? t.player.repeatOff
                : repeatMode === 'all' ? t.player.repeatAll
                : t.player.repeatOne
              }
              onClick={cycleRepeatMode}
              className={`relative transition ${
                repeatMode === 'off'
                  ? 'text-[var(--muted-text)] hover:text-[var(--app-text)]'
                  : 'text-pink-400 hover:text-pink-300'
              }`}
            >
              {repeatMode === 'one' ? <Repeat1 size={18} /> : <Repeat size={18} />}
              {repeatMode !== 'off' && (
                <span className="absolute -right-1 -top-1 flex h-2 w-2">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-pink-400 opacity-75" />
                  <span className="relative inline-flex h-2 w-2 rounded-full bg-pink-500" />
                </span>
              )}
            </button>
            <button
              type="button"
              aria-label={t.player.previous}
              onClick={playPrev}
              className="muted-text transition hover:text-[var(--app-text)]"
            >
              <SkipBack size={20} />
            </button>
            <button
              type="button"
              aria-label={isPlaying ? t.player.pause : t.player.play}
              onClick={togglePlay}
              className="flex h-10 w-10 items-center justify-center rounded-full bg-white text-black transition hover:scale-105"
            >
              {isPlaying ? <Pause size={20} /> : <Play size={20} className="ml-1" />}
            </button>
            <button
              type="button"
              aria-label={t.player.next}
              onClick={playNext}
              className="muted-text transition hover:text-[var(--app-text)]"
            >
              <SkipForward size={20} />
            </button>
          </div>

          <div className="flex w-full items-center gap-3">
            <span className="muted-text w-8 text-right font-mono text-[11px]">{formatTime(currentTime)}</span>
            <input
              type="range"
              min={0}
              max={duration || 100}
              value={currentTime}
              onChange={(event) => {
                const value = Number(event.target.value);
                setCurrentTime(value);

                if (isSoundCloud && scWidgetRef.current) {
                  scWidgetRef.current.seekTo(value * 1000); // seconds → ms
                } else {
                  ytPlayerRef.current?.seekTo?.(value, true);
                }
              }}
              className="music-range h-1 w-full cursor-pointer appearance-none rounded-lg bg-slate-500/40"
            />
            <span className="muted-text w-8 text-left font-mono text-[11px]">{formatTime(duration)}</span>
          </div>
        </div>

        <div className="hidden w-1/4 items-center justify-end gap-3 md:flex md:w-1/3">
          <button
            type="button"
            aria-label={t.lyrics.open}
            onClick={() => setIsLyricsOpen((value) => !value)}
            className={`pill-button gap-2 px-3 py-1.5 text-xs font-semibold ${isLyricsOpen ? 'border-pink-400 text-pink-400' : 'text-[var(--muted-text)]'}`}
          >
            <FileText size={15} />
            {t.lyrics.title}
          </button>
          <span className="rounded-full border border-[var(--border)] px-3 py-1 text-xs font-semibold text-[var(--muted-text)]">
            {isSoundCloud ? 'SC' : `${playbackRate}x`} · {volume}%
          </span>
        </div>
      </div>
    </div>
  );
}
