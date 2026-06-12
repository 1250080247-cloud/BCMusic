"use client";

import { Eye, Sparkles } from 'lucide-react';
import SongCard from '@/components/SongCard';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

export default function DualViewSection({ mostViewedSongs, newestSongs }) {
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  return (
    <div className="flex flex-col gap-10">
      {/* Most Viewed Section */}
      <section>
        <div className="mb-4 flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-orange-500/15 text-orange-400">
            <Eye size={18} />
          </div>
          <h2 className="section-header text-lg font-extrabold sm:text-xl">
            {t.dualView.mostViewed}
          </h2>
        </div>

        {mostViewedSongs.length === 0 ? (
          <div className="surface-card rounded-3xl p-8 text-center">
            <p className="muted-text text-sm">{t.home.noSongsDescription}</p>
          </div>
        ) : (
          <div className="flex flex-col gap-4">
            {mostViewedSongs.map((song) => (
              <SongCard key={`mv-${song.id}`} song={song} playlist={mostViewedSongs} />
            ))}
          </div>
        )}
      </section>

      {/* Newest Section */}
      <section>
        <div className="mb-4 flex items-center gap-3">
          <div className="flex h-9 w-9 items-center justify-center rounded-xl bg-emerald-500/15 text-emerald-400">
            <Sparkles size={18} />
          </div>
          <h2 className="section-header text-lg font-extrabold sm:text-xl">
            {t.dualView.newest}
          </h2>
        </div>

        {newestSongs.length === 0 ? (
          <div className="surface-card rounded-3xl p-8 text-center">
            <p className="muted-text text-sm">{t.home.noSongsDescription}</p>
          </div>
        ) : (
          <div className="flex flex-col gap-4">
            {newestSongs.map((song) => (
              <SongCard key={`nw-${song.id}`} song={song} playlist={newestSongs} />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
