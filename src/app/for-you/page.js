"use client";

import { Play, Sparkles } from 'lucide-react';
import Image from 'next/image';
import { useEffect, useState } from 'react';
import { getDictionary } from '@/lib/i18n';
import { decodeSongTitle } from '@/lib/song-title';
import { useMusicStore, useSettingsStore } from '@/lib/store';

export default function ForYouPage() {
  const language = useSettingsStore((state) => state.language);
  const startPlayback = useMusicStore((state) => state.startPlayback);
  const t = getDictionary(language);
  const [view, setView] = useState({ status: 'loading', items: [], basedOn: [] });

  useEffect(() => {
    let cancelled = false;

    async function load() {
      try {
        const res = await fetch('/api/recommendations');
        const data = await res.json();
        if (cancelled) return;
        if (!res.ok || !data.success) {
          setView({ status: 'error', items: [], basedOn: [] });
          return;
        }
        setView({ status: 'ready', items: data.data, basedOn: data.basedOn ?? [] });
      } catch (error) {
        console.error('Failed to load recommendations:', error);
        if (!cancelled) setView({ status: 'error', items: [], basedOn: [] });
      }
    }

    load();
    return () => { cancelled = true; };
  }, []);

  return (
    <main className="app-shell relative pb-8">
      <header className="px-4 pt-10 sm:px-8 sm:pt-12">
        <div className="mx-auto max-w-screen-xl text-center">
          <div className="mb-4 flex justify-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-2xl bg-pink-500/15 text-pink-400">
              <Sparkles size={28} />
            </div>
          </div>
          <h1 className="text-3xl font-extrabold sm:text-4xl">{t.sidebar.forYou}</h1>
          <p className="muted-text mt-2 text-sm sm:text-base">{t.playlist.forYouHint}</p>
        </div>
      </header>

      <section className="mx-auto mt-8 max-w-4xl px-4 sm:px-8">
        {view.status === 'loading' && (
          <p className="muted-text text-center text-sm">{t.playlist.forYouLoading}</p>
        )}
        {view.status === 'error' && (
          <p className="muted-text text-center text-sm">{t.playlist.forYouError}</p>
        )}
        {view.status === 'ready' && view.items.length === 0 && (
          <p className="muted-text text-center text-sm">{t.playlist.forYouEmpty}</p>
        )}
        {view.status === 'ready' && view.items.length > 0 && (
          <>
            {view.basedOn.length > 0 && (
              <p className="muted-text mb-4 text-xs">{t.playlist.forYouBasedOn}: {view.basedOn.join(', ')}</p>
            )}
            <ul className="flex flex-col gap-3">
              {view.items.map((song) => (
                <li key={song.id} className="surface-card flex items-center gap-4 rounded-2xl p-3">
                  <div className="relative h-14 w-24 flex-shrink-0 overflow-hidden rounded-xl bg-[var(--surface-strong)]">
                    {song.thumbnail && (
                      <Image src={song.thumbnail} alt="" fill sizes="96px" className="object-cover" />
                    )}
                  </div>
                  <div className="min-w-0 flex-1">
                    <p className="line-clamp-1 text-sm font-semibold">{decodeSongTitle(song.title)}</p>
                    <p className="muted-text truncate text-xs">{song.artist}</p>
                  </div>
                  <button
                    type="button"
                    onClick={() => startPlayback(song, view.items)}
                    aria-label={t.modal.playNow}
                    title={t.modal.playNow}
                    className="flex h-10 w-10 flex-shrink-0 items-center justify-center rounded-full bg-gradient-to-r from-purple-500 to-pink-600 text-white transition hover:scale-105"
                  >
                    <Play fill="white" size={16} />
                  </button>
                </li>
              ))}
            </ul>
          </>
        )}
      </section>
    </main>
  );
}
