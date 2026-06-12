"use client";

import Image from 'next/image';
import { formatDate, formatDateTime, formatViewCount, getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore } from '@/lib/store';

export default function SongCard({ song, playlist }) {
  const { setCurrentSong, setViewingSong, setPlaylist } = useMusicStore();
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);
  const hasHistoryMeta = Boolean(song.listenedAt);
  const viewText = formatViewCount(song.viewCount, language);
  const artistName = song.artist || t.common.unknownArtist;
  const primaryMeta = hasHistoryMeta
    ? `${t.history.listenedAt}: ${formatDateTime(song.listenedAt, language)}`
    : viewText
      ? `${viewText} · ${artistName}`
      : artistName;
  const secondaryMeta = hasHistoryMeta && song.artist
    ? (viewText ? `${viewText} · ${song.artist}` : song.artist)
    : song.publishedAt
      ? `${t.modal.releaseDate}: ${formatDate(song.publishedAt, language)}`
      : '';

  const activateSong = () => {
    setViewingSong(song);
    setPlaylist(playlist);
  };

  const playSong = () => {
    setCurrentSong(song);
    setPlaylist(playlist);
  };

  return (
    <article
      onClick={activateSong}
      onDoubleClick={playSong}
      className="surface-card surface-card-hover group relative cursor-pointer select-none overflow-hidden rounded-3xl p-4 sm:p-5"
    >
      <div className="pointer-events-none absolute inset-0 bg-gradient-to-r from-pink-500/10 via-transparent to-cyan-500/10 opacity-0 transition-opacity group-hover:opacity-100" />

      <div className="relative z-10 flex items-center gap-5 sm:gap-6">
        <div className="relative h-24 w-40 flex-shrink-0 overflow-hidden rounded-2xl bg-[var(--surface-strong)] shadow-lg sm:h-32 sm:w-56">
          {song.thumbnail && (
            <Image
              src={song.thumbnail}
              alt=""
              fill
              sizes="(max-width: 640px) 160px, 224px"
              className="object-cover"
            />
          )}
          <div className="absolute inset-0 bg-black/45 opacity-0 transition-opacity group-hover:opacity-100" />
        </div>

        <div className="flex min-w-0 flex-1 flex-col justify-center">
          <h3
            className="line-clamp-2 text-lg font-bold text-[var(--app-text)] transition-colors group-hover:text-pink-400 sm:text-xl"
            dangerouslySetInnerHTML={{ __html: song.title }}
          />
          <p className="muted-text mt-2 text-sm sm:text-base">{primaryMeta}</p>
          {secondaryMeta && (
            <p className="mt-1 truncate text-xs font-medium text-pink-400/90 sm:text-sm">{secondaryMeta}</p>
          )}
        </div>
      </div>
    </article>
  );
}
