"use client";

import { Eye, Sparkles } from 'lucide-react';
import Image from 'next/image';
import { formatViewCount, getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore } from '@/lib/store';

function HorizontalSongRow({ songs, playlist }) {
  const { setCurrentSong, setViewingSong, setPlaylist } = useMusicStore();

  const activateSong = (song) => {
    setViewingSong(song);
    setPlaylist(playlist);
  };

  const playSong = (song) => {
    setCurrentSong(song);
    setPlaylist(playlist);
  };

  return (
    <div className="scrollbar-hide flex gap-4 overflow-x-auto pb-2" style={{ cursor: 'grab' }}>
      {songs.map((song) => (
        <article
          key={song.id}
          onClick={() => activateSong(song)}
          onDoubleClick={() => playSong(song)}
          className="horizontal-song-card group flex-shrink-0 cursor-pointer select-none"
        >
          <div className="horizontal-song-thumb">
            {song.thumbnail && (
              <Image
                src={song.thumbnail}
                alt=""
                fill
                sizes="160px"
                className="object-cover transition-transform duration-300 group-hover:scale-110"
              />
            )}
            <div className="absolute inset-0 bg-black/40 opacity-0 transition-opacity group-hover:opacity-100" />
          </div>
          <div className="horizontal-song-info">
            <h3
              className="horizontal-song-title"
              dangerouslySetInnerHTML={{ __html: song.title }}
            />
            <p className="horizontal-song-meta">
              {song.artist}
              {song.viewCount ? ` · ${formatViewCount(song.viewCount, 'vi')}` : ''}
            </p>
          </div>
        </article>
      ))}
    </div>
  );
}

export default function DualViewSection({ mostViewedSongs, newestSongs }) {
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  return (
    <div className="flex flex-col gap-8">
      {/* Most Viewed Section — horizontal scroll */}
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
          <HorizontalSongRow songs={mostViewedSongs} playlist={mostViewedSongs} />
        )}
      </section>

      {/* Newest Section — horizontal scroll */}
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
          <HorizontalSongRow songs={newestSongs} playlist={newestSongs} />
        )}
      </section>
    </div>
  );
}
