"use client";

import { Clock, Music, Sparkles } from 'lucide-react';
import Image from 'next/image';
import SettingsPanel from '@/components/SettingsPanel';
import SongCard from '@/components/SongCard';
import { formatDateTime, getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

export default function HistoryView({ songs }) {
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);
  const latestListen = songs[0]?.listenedAt ? formatDateTime(songs[0].listenedAt, language) : t.common.unknownDate;

  return (
    <main className="app-shell relative pb-8">
      <header className="px-4 pt-10 sm:px-8 sm:pt-12">
        <div className="mx-auto max-w-screen-xl">
          <div className="relative flex flex-col items-center text-center">
            <div className="absolute right-0 top-0">
              <SettingsPanel />
            </div>

            <div className="mb-5 flex flex-col items-center gap-4 sm:flex-row">
              <div className="h-16 w-16 overflow-hidden rounded-full border-2 border-cyan-400 shadow-[0_0_24px_rgba(6,182,212,0.4)]">
                <Image src="/logo.jpg" alt="BCMusic Logo" width={64} height={64} className="h-full w-full object-cover" />
              </div>
              <div>
                <p className="mb-1 text-xs font-semibold uppercase tracking-[0.42em] text-cyan-400">
                  {t.common.brand}
                </p>
                <h1 className="flex items-center justify-center gap-3 bg-gradient-to-r from-cyan-400 to-blue-500 bg-clip-text text-4xl font-extrabold text-transparent sm:text-5xl">
                  <Clock size={38} className="text-cyan-400" />
                  {t.history.title}
                </h1>
              </div>
            </div>

            <p className="muted-text max-w-2xl text-sm sm:text-base">{t.history.subtitle}</p>
          </div>
        </div>
      </header>

      <section className="mx-auto mt-8 max-w-5xl px-4 sm:px-8">
        <div className="grid gap-4 md:grid-cols-3">
          <div className="surface-card rounded-3xl p-5">
            <div className="mb-3 flex h-10 w-10 items-center justify-center rounded-2xl bg-pink-500/15 text-pink-400">
              <Music size={20} />
            </div>
            <p className="text-3xl font-extrabold">{songs.length}</p>
            <p className="muted-text text-sm">{t.history.totalTracks}</p>
          </div>
          <div className="surface-card rounded-3xl p-5 md:col-span-2">
            <div className="mb-3 flex items-center gap-2 text-sm font-semibold uppercase tracking-[0.25em] text-cyan-400">
              <Clock size={18} />
              {t.history.latestListen}
            </div>
            <p className="text-xl font-bold">{latestListen}</p>
            <p className="muted-text mt-2 line-clamp-1 text-sm" dangerouslySetInnerHTML={{ __html: songs[0]?.title || t.history.emptyTitle }} />
          </div>
        </div>

        <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="text-sm font-semibold uppercase tracking-[0.28em] text-pink-400">
              {t.history.recentlyPlayed}
            </p>
            <h2 className="mt-1 text-2xl font-extrabold">{t.history.title}</h2>
          </div>
          <div className="surface-card rounded-2xl px-4 py-3 text-sm">
            <div className="flex items-center gap-2 font-semibold">
              <Sparkles size={16} className="text-pink-400" />
              {t.history.tipTitle}
            </div>
            <p className="muted-text mt-1">{t.history.tipDescription}</p>
          </div>
        </div>

        {songs.length === 0 ? (
          <div className="surface-card mt-6 rounded-3xl p-10 text-center">
            <p className="mb-2 text-xl font-bold text-pink-400">{t.history.emptyTitle}</p>
            <p className="muted-text">{t.history.emptyDescription}</p>
          </div>
        ) : (
          <div className="mt-6 flex flex-col gap-4">
            {songs.map((song, index) => (
              <SongCard key={`${song.id}-${song.listenedAt}-${index}`} song={song} playlist={songs} />
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
