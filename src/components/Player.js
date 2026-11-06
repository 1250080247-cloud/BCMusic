"use client";

import { decodeSongTitle } from '@/lib/song-title';

import { FileText, Heart, Pause, Play, Repeat, Repeat1, Shuffle, SkipBack, SkipForward, Timer, Volume2, X } from 'lucide-react';
import Image from 'next/image';
import { useEffect, useRef, useState, useCallback } from 'react';
import YouTube from 'react-youtube';
import { getDictionary } from '@/lib/i18n';
import { useSession } from 'next-auth/react';
import { useMusicStore, useSettingsStore } from '@/lib/store';
import { safeEmbedUrl } from '@/lib/url-policy';

// Module-level so react-youtube does not see a new options object on every render.
const YOUTUBE_OPTS = { playerVars: { autoplay: 1, controls: 0, rel: 0 } };
// Sleep timer choices in minutes. 0 means off.
const SLEEP_OPTIONS = [0, 15, 30, 60];

export default function Player() {
  const { data: session } = useSession();
  const [isPlaying, setIsPlaying] = useState(false);
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const ytPlayerRef = useRef(null);
  const scWidgetRef = useRef(null);
  const scIframeRef = useRef(null);
  const lastSongIdRef = useRef(null);
  const scApiLoadedRef = useRef(false);
  const handleTrackEndRef = useRef(null);
  const playNextRef = useRef(null);
  const togglePlayRef = useRef(null);
  const historySavedForRef = useRef(null);
  const consecutiveErrorsRef = useRef(0);
  const shuffleRoundRef = useRef(new Set());
  const [sleepMinutes, setSleepMinutes] = useState(0);
  const [sleepEndsAt, setSleepEndsAt] = useState(null);
  const {
    currentSong,
    playlist,
    setCurrentSong,
    repeatMode,
    cycleRepeatMode,
    toggleNowPlaying,
    setNowPlayingOpen,
    favorites,
    addFavorite,
    removeFavorite,
    shuffle,
    toggleShuffle,
    shiftQueue,
  } = useMusicStore();
  const language = useSettingsStore((state) => state.language);
  const volume = useSettingsStore((state) => state.volume);
  const playbackRate = useSettingsStore((state) => state.playbackRate);
  const t = getDictionary(language);

  const isFavorited = currentSong && favorites?.some((s) => s.id === currentSong.id);

  const handleFavoriteToggle = async () => {
    if (!currentSong) return;
    if (!session?.user?.id) {
      alert(t.player.loginToFavorite);
      return;
    }

    if (isFavorited) {
      try {
        const res = await fetch(`/api/favorites?songId=${encodeURIComponent(currentSong.id)}`, {
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


  const isSoundCloud = currentSong?.source === 'soundcloud';

  // Record history once a track actually starts (player reports playback), so tracks that never play are not logged.
  const recordPlayback = (song) => {
    if (!song || historySavedForRef.current === song.id) return;
    historySavedForRef.current = song.id;
    fetch('/api/history', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        id: song.id,
        title: song.title,
        thumbnail: song.thumbnail,
        artist: song.artist,
        publishedAt: song.publishedAt,
        lyrics: song.lyrics,
        embedUrl: song.embedUrl,
        sourceUrl: song.sourceUrl,
        source: song.source || 'youtube',
      }),
    }).catch((error) => console.error('Unable to save listening history', error));
  };

  useEffect(() => {
    if (!currentSong) historySavedForRef.current = null;
  }, [currentSong]);

  // Broadcast play-state to NowPlayingPanel
  useEffect(() => {
    const broadcast = () => window.dispatchEvent(
      new CustomEvent('bcmusic:playstate', { detail: { songId: currentSong?.id, isPlaying } })
    );
    broadcast();
    window.addEventListener('bcmusic:requestplaystate', broadcast);
    return () => window.removeEventListener('bcmusic:requestplaystate', broadcast);
  }, [isPlaying, currentSong?.id]);

  // Broadcast time updates to NowPlayingPanel
  useEffect(() => {
    window.dispatchEvent(
      new CustomEvent('bcmusic:timeupdate', { detail: { songId: lastSongIdRef.current, currentTime, duration } })
    );
  }, [currentTime, duration, currentSong?.id]);

  // Listen for seek commands from NowPlayingPanel
  useEffect(() => {
    const handleSeekTo = (e) => {
      const time = e.detail?.time;
      if (time === undefined) return;
      if (isSoundCloud && scWidgetRef.current) {
        scWidgetRef.current.seekTo(time * 1000);
      } else if (ytPlayerRef.current?.seekTo) {
        ytPlayerRef.current.seekTo(time, true);
      }
      setCurrentTime(time);
    };
    // Same behavior as the play button: the ref always holds the latest togglePlay.
    const handleTogglePlay = () => togglePlayRef.current?.();
    window.addEventListener('bcmusic:seekto', handleSeekTo);
    window.addEventListener('bcmusic:toggleplay', handleTogglePlay);
    return () => {
      window.removeEventListener('bcmusic:seekto', handleSeekTo);
      window.removeEventListener('bcmusic:toggleplay', handleTogglePlay);
    };
  }, [isSoundCloud, isPlaying]);


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

    // Another mount may already be loading the same script.
    if (document.querySelector('script[data-sc-widget-api]')) return;

    const script = document.createElement('script');
    script.src = 'https://w.soundcloud.com/player/api.js';
    script.async = true;
    script.dataset.scWidgetApi = 'true';
    script.onload = () => {
      scApiLoadedRef.current = true;
    };
    script.onerror = () => {
      script.remove();
      console.error('SoundCloud Widget API failed to load.');
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
        recordPlayback(currentSong);
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
      // Give up after 15 seconds instead of polling for the rest of the track.
      const startedAt = Date.now();
      const checkInterval = setInterval(() => {
        if (window.SC?.Widget) {
          clearInterval(checkInterval);
          initWidget();
        } else if (Date.now() - startedAt > 15_000) {
          clearInterval(checkInterval);
          console.error('SoundCloud Widget API did not become available.');
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
  const stopPlayback = useCallback(() => {
    if (isSoundCloud) scWidgetRef.current?.pause();
    else ytPlayerRef.current?.pauseVideo?.();
    setIsPlaying(false);
  }, [isSoundCloud]);

  const replayTrack = useCallback(() => {
    if (isSoundCloud && scWidgetRef.current) {
      scWidgetRef.current.seekTo(0);
      scWidgetRef.current.play();
    } else if (ytPlayerRef.current) {
      ytPlayerRef.current.seekTo(0, true);
      ytPlayerRef.current.playVideo();
    }
    setCurrentTime(0);
  }, [isSoundCloud]);

  const playNext = useCallback(() => {
    // A queued track plays before the list continues.
    const queued = shiftQueue();
    if (queued) {
      setCurrentSong(queued);
      return;
    }
    if (!playlist.length || !currentSong) return;

    if (shuffle) {
      // Each round plays every track once. Repeat off stops at the end of a round; repeat on starts another.
      const played = shuffleRoundRef.current;
      played.add(currentSong.id);
      let pool = playlist.filter((song) => !played.has(song.id));
      if (!pool.length) {
        if (repeatMode === 'off') {
          stopPlayback();
          return;
        }
        played.clear();
        played.add(currentSong.id);
        pool = playlist.filter((song) => song.id !== currentSong.id);
      }
      if (!pool.length) {
        replayTrack();
        return;
      }
      setCurrentSong(pool[Math.floor(Math.random() * pool.length)]);
      return;
    }

    const currentIndex = playlist.findIndex((song) => song.id === currentSong.id);
    if (repeatMode === 'off') {
      // Stop at end of playlist
      const nextIndex = currentIndex + 1;
      if (nextIndex >= playlist.length) {
        stopPlayback();
        return;
      }
      const next = playlist[nextIndex];
      if (next.id === currentSong.id) replayTrack();
      else setCurrentSong(next);
    } else {
      // repeat 'all': wrap around
      const nextIndex = currentIndex === -1 ? 0 : (currentIndex + 1) % playlist.length;
      const next = playlist[nextIndex];
      if (next.id === currentSong.id) replayTrack();
      else setCurrentSong(next);
    }
  }, [playlist, currentSong, setCurrentSong, repeatMode, shuffle, shiftQueue, stopPlayback, replayTrack]);

  useEffect(() => {
    playNextRef.current = playNext;
  }, [playNext]);

  // Sleep timer: stop playback when the chosen time has passed.
  const cycleSleepTimer = () => {
    const next = SLEEP_OPTIONS[(SLEEP_OPTIONS.indexOf(sleepMinutes) + 1) % SLEEP_OPTIONS.length];
    setSleepMinutes(next);
    setSleepEndsAt(next ? Date.now() + next * 60_000 : null);
  };

  useEffect(() => {
    if (!sleepEndsAt) return undefined;
    const timer = setTimeout(() => {
      stopPlayback();
      setSleepEndsAt(null);
      setSleepMinutes(0);
    }, Math.max(0, sleepEndsAt - Date.now()));
    return () => clearTimeout(timer);
  }, [sleepEndsAt, stopPlayback]);

  const playPrev = useCallback(() => {
    if (!playlist.length || !currentSong) return;
    // Past the first few seconds, Previous restarts the current track, as most players do.
    if (currentTime > 3) {
      replayTrack();
      return;
    }
    const currentIndex = playlist.findIndex((song) => song.id === currentSong.id);
    const prevIndex = currentIndex === -1 ? 0 : (currentIndex - 1 + playlist.length) % playlist.length;
    const previous = playlist[prevIndex];
    if (previous.id === currentSong.id) replayTrack();
    else setCurrentSong(previous);
  }, [playlist, currentSong, currentTime, setCurrentSong, replayTrack]);

  // Both control surfaces use this player as the single media controller.
  useEffect(() => {
    window.addEventListener('bcmusic:next', playNext);
    window.addEventListener('bcmusic:previous', playPrev);
    return () => {
      window.removeEventListener('bcmusic:next', playNext);
      window.removeEventListener('bcmusic:previous', playPrev);
    };
  }, [playNext, playPrev]);

  // Handle end-of-track (called by both YouTube and SoundCloud)
  const handleTrackEnd = useCallback(() => {
    if (repeatMode === 'one') {
      replayTrack();
    } else {
      setIsPlaying(false);
      playNext();
    }
  }, [repeatMode, replayTrack, playNext]);

  // Keep ref in sync so event-listener closures always call the latest version
  useEffect(() => {
    handleTrackEndRef.current = handleTrackEnd;
  }, [handleTrackEnd]);

  // ─── YouTube: Player ready ─────────────────────────────
  const onPlayerReady = (event) => {
    ytPlayerRef.current = event.target;
    window.dispatchEvent(new CustomEvent('bcmusic:playerror', { detail: { songId: currentSong?.id, code: null } }));
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

  // The media-key/event handler reads the latest togglePlay through this ref.
  useEffect(() => {
    togglePlayRef.current = togglePlay;
  });

  const formatTime = (time) => {
    if (!time) return "0:00";
    const minutes = Math.floor(time / 60);
    const seconds = Math.floor(time % 60);
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  };

  const handleCloseSong = () => {
    // Stop playback
    if (isSoundCloud && scWidgetRef.current) {
      try { scWidgetRef.current.pause(); } catch { /* ignore */ }
    } else if (ytPlayerRef.current?.pauseVideo) {
      ytPlayerRef.current.pauseVideo();
    }
    setIsPlaying(false);
    setNowPlayingOpen(false);
    setCurrentSong(null);
  };

  if (!currentSong) return null;

  return (
    <div className="player-shell">
      {/* ─── Hidden Players ──────────────────────────────── */}

      {/* YouTube Player (only rendered for YouTube tracks) */}
      {!isSoundCloud && (
        <div className="hidden">
          <YouTube
            videoId={currentSong.id}
            opts={YOUTUBE_OPTS}
            onReady={onPlayerReady}
            onError={(event) => {
              setIsPlaying(false);
              window.dispatchEvent(new CustomEvent('bcmusic:playerror', { detail: { songId: currentSong.id, code: event.data } }));
              // Skip an unplayable video so the queue keeps going. Stop after one failure per track in the list,
              // and never skip while repeating one track.
              consecutiveErrorsRef.current += 1;
              if (repeatMode !== 'one' && consecutiveErrorsRef.current < Math.max(1, playlist.length)) {
                playNextRef.current?.();
              }
            }}
            onStateChange={(event) => {
              if (event.data === 1) {
                if (lastSongIdRef.current !== currentSong.id) {
                  lastSongIdRef.current = currentSong.id;
                  setCurrentTime(0);
                  setDuration(0);
                }
                consecutiveErrorsRef.current = 0;
                setIsPlaying(true);
                recordPlayback(currentSong);
              }
              if (event.data === 2) setIsPlaying(false);
              if (event.data === 0) handleTrackEndRef.current?.();
            }}
          />
        </div>
      )}

      {/* SoundCloud Widget (only rendered for SoundCloud tracks) */}
      {isSoundCloud && safeEmbedUrl(currentSong.embedUrl) && (
        <div className="hidden">
          <iframe
            ref={scIframeRef}
            key={currentSong.id}
            id="sc-widget"
            title="SoundCloud Player"
            width="100%"
            height="166"
            allow="autoplay"
            src={safeEmbedUrl(currentSong.embedUrl)}
          />
        </div>
      )}

      {/* ─── Visible Player UI (shared for both sources) ─ */}
      <div className="player-inner">
        {/* Left: Song info (clickable to open Now Playing panel) */}
        <button
          type="button"
          aria-label={t.player.showDetails}
          onClick={toggleNowPlaying}
          className="player-song-info"
        >
          <div className="player-thumb">
            {currentSong.thumbnail && (
              <Image
                src={currentSong.thumbnail}
                alt={t.player.coverAlt}
                width={48}
                height={48}
                className="h-full w-full object-cover"
              />
            )}
          </div>
          <div className="player-song-text">
            <div className="player-title-marquee font-semibold text-[var(--app-text)]">
              <div className="player-title-track">
                <span className="player-title-copy">{decodeSongTitle(currentSong.title)}</span>
                <span className="player-title-copy" aria-hidden="true">{decodeSongTitle(currentSong.title)}</span>
              </div>
            </div>
            <p className="muted-text truncate text-xs">
              {currentSong.artist}
              {isSoundCloud && (
                <span className="ml-2 inline-flex items-center rounded bg-orange-500/15 px-1.5 py-0.5 text-[10px] font-bold text-orange-400">
                  SC
                </span>
              )}
            </p>
          </div>
        </button>

        {/* Center: Controls */}
        <div className="player-controls">
          <div className="player-controls-buttons">
            <button
              type="button"
              aria-label={t.player.shuffle}
              aria-pressed={shuffle}
              onClick={toggleShuffle}
              className={`player-control-btn ${shuffle ? 'text-pink-400' : 'muted-text'}`}
            >
              <Shuffle size={16} />
            </button>
            <button
              type="button"
              aria-label={t.player.previous}
              onClick={playPrev}
              className="player-control-btn muted-text"
            >
              <SkipBack size={18} />
            </button>
            <button
              type="button"
              aria-label={isPlaying ? t.player.pause : t.player.play}
              onClick={togglePlay}
              className="player-play-btn"
            >
              {isPlaying ? <Pause size={18} /> : <Play size={18} className="ml-0.5" />}
            </button>
            <button
              type="button"
              aria-label={t.player.next}
              onClick={playNext}
              className="player-control-btn muted-text"
            >
              <SkipForward size={18} />
            </button>
            <button
              type="button"
              aria-label={
                repeatMode === 'off' ? t.player.repeatOff
                : repeatMode === 'all' ? t.player.repeatAll
                : t.player.repeatOne
              }
              onClick={cycleRepeatMode}
              className={`player-control-btn relative ${
                repeatMode === 'off'
                  ? 'muted-text'
                  : 'text-pink-400'
              }`}
            >
              {repeatMode === 'one' ? <Repeat1 size={16} /> : <Repeat size={16} />}
              {repeatMode !== 'off' && (
                <span className="absolute -right-0.5 -top-0.5 flex h-1.5 w-1.5">
                  <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-pink-400 opacity-75" />
                  <span className="relative inline-flex h-1.5 w-1.5 rounded-full bg-pink-500" />
                </span>
              )}
            </button>
          </div>

          {/* Progress bar */}
          <div className="player-progress">
            <span className="player-time">{formatTime(currentTime)}</span>
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
              className="music-range player-range"
            />
            <span className="player-time">{formatTime(duration)}</span>
          </div>
        </div>

        {/* Right: Extra actions */}
        <div className="player-right-actions">
          <button
            type="button"
            aria-label={t.player.favorite}
            onClick={handleFavoriteToggle}
            className={`player-control-btn ${isFavorited ? 'text-pink-500 hover:text-pink-600' : 'muted-text'}`}
          >
            <Heart size={18} fill={isFavorited ? 'currentColor' : 'none'} />
          </button>
          <button
            type="button"
            aria-label={t.lyrics.open}
            onClick={() => setNowPlayingOpen(true)}
            className="player-control-btn muted-text"
          >
            <FileText size={18} />
          </button>
          <button
            type="button"
            aria-label={t.player.sleepTimer}
            title={t.player.sleepTimer}
            onClick={cycleSleepTimer}
            className={`player-control-btn flex items-center ${sleepMinutes ? 'text-cyan-400' : 'muted-text'}`}
          >
            <Timer size={18} />
            {sleepMinutes > 0 && <span className="ml-0.5 text-[10px] font-bold">{sleepMinutes}m</span>}
          </button>
          <div className="player-volume-group">
            <Volume2 size={16} className="muted-text flex-shrink-0" />
            <input
              type="range"
              min={0}
              max={100}
              value={volume}
              onChange={(event) => useSettingsStore.getState().setVolume(event.target.value)}
              className="music-range player-volume-range"
            />
          </div>
          <button
            type="button"
            aria-label={t.player.closePlayer}
            onClick={handleCloseSong}
            className="player-control-btn muted-text"
          >
            <X size={18} />
          </button>
        </div>
      </div>
    </div>
  );
}
