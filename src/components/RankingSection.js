'use client';

import { useEffect, useState } from 'react';
import { Crown } from 'lucide-react';
import DiscoverySongCard from '@/components/DiscoverySongCard';
import SongCarousel from '@/components/SongCarousel';
import MusicRowSkeleton from '@/components/MusicRowSkeleton';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

export default function RankingSection({ songs, genreKey, isLoading = false, unavailable = false }) {
  const [mounted, setMounted] = useState(false);
  const storeLanguage = useSettingsStore(state => state.language);
  const language = mounted ? storeLanguage : 'vi';
  useEffect(() => { setMounted(true); }, []);

  const t = getDictionary(language);
  const genre = genreKey ? t.home.categories[genreKey] : '';
  if (!songs) return null;
  return (
    <section
      {...(mounted && !isLoading ? { 'data-motion-section': '' } : {})}
      aria-busy={isLoading}
      className="discovery-ranking mx-auto mb-8 px-4 sm:px-8 max-w-[80rem]"
      style={{ maxWidth: '80rem' }}
    >
      <SongCarousel
        title={t.ranking.title}
        genre={genre}
        language={language}
        icon={<Crown size={20} />}
        isLoading={isLoading}
        subtitle={genre ? (language === 'vi' ? 'Những bản nhạc nổi bật của ' + genre : 'Popular tracks for ' + genre) : t.ranking.subtitle}
        animationKey={songs.map(song => song.id).join('|')}
      >
        {isLoading ? (
          <>
            <span className="sr-only" role="status">{language === 'vi' ? 'Đang tải nhạc…' : 'Loading music…'}</span>
            <MusicRowSkeleton count={6} />
          </>
        ) : songs.length ? (
          songs.map((song, index) => <DiscoverySongCard key={song.id} song={song} playlist={songs} rank={index + 1} />)
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
