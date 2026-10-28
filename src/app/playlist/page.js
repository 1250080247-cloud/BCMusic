"use client";

import MotionList from '@/components/MotionList';
import PlaylistArtwork from '@/components/PlaylistArtwork';

import { decodeSongTitle } from '@/lib/song-title';

import { ChevronDown, ChevronUp, ListMusic, Play, Plus, Trash2, X } from 'lucide-react';
import Image from 'next/image';
import { useEffect, useState } from 'react';
import { useSession } from 'next-auth/react';
import SettingsPanel from '@/components/SettingsPanel';
import AuthModal from '@/components/AuthModal';
import { formatDateTime, getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore } from '@/lib/store';

export default function PlaylistPage() {
  const { data: session } = useSession();
  const language = useSettingsStore((state) => state.language);
  const { startPlayback, setViewingSong } = useMusicStore();
  const t = getDictionary(language);

  const [playlists, setPlaylists] = useState([]);
  const [newName, setNewName] = useState('');
  const [loading, setLoading] = useState(true);
  const [expandedId, setExpandedId] = useState(null);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const res = await fetch('/api/playlist');
        const data = await res.json();
        if (!cancelled && data.success) setPlaylists(data.data);
      } catch (error) {
        console.error('Failed to fetch playlists:', error);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    load();
    return () => { cancelled = true; };
  }, [session?.user?.id]);

  const handleCreate = async (event) => {
    event.preventDefault();
    const trimmed = newName.trim();
    if (!trimmed) return;
    try {
      const res = await fetch('/api/playlist', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ name: trimmed }),
      });
      const data = await res.json();
      if (data.success) {
        setPlaylists((prev) => [data.data, ...prev]);
        setNewName('');
      }
    } catch (error) {
      console.error('Failed to create playlist:', error);
    }
  };

  const handleDelete = async (playlistId) => {
    try {
      const res = await fetch('/api/playlist', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ playlistId }),
      });
      const data = await res.json();
      if (data.success) {
        setPlaylists((prev) => prev.filter((p) => p.id !== playlistId));
        if (expandedId === playlistId) setExpandedId(null);
      }
    } catch (error) {
      console.error('Failed to delete playlist:', error);
    }
  };

  const handleRemoveSong = async (playlistId, songId) => {
    try {
      const res = await fetch('/api/playlist/song', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ playlistId, songId }),
      });
      const data = await res.json();
      if (data.success) {
        setPlaylists((prev) =>
          prev.map((p) => {
            if (p.id !== playlistId) return p;
            return { ...p, songs: p.songs.filter((s) => s.id !== songId) };
          })
        );
      }
    } catch (error) {
      console.error('Failed to remove song:', error);
    }
  };

  const handlePlayAll = (playlist) => {
    if (!playlist.songs.length) return;
    startPlayback(playlist.songs[0], playlist.songs);
  };

  return (
    <main className="app-shell relative pb-8">
      <header className="px-4 pt-10 sm:px-8 sm:pt-12">
        <div className="mx-auto max-w-screen-xl">
          <div className="relative flex flex-col items-center text-center">
            <div className="absolute right-0 top-0 flex items-center gap-2">
              <div className="md:hidden header-auth-wrapper">
                <AuthModal />
              </div>
              <SettingsPanel />
            </div>

            <div className="mb-5 flex flex-col items-center gap-4 sm:flex-row">
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-purple-500/15 text-purple-400">
                <ListMusic size={28} />
              </div>
              <div>
                <p className="mb-1 text-xs font-semibold uppercase tracking-[0.42em] text-purple-400">
                  {t.common.brand}
                </p>
                <h1 className="bg-gradient-to-r from-purple-400 to-pink-500 bg-clip-text text-4xl font-extrabold text-transparent sm:text-5xl">
                  {t.playlist.title}
                </h1>
              </div>
            </div>

            <p className="muted-text max-w-2xl text-sm sm:text-base">{t.playlist.subtitle}</p>
          </div>
        </div>
      </header>

      <section className="mx-auto mt-8 max-w-6xl px-4 sm:px-8">
        {/* Create Playlist Form */}
        <form onSubmit={handleCreate} className="mb-8 flex gap-3">
          <input
            type="text"
            value={newName}
            onChange={(event) => setNewName(event.target.value)}
            placeholder={t.playlist.namePlaceholder}
            className="search-input min-w-0 flex-1 rounded-2xl px-5 py-3 text-sm font-medium"
          />
          <button
            type="submit"
            disabled={!newName.trim()}
            className="search-submit-button flex items-center gap-2 rounded-2xl px-5 py-3 text-sm font-bold text-white disabled:opacity-40"
          >
            <Plus size={18} />
            {t.playlist.create}
          </button>
        </form>

        {/* Playlists */}
        {loading ? (
          <div className="surface-card rounded-3xl p-10 text-center">
            <p className="muted-text text-sm">Loading...</p>
          </div>
        ) : playlists.length === 0 ? (
          <div className="surface-card rounded-3xl p-10 text-center">
            <p className="mb-2 text-xl font-bold text-purple-400">{t.playlist.emptyTitle}</p>
            <p className="muted-text">{t.playlist.emptyDescription}</p>
          </div>
        ) : (
          <MotionList animationKey={playlists.map((item) => item.id).join('|')} className="flex flex-col gap-4">
            {playlists.map((pl) => {
              const isExpanded = expandedId === pl.id;

              return (
                <div key={pl.id} className="surface-card overflow-hidden rounded-3xl">
                  {/* Playlist Header */}
                  <div className="grid grid-cols-[80px_minmax(0,1fr)] items-center gap-x-4 gap-y-3 p-4 sm:flex sm:gap-6 sm:p-6">
                    <div className="row-span-2 sm:row-span-1"><PlaylistArtwork songs={pl.songs} /></div>
                    <div className="min-w-0 flex-1">
                      <h2 className="break-words text-xl font-bold sm:text-2xl">{pl.name}</h2>
                      <p className="muted-text mt-1 text-xs leading-5 sm:text-sm">
                        {pl.songs.length} {t.playlist.songCount}
                        {pl.createdAt && ` · ${t.playlist.createdAt} ${formatDateTime(pl.createdAt, language)}`}
                      </p>
                    </div>
                    <div className="col-start-2 flex items-center gap-1 sm:gap-2">
                      {pl.songs.length > 0 && (
                        <button
                          type="button"
                          onClick={() => handlePlayAll(pl)}
                          className="flex h-11 w-11 items-center justify-center rounded-full bg-gradient-to-r from-purple-500 to-pink-600 text-white transition hover:scale-105"
                          aria-label={t.playlist.playAll}
                          title={t.playlist.playAll}
                        >
                          <Play fill="white" size={18} />
                        </button>
                      )}
                      <button
                        type="button"
                        onClick={() => setExpandedId(isExpanded ? null : pl.id)}
                        className="flex h-11 w-11 items-center justify-center rounded-full text-[var(--muted-text)] transition hover:bg-[var(--surface-hover)] hover:text-[var(--app-text)]"
                        aria-label={isExpanded ? 'Collapse' : 'Expand'}
                        aria-expanded={isExpanded}
                        aria-controls={`playlist-songs-${pl.id}`}
                      >
                        {isExpanded ? <ChevronUp size={18} /> : <ChevronDown size={18} />}
                      </button>
                      <button
                        type="button"
                        onClick={() => handleDelete(pl.id)}
                        className="flex h-11 w-11 items-center justify-center rounded-full text-[var(--muted-text)] transition hover:bg-red-500/15 hover:text-red-400"
                        aria-label={t.playlist.deletePlaylist}
                        title={t.playlist.deletePlaylist}
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </div>

                  {/* Songs List (expanded) */}
                  {isExpanded && (
                    <div id={`playlist-songs-${pl.id}`} className="border-t border-[var(--border)] px-4 pb-5 pt-4 sm:px-6">
                      {pl.songs.length === 0 ? (
                        <p className="muted-text py-4 text-center text-sm">{t.playlist.emptyDescription}</p>
                      ) : (
                        <div className="flex flex-col gap-3">
                          <p className="muted-text text-xs font-semibold uppercase tracking-[0.2em]">
                            {t.playlist.songsInPlaylist}
                          </p>
                          {pl.songs.map((song) => (
                            <div
                              key={song.id}
                              className="group flex items-center gap-3 rounded-2xl p-3 transition hover:bg-[var(--surface-hover)]"
                            >
                              <div className="relative h-12 w-20 flex-shrink-0 overflow-hidden rounded-xl bg-[var(--surface-strong)]">
                                {song.thumbnail && (
                                  <Image
                                    src={song.thumbnail}
                                    alt=""
                                    fill
                                    sizes="80px"
                                    className="object-cover"
                                  />
                                )}
                              </div>
                              <div className="min-w-0 flex-1">
                                <button
                                  type="button"
                                  onClick={() => setViewingSong(song, pl.songs)}
                                  className="text-left"
                                >
                                  <p
                                    className="line-clamp-1 text-sm font-semibold transition-colors group-hover:text-pink-400">{decodeSongTitle(song.title)}</p>
                                </button>
                                <p className="muted-text truncate text-xs">{song.artist}</p>
                              </div>
                              <div className="flex items-center gap-2">
                                <button
                                  type="button"
                                  onClick={() => {
                                    startPlayback(song, pl.songs);
                                  }}
                                  className="flex h-8 w-8 items-center justify-center rounded-full text-[var(--muted-text)] opacity-0 transition hover:text-[var(--app-text)] group-hover:opacity-100"
                                  aria-label={t.modal.playNow}
                                >
                                  <Play size={14} fill="currentColor" />
                                </button>
                                <button
                                  type="button"
                                  onClick={() => handleRemoveSong(pl.id, song.id)}
                                  className="flex h-8 w-8 items-center justify-center rounded-full text-[var(--muted-text)] opacity-0 transition hover:text-red-400 group-hover:opacity-100"
                                  aria-label={t.playlist.removeSong}
                                  title={t.playlist.removeSong}
                                >
                                  <X size={14} />
                                </button>
                              </div>
                            </div>
                          ))}
                        </div>
                      )}
                    </div>
                  )}
                </div>
              );
            })}
          </MotionList>
        )}
      </section>
    </main>
  );
}
