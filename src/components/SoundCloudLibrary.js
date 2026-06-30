"use client";

import { AlertCircle, Check, CloudDownload, ExternalLink, Loader2, Music, Plus, Trash2, X } from 'lucide-react';
import Image from 'next/image';
import { useCallback, useEffect, useState } from 'react';
import SettingsPanel from '@/components/SettingsPanel';
import AuthModal from '@/components/AuthModal';
import { formatDateTime, getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore, useUserStore } from '@/lib/store';

export default function SoundCloudLibrary() {
  const language = useSettingsStore((state) => state.language);
  const getUserId = useUserStore((state) => state.getUserId);
  const { setCurrentSong, setViewingSong, setPlaylist } = useMusicStore();
  const t = getDictionary(language);
  const sc = t.soundcloud;

  const [tracks, setTracks] = useState([]);
  const [loading, setLoading] = useState(true);
  const [importUrl, setImportUrl] = useState('');
  const [importing, setImporting] = useState(false);
  const [feedback, setFeedback] = useState(null);

  // Fetch imported tracks on mount
  useEffect(() => {
    let cancelled = false;

    async function load() {
      const userId = getUserId();
      try {
        const res = await fetch(`/api/soundcloud/import?userId=${encodeURIComponent(userId)}`);
        const data = await res.json();
        if (!cancelled && data.success) setTracks(data.data);
      } catch (error) {
        console.error('Failed to fetch SoundCloud tracks:', error);
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    load();
    return () => { cancelled = true; };
  }, [getUserId]);

  const showFeedback = useCallback((type, text) => {
    setFeedback({ type, text });
    setTimeout(() => setFeedback(null), 3500);
  }, []);

  const handleImport = async (event) => {
    event.preventDefault();
    const url = importUrl.trim();
    if (!url) return;

    setImporting(true);
    setFeedback(null);

    try {
      const userId = getUserId();
      const res = await fetch('/api/soundcloud/import', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, url }),
      });
      const data = await res.json();

      if (res.status === 409) {
        showFeedback('warn', sc.alreadyImported);
      } else if (res.status === 400 && data.message === 'invalid_url') {
        showFeedback('error', sc.invalidUrl);
      } else if (!res.ok) {
        showFeedback('error', sc.importError);
      } else if (data.success) {
        setTracks((prev) => [data.data, ...prev]);
        setImportUrl('');
        showFeedback('ok', `${sc.importSuccess} "${data.data.title}"`);
      }
    } catch (error) {
      console.error('Import failed:', error);
      showFeedback('error', sc.importError);
    } finally {
      setImporting(false);
    }
  };

  const handleDelete = async (scId) => {
    const userId = getUserId();
    try {
      const res = await fetch('/api/soundcloud/import', {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ userId, scId }),
      });
      const data = await res.json();
      if (data.success) {
        setTracks((prev) => prev.filter((t) => t.id !== scId));
      }
    } catch (error) {
      console.error('Delete failed:', error);
    }
  };

  const handlePlayTrack = (track) => {
    setCurrentSong(track);
    setPlaylist(tracks);
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
              <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-orange-500/15 text-orange-400">
                <CloudDownload size={28} />
              </div>
              <div>
                <p className="mb-1 text-xs font-semibold uppercase tracking-[0.42em] text-orange-400">
                  {t.common.brand}
                </p>
                <h1 className="bg-gradient-to-r from-orange-400 to-pink-500 bg-clip-text text-4xl font-extrabold text-transparent sm:text-5xl">
                  SoundCloud
                </h1>
              </div>
            </div>

            <p className="muted-text max-w-2xl text-sm sm:text-base">{sc.subtitle}</p>
          </div>
        </div>
      </header>

      <section className="mx-auto mt-8 max-w-3xl px-4 sm:px-8">
        {/* Import Form */}
        <form onSubmit={handleImport} className="mb-6">
          <div className="flex gap-3">
            <div className="relative flex-1">
              <input
                type="url"
                value={importUrl}
                onChange={(event) => setImportUrl(event.target.value)}
                placeholder={sc.placeholder}
                disabled={importing}
                className="search-input w-full rounded-2xl px-5 py-3 text-sm font-medium disabled:opacity-50"
              />
            </div>
            <button
              type="submit"
              disabled={importing || !importUrl.trim()}
              className="search-submit-button flex items-center gap-2 rounded-2xl px-5 py-3 text-sm font-bold text-white disabled:opacity-40"
            >
              {importing ? (
                <Loader2 size={18} className="animate-spin" />
              ) : (
                <Plus size={18} />
              )}
              {sc.importButton}
            </button>
          </div>

          {/* Feedback */}
          {feedback && (
            <div className={`mt-3 flex items-center gap-2 rounded-xl px-4 py-2.5 text-sm font-semibold ${
              feedback.type === 'ok'
                ? 'bg-emerald-500/15 text-emerald-400'
                : feedback.type === 'warn'
                  ? 'bg-amber-500/15 text-amber-400'
                  : 'bg-red-500/15 text-red-400'
            }`}>
              {feedback.type === 'ok' ? <Check size={15} /> :
               feedback.type === 'warn' ? <AlertCircle size={15} /> :
               <X size={15} />}
              {feedback.text}
            </div>
          )}
        </form>

        {/* Hint */}
        <div className="mb-8 rounded-2xl border border-orange-400/20 bg-orange-500/5 p-4">
          <p className="text-sm font-semibold text-orange-400">{sc.hintTitle}</p>
          <p className="muted-text mt-1 text-sm">{sc.hintDescription}</p>
        </div>

        {/* Track List */}
        {loading ? (
          <div className="surface-card rounded-3xl p-10 text-center">
            <p className="muted-text text-sm">Loading...</p>
          </div>
        ) : tracks.length === 0 ? (
          <div className="surface-card rounded-3xl p-10 text-center">
            <p className="mb-2 text-xl font-bold text-orange-400">{sc.emptyTitle}</p>
            <p className="muted-text">{sc.emptyDescription}</p>
          </div>
        ) : (
          <>
            <div className="mb-4 flex items-end justify-between">
              <div>
                <p className="text-sm font-semibold uppercase tracking-[0.28em] text-orange-400">
                  {sc.libraryLabel}
                </p>
                <h2 className="mt-1 text-2xl font-extrabold">
                  {tracks.length} {sc.tracksCount}
                </h2>
              </div>
            </div>

            <div className="flex flex-col gap-3">
              {tracks.map((track) => (
                <div
                  key={track.id}
                  className="surface-card surface-card-hover group relative cursor-pointer select-none overflow-hidden rounded-3xl p-4 sm:p-5"
                >
                  <div className="pointer-events-none absolute inset-0 bg-gradient-to-r from-orange-500/10 via-transparent to-pink-500/10 opacity-0 transition-opacity group-hover:opacity-100" />

                  <div className="relative z-10 flex items-center gap-4 sm:gap-5">
                    {/* Thumbnail */}
                    <div className="relative h-16 w-16 flex-shrink-0 overflow-hidden rounded-2xl bg-[var(--surface-strong)] shadow-lg sm:h-20 sm:w-20">
                      {track.thumbnail ? (
                        <Image
                          src={track.thumbnail}
                          alt=""
                          fill
                          sizes="80px"
                          className="object-cover"
                        />
                      ) : (
                        <div className="flex h-full w-full items-center justify-center text-orange-400">
                          <Music size={24} />
                        </div>
                      )}
                      <div className="absolute inset-0 bg-black/45 opacity-0 transition-opacity group-hover:opacity-100" />
                    </div>

                    {/* Info */}
                    <div
                      className="min-w-0 flex-1"
                      onClick={() => setViewingSong(track)}
                      onDoubleClick={() => handlePlayTrack(track)}
                    >
                      <h3 className="line-clamp-2 text-base font-bold text-[var(--app-text)] transition-colors group-hover:text-orange-400 sm:text-lg">
                        {track.title}
                      </h3>
                      <p className="muted-text mt-1 text-sm">{track.artist}</p>
                      {track.importedAt && (
                        <p className="mt-1 text-xs font-medium text-orange-400/70">
                          {sc.importedAt}: {formatDateTime(track.importedAt, language)}
                        </p>
                      )}
                    </div>

                    {/* Actions */}
                    <div className="flex items-center gap-2">
                      <a
                        href={track.sourceUrl}
                        target="_blank"
                        rel="noreferrer"
                        className="flex h-9 w-9 items-center justify-center rounded-full text-[var(--muted-text)] transition hover:bg-[var(--surface-hover)] hover:text-orange-400"
                        aria-label={sc.openOnSoundCloud}
                        title={sc.openOnSoundCloud}
                        onClick={(e) => e.stopPropagation()}
                      >
                        <ExternalLink size={16} />
                      </a>
                      <button
                        type="button"
                        onClick={(e) => { e.stopPropagation(); handleDelete(track.id); }}
                        className="flex h-9 w-9 items-center justify-center rounded-full text-[var(--muted-text)] transition hover:bg-red-500/15 hover:text-red-400"
                        aria-label={sc.deleteTrack}
                        title={sc.deleteTrack}
                      >
                        <Trash2 size={16} />
                      </button>
                    </div>
                  </div>
                </div>
              ))}
            </div>
          </>
        )}
      </section>
    </main>
  );
}
