'use client';

import Image from 'next/image';
import { Music2, Play } from 'lucide-react';
import { decodeSongTitle } from '@/lib/song-title';
import { formatViewCount, getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore } from '@/lib/store';

export default function DiscoverySongCard({ song, playlist, rank }) {
  const startPlayback = useMusicStore(state => state.startPlayback);
  const setViewingSong = useMusicStore(state => state.setViewingSong);
  const currentId = useMusicStore(state => state.currentSong?.id);
  const language = useSettingsStore(state => state.language);
  const title = decodeSongTitle(song.title);
  const vi = language === 'vi';
  const selected = currentId === song.id;
  const play = () => startPlayback(song, playlist);
  return (
    <article className={`discovery-card${selected ? ' is-current' : ''}`}>
      <button type="button" className="discovery-card-main" aria-label={`${vi ? 'Xem bài hát' : 'Track details'}: ${title}`} onClick={() => setViewingSong(song, playlist)} onDoubleClick={play}>
        <span className="discovery-artwork">
          {song.thumbnail ? <Image src={song.thumbnail} alt="" fill sizes="(max-width: 640px) 152px, 192px" draggable={false} className="discovery-artwork-image" /> : <Music2 size={40} aria-hidden="true" />}
          {rank && <span className="discovery-rank">{String(rank).padStart(2, '0')}</span>}
          {selected && <span className="discovery-current-label">{vi ? 'Đã chọn' : 'Selected'}</span>}
        </span>
        <span className="discovery-card-title">{title}</span>
        <span className="discovery-card-artist">{song.artist || getDictionary(language).common.unknownArtist}</span>
        {song.viewCount && <span className="discovery-card-views">{formatViewCount(song.viewCount, language)}</span>}
      </button>
      <button type="button" className="discovery-card-play" aria-label={`${vi ? 'Phát' : 'Play'}: ${title}`} onClick={play}><Play size={19} fill="currentColor" aria-hidden="true" /></button>
    </article>
  );
}
