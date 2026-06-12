"use client";

import { Check, ExternalLink, FileText, ListPlus, Play, Radio, X } from 'lucide-react';
import Image from 'next/image';
import { useCallback, useEffect, useState } from 'react';
import { formatDate, formatDateTime, getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore, useUserStore } from '@/lib/store';

export default function SongModal() {
  const { viewingSong, setViewingSong, setCurrentSong } = useMusicStore();
  const language = useSettingsStore((state) => state.language);
  const getUserId = useUserStore((state) => state.getUserId);
  const t = getDictionary(language);

  const [showPlaylistMenu, setShowPlaylistMenu] = useState(false);
  const [playlists, setPlaylists] = useState([]);
  const [feedback, setFeedback] = useState(null);

  const fetchPlaylists = useCallback(async () => {
    const userId = getUserId();
    try {
      const res = await fetch(`/api/playlist?userId=${encodeURIComponent(userId)}`);
      const data = await res.json();
      if (data.success) setPlaylists(data.data);
    } catch (error) {
      console.error('Failed to fetch playlists:', error);
    }
  }, [getUserId]);

  useEffect(() => {
    if (!showPlaylistMenu) return;

    let cancelled = false;

    async function load() {
      const userId = getUserId();
      try {
        const res = await fetch(`/api/playlist?userId=${encodeURIComponent(userId)}`);
        const data = await res.json();
        if (!cancelled && data.success) setPlaylists(data.data);
      } catch (error) {
        console.error('Failed to fetch playlists:', error);
      }
    }

    load();
    return () => { cancelled = true; };
  }, [showPlaylistMenu, getUserId]);

  const handleAddToPlaylist = async (playlistId, playlistName) => {
    const userId = getUserId();
    try {
      const res = await fetch('/api/playlist/song', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          userId,
          playlistId,
          song: {
            id: viewingSong.id,
            title: viewingSong.title,
            thumbnail: viewingSong.thumbnail,
            artist: viewingSong.artist,
            publishedAt: viewingSong.publishedAt,
          },
        }),
      });
      const data = await res.json();

      if (res.status === 409) {
        setFeedback({ type: 'warn', text: t.playlist.alreadyInPlaylist });
      } else if (data.success) {
        setFeedback({ type: 'ok', text: `${t.playlist.addedToPlaylist} "${playlistName}"` });
      }

      setTimeout(() => setFeedback(null), 2500);
    } catch (error) {
      console.error('Failed to add song:', error);
    }
  };

  const closeModal = () => {
    setShowPlaylistMenu(false);
    setFeedback(null);
    setViewingSong(null);
  };

  if (!viewingSong) return null;

  const youtubeUrl = viewingSong.id ? `https://www.youtube.com/watch?v=${viewingSong.id}` : null;
  const songDetails = [
    {
      icon: Radio,
      label: t.modal.artistChannel,
      value: viewingSong.artist || t.common.unknownArtist,
    },
  ];

  if (viewingSong.publishedAt) {
    songDetails.push({
      icon: FileText,
      label: t.modal.releaseDate,
      value: formatDate(viewingSong.publishedAt, language),
    });
  }

  if (viewingSong.listenedAt) {
    songDetails.push({
      icon: FileText,
      label: t.modal.listenedAt,
      value: formatDateTime(viewingSong.listenedAt, language),
    });
  }

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 p-4 backdrop-blur-md">
      <div className="modal-shell relative max-h-[92vh] w-full max-w-3xl overflow-y-auto rounded-3xl p-6 shadow-2xl shadow-pink-500/10">
        <button
          type="button"
          aria-label={t.modal.close}
          onClick={closeModal}
          className="absolute right-4 top-4 rounded-full p-2 text-[var(--muted-text)] transition hover:bg-[var(--surface-hover)] hover:text-[var(--app-text)]"
        >
          <X size={22} />
        </button>

        <div className="mt-4 grid gap-6 md:grid-cols-[1fr_1.05fr]">
          <div>
            <div className="aspect-video w-full overflow-hidden rounded-3xl bg-[var(--surface-strong)] shadow-lg">
              {viewingSong.thumbnail && (
                <Image
                  src={viewingSong.thumbnail}
                  alt=""
                  width={640}
                  height={360}
                  className="h-full w-full object-cover"
                />
              )}
            </div>

            <div className="mt-4 flex flex-wrap gap-3">
              <button
                type="button"
                onClick={() => {
                  setCurrentSong(viewingSong);
                  closeModal();
                }}
                className="flex flex-1 items-center justify-center gap-2 rounded-full bg-gradient-to-r from-purple-500 to-pink-600 px-5 py-3 font-bold text-white transition-all hover:scale-[1.02] hover:from-purple-400 hover:to-pink-500"
              >
                <Play fill="white" size={20} />
                {t.modal.playNow}
              </button>
              {youtubeUrl && (
                <a
                  href={youtubeUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="pill-button gap-2 px-5 py-3 text-sm font-bold"
                >
                  <ExternalLink size={18} />
                  {t.modal.openOnYouTube}
                </a>
              )}
            </div>

            {/* Add to Playlist */}
            <div className="relative mt-3">
              <button
                type="button"
                onClick={() => setShowPlaylistMenu((v) => !v)}
                className="pill-button w-full justify-center gap-2 px-5 py-3 text-sm font-bold"
              >
                <ListPlus size={18} />
                {t.playlist.addToPlaylist}
              </button>

              {showPlaylistMenu && (
                <div className="absolute left-0 right-0 top-full z-10 mt-2 max-h-48 overflow-y-auto rounded-2xl border border-[var(--border)] bg-[var(--modal-bg)] p-2 shadow-xl backdrop-blur-xl">
                  {playlists.length === 0 ? (
                    <p className="muted-text px-3 py-3 text-center text-xs">{t.playlist.noPlaylistYet}</p>
                  ) : (
                    playlists.map((pl) => (
                      <button
                        key={pl.id}
                        type="button"
                        onClick={() => handleAddToPlaylist(pl.id, pl.name)}
                        className="flex w-full items-center gap-3 rounded-xl px-3 py-2.5 text-left text-sm font-semibold transition hover:bg-[var(--surface-hover)]"
                      >
                        <ListPlus size={15} className="flex-shrink-0 text-purple-400" />
                        <span className="flex-1 truncate">{pl.name}</span>
                        <span className="muted-text text-xs">{pl.songs.length} {t.playlist.songCount}</span>
                      </button>
                    ))
                  )}
                </div>
              )}

              {/* Feedback toast */}
              {feedback && (
                <div className={`mt-2 flex items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold ${
                  feedback.type === 'ok'
                    ? 'bg-emerald-500/15 text-emerald-400'
                    : 'bg-amber-500/15 text-amber-400'
                }`}>
                  <Check size={15} />
                  {feedback.text}
                </div>
              )}
            </div>
          </div>

          <div>
            <p className="mb-2 text-sm font-semibold uppercase tracking-[0.28em] text-pink-400">
              {t.modal.details}
            </p>
            <h2
              className="mb-5 text-2xl font-extrabold leading-tight text-[var(--app-text)]"
              dangerouslySetInnerHTML={{ __html: viewingSong.title }}
            />

            <div className="grid gap-3">
              {songDetails.map((item) => {
                const Icon = item.icon;

                return (
                  <div key={`${item.label}-${item.value}`} className="detail-chip">
                    <div className="mb-1 flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">
                      <Icon size={15} />
                      {item.label}
                    </div>
                    <p className="break-words text-sm font-semibold">{item.value}</p>
                  </div>
                );
              })}
            </div>

            <section className="detail-chip mt-4">
              <div className="mb-2 flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.18em] text-pink-400">
                <FileText size={15} />
                {t.lyrics.title}
              </div>
              {viewingSong.lyrics ? (
                <p className="max-h-40 overflow-y-auto whitespace-pre-line text-sm leading-7">
                  {viewingSong.lyrics}
                </p>
              ) : (
                <div>
                  <p className="font-semibold text-[var(--app-text)]">{t.lyrics.unavailableTitle}</p>
                  <p className="muted-text mt-1 text-sm leading-6">{t.lyrics.unavailableDescription}</p>
                </div>
              )}
            </section>
          </div>
        </div>
      </div>
    </div>
  );
}
