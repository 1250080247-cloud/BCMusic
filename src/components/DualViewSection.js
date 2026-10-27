"use client";

import MotionList from '@/components/MotionList';
import MusicRowSkeleton from '@/components/MusicRowSkeleton';

import { decodeSongTitle } from '@/lib/song-title';

import { Eye, Sparkles } from 'lucide-react';
import Image from 'next/image';
import { formatViewCount, getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore } from '@/lib/store';

function HorizontalSongRow({ songs, playlist }) {
  const { startPlayback, setViewingSong } = useMusicStore();

  const activateSong = (song) => {
    setViewingSong(song, playlist);
  };

  const playSong = (song) => {
    startPlayback(song, playlist);
  };

  return (
    <MotionList animationKey={songs.map((item) => item.id).join('|')} className="scrollbar-hide flex gap-4 overflow-x-auto pb-2" style={{ cursor: 'grab' }}>
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
              className="horizontal-song-title">{decodeSongTitle(song.title)}</h3>
            <p className="horizontal-song-meta">
              {song.artist}
              {song.viewCount ? ` · ${formatViewCount(song.viewCount, 'vi')}` : ''}
            </p>
          </div>
        </article>
      ))}
    </MotionList>
  );
}

export function SongRowSection({ songs, genreKey, kind, isLoading = false }) {
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);
  const genre = genreKey ? t.home.categories[genreKey] : '';
  const mostViewed = kind === 'mostViewed';
  return (
      <section data-motion-section aria-busy={isLoading}>
        <div className="mb-4 flex items-center gap-3">
          <div className={`flex h-9 w-9 items-center justify-center rounded-xl ${mostViewed ? 'bg-orange-500/15 text-orange-400' : 'bg-emerald-500/15 text-emerald-400'}`}>
            {mostViewed ? <Eye size={18} /> : <Sparkles size={18} />}
          </div>
          <h2 className="section-header text-lg font-extrabold sm:text-xl">
            {mostViewed ? t.dualView.mostViewed : t.dualView.newest}
            {genre && <span className="text-sm font-medium opacity-60"> · {genre}</span>}
          </h2>
        </div>

        {isLoading ? <><p className="sr-only" role="status">{language === 'vi' ? 'Đang tải nhạc…' : 'Loading music…'}</p><MusicRowSkeleton /></> : songs.length === 0 ? (
          <div className="surface-card rounded-3xl p-8 text-center">
            <p className="muted-text text-sm">{t.home.noSongsDescription}</p>
          </div>
        ) : (
          <HorizontalSongRow songs={songs} playlist={songs} />
        )}
      </section>
  );
}

export default function DualViewSection({ mostViewedSongs, newestSongs, genreKey }) {
  return <div className="flex flex-col gap-8">
    <SongRowSection songs={mostViewedSongs} genreKey={genreKey} kind="mostViewed" />
    <SongRowSection songs={newestSongs} genreKey={genreKey} kind="newest" />
  </div>;
}
