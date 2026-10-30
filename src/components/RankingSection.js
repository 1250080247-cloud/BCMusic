'use client';

import { Crown } from 'lucide-react';
import DiscoverySongCard from '@/components/DiscoverySongCard';
import SongCarousel from '@/components/SongCarousel';
import MusicRowSkeleton from '@/components/MusicRowSkeleton';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

export default function RankingSection({ songs, genreKey, isLoading = false }) {
  const language = useSettingsStore(state => state.language);
  const t = getDictionary(language);
  const genre = genreKey ? t.home.categories[genreKey] : '';
  if (!songs) return null;
  return (
    <section data-motion-section aria-busy={isLoading} className="discovery-ranking mx-auto mb-8 px-4 sm:px-8" style={{ maxWidth: '80rem' }}>
      <SongCarousel title={t.ranking.title} genre={genre} language={language} icon={<Crown size={20} />} isLoading={isLoading}
        subtitle={genre ? (language === 'vi' ? 'Những bản nhạc nổi bật của ' + genre : 'Popular tracks for ' + genre) : t.ranking.subtitle}
        animationKey={songs.map(song => song.id).join('|')}>
        {isLoading ? <><span className="sr-only" role="status">{language === 'vi' ? 'Đang tải nhạc…' : 'Loading music…'}</span><MusicRowSkeleton count={6} /></> : songs.length ?
          songs.map((song, index) => <DiscoverySongCard key={song.id} song={song} playlist={songs} rank={index + 1} />) : <p className="discovery-empty">{t.home.noSongsDescription}</p>}
      </SongCarousel>
    </section>
  );
}
