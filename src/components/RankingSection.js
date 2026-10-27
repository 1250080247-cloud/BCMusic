"use client";

import MotionList from '@/components/MotionList';

import { decodeSongTitle } from '@/lib/song-title';

import { Crown } from 'lucide-react';
import Image from 'next/image';
import { formatViewCount, getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore } from '@/lib/store';

export default function RankingSection({ songs, genreKey }) {
  const { startPlayback, setViewingSong } = useMusicStore();
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);
  const genre = genreKey ? t.home.categories[genreKey] : '';

  if (!songs) return null;

  const activateSong = (song) => {
    setViewingSong(song, songs);
  };

  const playSong = (song) => {
    startPlayback(song, songs);
  };

  return (
    <section data-motion-section className="mx-auto mb-8 px-4 sm:px-8" style={{ maxWidth: '80rem' }}>
      <div className="mb-5 flex items-center gap-3">
        <div className="flex h-10 w-10 items-center justify-center rounded-2xl bg-amber-500/15 text-amber-400">
          <Crown size={20} />
        </div>
        <div>
          <h2 className="text-xl font-extrabold sm:text-2xl">{t.ranking.title}{genre && <span className="text-sm font-medium opacity-60"> · {genre}</span>}</h2>
          <p className="muted-text text-sm">{genre ? (language === 'vi' ? `Những bản nhạc nổi bật của ${genre}` : `Popular tracks for ${genre}`) : t.ranking.subtitle}</p>
        </div>
      </div>

      {songs.length === 0 && <p className="surface-card rounded-3xl p-8 muted-text text-sm">{t.home.noSongsDescription}</p>}
      <MotionList animationKey={songs.map((item) => item.id).join('|')} className="scrollbar-hide flex gap-4 overflow-x-auto pb-2" style={{ cursor: 'grab' }}>
        {songs.map((song, index) => (
          <article
            key={song.id}
            onClick={() => activateSong(song)}
            onDoubleClick={() => playSong(song)}
            className="horizontal-song-card group cursor-pointer select-none"
          >
            <div className="horizontal-song-thumb">
              {song.thumbnail && (
                <Image
                  src={song.thumbnail}
                  alt=""
                  fill
                  sizes="180px"
                  priority={index < 3}
                  className="object-cover transition-transform duration-300 group-hover:scale-110"
                />
              )}
              <div className="absolute inset-0 bg-black/40 opacity-0 transition-opacity group-hover:opacity-100" />

              {/* Ranking badge */}
              <div className="ranking-badge absolute left-2 top-2">
                <span className="text-sm font-extrabold">#{index + 1}</span>
              </div>
            </div>
            <div className="horizontal-song-info">
              <h3
                className="horizontal-song-title">{decodeSongTitle(song.title)}</h3>
              <p className="horizontal-song-meta">
                {song.artist}
                {song.viewCount ? ` · ${formatViewCount(song.viewCount, language)}` : ''}
              </p>
            </div>
          </article>
        ))}
      </MotionList>
    </section>
  );
}
