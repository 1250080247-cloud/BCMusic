"use client";

import { Eye, Loader2, Music2, Sparkles } from 'lucide-react';
import Image from 'next/image';
import { useState, useCallback } from 'react';
import { formatViewCount } from '@/lib/i18n';
import { useMusicStore } from '@/lib/store';

/* ── Data ─────────────────────────────────────────────── */
const MOODS = [
  { key: 'chill',    label: 'Chill',     query: 'chill music relaxing',     color: '#06b6d4' },
  { key: 'feelgood', label: 'Feel good', query: 'feel good happy music',    color: '#a78bfa' },
  { key: 'party',    label: 'Party',     query: 'party music dance hits',   color: '#f59e0b' },
  { key: 'sleep',    label: 'Sleep',     query: 'sleep music calm ambient', color: '#818cf8' },
  { key: 'commute',  label: 'Commute',   query: 'commute music energy',     color: '#f87171' },
  { key: 'focus',    label: 'Focus',     query: 'focus study music lofi',   color: '#34d399' },
  { key: 'romance',  label: 'Romance',   query: 'romantic love songs',      color: '#f472b6' },
  { key: 'workout',  label: 'Workout',   query: 'workout gym music',        color: '#fb923c' },
  { key: 'energize', label: 'Energize',  query: 'energizing upbeat music',  color: '#facc15' },
  { key: 'gaming',   label: 'Gaming',    query: 'gaming music epic',        color: '#4ade80' },
  { key: 'sad',      label: 'Sad',       query: 'sad emotional music',      color: '#94a3b8' },
];

const GENRES = [
  { key: 'african',    label: 'African',              query: 'african music hits',           color: '#f59e0b' },
  { key: 'bollywood',  label: 'Bollywood & Indian',   query: 'bollywood hindi songs',        color: '#f87171' },
  { key: 'dance',      label: 'Dance & Electronic',   query: 'dance electronic edm',         color: '#06b6d4' },
  { key: 'folk',       label: 'Folk & Acoustic',      query: 'folk acoustic guitar music',   color: '#a3e635' },
  { key: 'indonesian', label: 'Indonesian',           query: 'lagu indonesia hits',          color: '#4ade80' },
  { key: 'kpop',       label: 'K-Pop',                query: 'kpop hit songs',               color: '#f472b6' },
  { key: 'metal',      label: 'Metal',                query: 'heavy metal rock music',       color: '#94a3b8' },
  { key: 'reggae',     label: 'Reggae & Caribbean',   query: 'reggae caribbean music',       color: '#fbbf24' },
  { key: 'soundtrack', label: 'Soundtrack & Musical', query: 'movie soundtrack music',       color: '#a78bfa' },
  { key: 'arabic',     label: 'Arabic',               query: 'arabic music hits',            color: '#34d399' },
  { key: 'classical',  label: 'Classical',            query: 'classical music orchestra',    color: '#818cf8' },
  { key: 'decades',    label: 'Decades',              query: '80s 90s 2000s hits music',    color: '#fb923c' },
  { key: 'hiphop',     label: 'Hip-hop',              query: 'hip hop rap music',            color: '#facc15' },
  { key: 'jpop',       label: 'J-Pop',                query: 'jpop japanese music',          color: '#f9a8d4' },
  { key: 'latin',      label: 'Latin',                query: 'latin music salsa reggaeton',  color: '#f87171' },
  { key: 'pop',        label: 'Pop',                  query: 'pop music hits 2024',          color: '#06b6d4' },
  { key: 'rock',       label: 'Rock',                 query: 'rock music classic hits',      color: '#e2e8f0' },
  { key: 'thai',       label: 'Thai',                 query: 'thai music hits',              color: '#4ade80' },
  { key: 'blues',      label: 'Blues',                query: 'blues music soul',             color: '#818cf8' },
  { key: 'country',    label: 'Country & Americana',  query: 'country music americana',      color: '#f59e0b' },
  { key: 'family',     label: 'Family',               query: 'family kids music fun',        color: '#86efac' },
  { key: 'indie',      label: 'Indie & Alternative',  query: 'indie alternative music',      color: '#c4b5fd' },
  { key: 'jazz',       label: 'Jazz',                 query: 'jazz music smooth',            color: '#fcd34d' },
  { key: 'mandopop',   label: 'Mandopop & Cantopop',  query: 'mandopop cantopop hits',       color: '#f9a8d4' },
  { key: 'rnb',        label: 'R&B & Soul',           query: 'rnb soul music hits',          color: '#a78bfa' },
  { key: 'seasonal',   label: 'Seasonal',             query: 'seasonal holiday music',       color: '#6ee7b7' },
];

/* ── Pill button — box style with left colour bar ──────── */
function GenrePill({ item, isActive, onClick }) {
  const [hovered, setHovered] = useState(false);

  const base = {
    display: 'flex',
    alignItems: 'center',
    gap: '10px',
    padding: '10px 14px',
    borderRadius: '8px',
    border: `1px solid ${isActive ? item.color : 'rgba(148,163,184,0.18)'}`,
    background: isActive
      ? `${item.color}20`
      : hovered
        ? 'rgba(30,41,59,0.92)'
        : 'rgba(15,23,42,0.72)',
    color: isActive ? item.color : hovered ? '#f8fafc' : '#cbd5e1',
    fontSize: '0.82rem',
    fontWeight: 600,
    cursor: 'pointer',
    transition: 'all 150ms ease',
    textAlign: 'left',
    minWidth: 0,
    boxShadow: isActive ? `0 0 0 2px ${item.color}40` : 'none',
  };

  const bar = {
    width: '3px',
    height: '18px',
    borderRadius: '2px',
    flexShrink: 0,
    background: item.color,
    opacity: isActive || hovered ? 1 : 0.7,
  };

  return (
    <button
      type="button"
      onClick={() => onClick(item)}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={base}
    >
      <span style={bar} />
      <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
        {item.label}
      </span>
    </button>
  );
}

/* ── Song card inside results ─────────────────────────── */
function ExploreSongCard({ song, playlist }) {
  const { setCurrentSong, setViewingSong, setPlaylist } = useMusicStore();
  const [hovered, setHovered] = useState(false);

  return (
    <article
      onClick={() => { setViewingSong(song); setPlaylist(playlist); }}
      onDoubleClick={() => { setCurrentSong(song); setPlaylist(playlist); }}
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        display: 'flex',
        alignItems: 'center',
        gap: '10px',
        padding: '6px 8px',
        borderRadius: '10px',
        cursor: 'pointer',
        background: hovered ? 'rgba(51,65,85,0.8)' : 'transparent',
        transform: hovered ? 'translateX(3px)' : 'translateX(0)',
        transition: 'all 150ms ease',
      }}
    >
      {/* Thumbnail */}
      <div style={{
        position: 'relative', width: 48, height: 48,
        borderRadius: 8, overflow: 'hidden', flexShrink: 0,
        background: 'rgba(30,41,59,0.8)',
      }}>
        {song.thumbnail && (
          <Image src={song.thumbnail} alt="" fill sizes="48px" style={{ objectFit: 'cover' }} />
        )}
      </div>
      {/* Info */}
      <div style={{ minWidth: 0, flex: 1 }}>
        <p
          style={{
            fontSize: '0.78rem', fontWeight: 600, color: hovered ? '#ec4899' : '#f1f5f9',
            display: '-webkit-box', WebkitLineClamp: 2, WebkitBoxOrient: 'vertical',
            overflow: 'hidden', lineHeight: 1.3, transition: 'color 150ms ease',
            margin: 0,
          }}
          dangerouslySetInnerHTML={{ __html: song.title }}
        />
        <p style={{ fontSize: '0.68rem', color: '#94a3b8', marginTop: 2, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
          {song.artist}{song.viewCount ? ` · ${formatViewCount(song.viewCount, 'vi')}` : ''}
        </p>
      </div>
    </article>
  );
}

/* ── Results panel ────────────────────────────────────── */
function ExploreResults({ selected, songs, newestSongs, loading }) {
  if (!selected) return null;

  return (
    <div style={{
      marginTop: '1rem',
      background: 'rgba(15,23,42,0.72)',
      border: '1px solid rgba(148,163,184,0.16)',
      borderRadius: '16px',
      overflow: 'hidden',
      animation: 'ge-fadein 250ms ease',
    }}>
      {/* Header */}
      <div style={{
        display: 'flex', alignItems: 'center', gap: 8,
        padding: '14px 20px 12px',
        borderBottom: '1px solid rgba(148,163,184,0.12)',
      }}>
        <Music2 size={16} style={{ color: '#ec4899', flexShrink: 0 }} />
        <span style={{ fontSize: '0.85rem', fontWeight: 600, color: '#f1f5f9' }}>
          Nhạc theo thể loại:{' '}
          <strong style={{ color: selected.color }}>{selected.label}</strong>
        </span>
      </div>

      {loading ? (
        <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 10, padding: '2.5rem', color: '#94a3b8', fontSize: '0.875rem' }}>
          <Loader2 size={24} style={{ animation: 'spin 1s linear infinite', color: '#ec4899' }} />
          Đang tải nhạc...
        </div>
      ) : (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr' }}>
          {/* Most viewed */}
          <div style={{ padding: '14px 16px 18px', borderRight: '1px solid rgba(148,163,184,0.12)' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 12, fontSize: '0.78rem', fontWeight: 700, color: '#f97316' }}>
              <Eye size={14} />🔥 Xem nhiều nhất
            </div>
            {songs.length === 0
              ? <p style={{ fontSize: '0.8rem', color: '#64748b' }}>Không có kết quả</p>
              : songs.map(s => <ExploreSongCard key={s.id} song={s} playlist={songs} />)
            }
          </div>
          {/* Newest */}
          <div style={{ padding: '14px 16px 18px' }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginBottom: 12, fontSize: '0.78rem', fontWeight: 700, color: '#10b981' }}>
              <Sparkles size={14} />✨ Mới nhất
            </div>
            {newestSongs.length === 0
              ? <p style={{ fontSize: '0.8rem', color: '#64748b' }}>Không có kết quả</p>
              : newestSongs.map(s => <ExploreSongCard key={s.id} song={s} playlist={newestSongs} />)
            }
          </div>
        </div>
      )}
    </div>
  );
}

/* ── Main component ───────────────────────────────────── */
export default function GenreExplorer() {
  const [selected, setSelected] = useState(null);
  const [songs, setSongs] = useState([]);
  const [newestSongs, setNewestSongs] = useState([]);
  const [loading, setLoading] = useState(false);

  const handleSelect = useCallback(async (item) => {
    if (selected?.key === item.key) {
      setSelected(null); setSongs([]); setNewestSongs([]);
      return;
    }
    setSelected(item); setSongs([]); setNewestSongs([]); setLoading(true);
    try {
      const [vRes, nRes] = await Promise.all([
        fetch(`/api/explore?q=${encodeURIComponent(item.query)}&order=viewCount`),
        fetch(`/api/explore?q=${encodeURIComponent(item.query)}&order=date`),
      ]);
      const [vData, nData] = await Promise.all([vRes.json(), nRes.json()]);
      setSongs(vData.items || []);
      setNewestSongs(nData.items || []);
    } catch {
      setSongs([]); setNewestSongs([]);
    } finally {
      setLoading(false);
    }
  }, [selected]);

  const section = {
    maxWidth: '80rem', margin: '0 auto',
    padding: '0 1.5rem 2.5rem',
  };
  const divider = {
    height: 1, background: 'rgba(148,163,184,0.16)',
    margin: '2rem 0',
  };
  const eyebrow = {
    fontSize: '0.65rem', fontWeight: 700,
    letterSpacing: '0.18em', textTransform: 'uppercase',
    color: '#64748b', marginBottom: '1rem',
  };
  const groupTitle = {
    fontSize: '1.1rem', fontWeight: 800,
    color: '#f1f5f9', marginBottom: '0.85rem', lineHeight: 1.2,
  };
  const grid = {
    display: 'grid',
    gridTemplateColumns: 'repeat(auto-fill, minmax(140px, 1fr))',
    gap: '8px',
  };

  return (
    <>
      <style>{`
        @keyframes ge-fadein {
          from { opacity: 0; transform: translateY(8px); }
          to   { opacity: 1; transform: translateY(0); }
        }
        @keyframes spin {
          from { transform: rotate(0deg); }
          to   { transform: rotate(360deg); }
        }
      `}</style>

      <section style={section}>
        <div style={divider} />

        {/* Eyebrow */}
        <p style={eyebrow}>LET&apos;S PICK A PLAYLIST FOR YOU</p>

        {/* Moods */}
        <div style={{ marginBottom: '1.75rem' }}>
          <h2 style={groupTitle}>Moods &amp; Moment</h2>
          <div style={grid}>
            {MOODS.map(item => (
              <GenrePill
                key={item.key}
                item={item}
                isActive={selected?.key === item.key}
                onClick={handleSelect}
              />
            ))}
          </div>
        </div>

        {/* Genre */}
        <div style={{ marginBottom: '1.25rem' }}>
          <h2 style={groupTitle}>Genre</h2>
          <div style={grid}>
            {GENRES.map(item => (
              <GenrePill
                key={item.key}
                item={item}
                isActive={selected?.key === item.key}
                onClick={handleSelect}
              />
            ))}
          </div>
        </div>

        {/* Results */}
        <ExploreResults
          selected={selected}
          songs={songs}
          newestSongs={newestSongs}
          loading={loading}
        />

        {/* Footer */}
        <footer style={{
          marginTop: '2rem',
          paddingTop: '1.25rem',
          borderTop: '1px solid rgba(148,163,184,0.16)',
          textAlign: 'center',
        }}>
          <span style={{
            fontSize: '0.75rem', fontWeight: 500,
            background: 'linear-gradient(90deg, #ec4899, #06b6d4)',
            WebkitBackgroundClip: 'text',
            WebkitTextFillColor: 'transparent',
            backgroundClip: 'text',
            letterSpacing: '0.03em',
          }}>
            @2026 BCMusic · Made by ThanhDat
          </span>
        </footer>
      </section>
    </>
  );
}
