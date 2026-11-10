'use client';

import { useEffect, useState } from 'react';
import { Eye, Sparkles } from 'lucide-react';
import DiscoverySongCard from '@/components/DiscoverySongCard';
import SongCarousel from '@/components/SongCarousel';
import MusicRowSkeleton from '@/components/MusicRowSkeleton';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

export function SongRowSection({ songs, genreKey, kind, isLoading = false, unavailable = false }) {
  const [mounted, setMounted] = useState(false);
  const storeLanguage = useSettingsStore(state => state.language);
  const language = mounted ? storeLanguage : 'vi';
  useEffect(() => { setMounted(true); }, []);

  const t = getDictionary(language);
  const genre = genreKey ? t.home.categories[genreKey] : '';
  const mostViewed = kind === 'mostViewed';
  return (
    <section {...(mounted && !isLoading ? { 'data-motion-section': '' } : {})} aria-busy={isLoading}>
      <SongCarousel
        title={mostViewed ? t.dualView.mostViewed : t.dualView.newest}
        genre={genre}
        language={language}
        icon={mostViewed ? <Eye size={20} /> : <Sparkles size={20} />}
        isLoading={isLoading}
        animationKey={songs.map(song => song.id).join('|')}
      >
        {isLoading ? (
          <>
            <span className="sr-only" role="status">{language === 'vi' ? 'Đang tải nhạc…' : 'Loading music…'}</span>
            <MusicRowSkeleton />
          </>
        ) : songs.length ? (
          songs.map(song => <DiscoverySongCard key={song.id} song={song} playlist={songs} />)
        ) : (
          <p className="discovery-empty">
            {unavailable
              ? (language === 'vi' ? 'Tạm thời không kết nối được nguồn nhạc. Vui lòng thử lại sau.' : 'Music source temporarily unavailable. Please try again later.')
              : t.home.noSongsDescription}
          </p>
        )}
      </SongCarousel>
    </section>
  );
}

export default function DualViewSection({ mostViewedSongs, newestSongs, genreKey, unavailable = false }) {
  return (
    <div className="flex flex-col gap-8">
      <SongRowSection songs={mostViewedSongs} genreKey={genreKey} kind="mostViewed" unavailable={unavailable} />
      <SongRowSection songs={newestSongs} genreKey={genreKey} kind="newest" unavailable={unavailable} />
    </div>
  );
}
