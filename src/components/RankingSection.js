"use client";

import { Crown } from 'lucide-react';
import Image from 'next/image';
import { getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore } from '@/lib/store';

export default function RankingSection({ songs }) {
  const { setCurrentSong, setViewingSong, setPlaylist } = useMusicStore();
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  if (!songs || songs.length === 0) return null;

  const activateSong = (song) => {
    setViewingSong(song);
    setPlaylist(songs);
  };

  const playSong = (song) => {
    setCurrentSong(song);
    setPlaylist(songs);
  };

  return (
    <section className="mx-auto mb-10 max-w-5xl px-4 sm:px-8">
      <div className="mb-5 flex items-center gap-3">
        <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-amber-500/15 text-amber-400">
          <Crown size={20} />
        </div>
        <div>
          <h2 className="text-xl font-extrabold sm:text-2xl">{t.ranking.title}</h2>
          <p className="muted-text text-sm">{t.ranking.subtitle}</p>
        </div>
      </div>

      <div className="scrollbar-hide flex gap-4 overflow-x-auto pb-4" style={{ cursor: 'grab' }}>
        {songs.map((song, index) => (
          <article
            key={song.id}
            onClick={() => activateSong(song)}
            onDoubleClick={() => playSong(song)}
            className="ranking-card group relative flex-shrink-0 cursor-pointer select-none overflow-hidden rounded-2xl"
            style={{ width: '180px' }}
          >
            <div className="relative aspect-square w-full overflow-hidden bg-[var(--surface-strong)]">
              {song.thumbnail && (
                <Image
                  src={song.thumbnail}
                  alt=""
                  fill
                  sizes="180px"
                  className="object-cover transition-transform duration-300 group-hover:scale-110"
                />
              )}
              <div className="absolute inset-0 bg-gradient-to-t from-black/70 via-black/20 to-transparent" />

              <div className="ranking-badge absolute left-2 top-2">
                <span className="text-sm font-extrabold">#{index + 1}</span>
              </div>
            </div>

            <div className="absolute bottom-0 left-0 right-0 p-3">
              <h3
                className="line-clamp-2 text-sm font-bold leading-tight text-white drop-shadow-lg"
                dangerouslySetInnerHTML={{ __html: song.title }}
              />
              <p className="mt-1 truncate text-xs font-medium text-white/70">
                {song.artist}
              </p>
            </div>
          </article>
        ))}
      </div>
    </section>
  );
}
