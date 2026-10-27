"use client";
import { useEffect, useState } from "react";
import Image from "next/image";
import { Loader2, Music2, Radio } from "lucide-react";
import { useMusicStore } from "@/lib/store";
import { decodeSongTitle } from "@/lib/song-title";
import { formatDate } from "@/lib/i18n";

function SimilarSongs({ currentSong }) {
  const [result, setResult] = useState(null);
  const songs = result && result.songId === currentSong?.id ? result.songs : [];
  const loading = Boolean(currentSong?.id && result?.songId !== currentSong.id);
  const { startPlayback, setViewingSong } = useMusicStore();

  useEffect(() => {
    if (!currentSong?.id) return;
    const controller = new AbortController();

    const rawTitle = currentSong.title?.replace(/<[^>]*>/g, '') || '';
    const titleWords = rawTitle.split(/[\s\-–|]+/).slice(0, 4).join(' ');
    const artist = currentSong.artist || '';
    const query = artist ? `${artist} ${titleWords}` : titleWords;

    fetch(`/api/explore?q=${encodeURIComponent(query)}&order=relevance`, { signal: controller.signal })
      .then(r => r.json())
      .then(data => {
        const filtered = (data.items || []).filter(s => s.id !== currentSong.id);
        if (!controller.signal.aborted) setResult({ songId: currentSong.id, songs: filtered.slice(0, 6) });
      })
      .catch(() => {
        if (!controller.signal.aborted) setResult({ songId: currentSong.id, songs: [] });
      });
    return () => controller.abort();
  }, [currentSong?.id, currentSong?.title, currentSong?.artist]);

  if (!loading && songs.length === 0) return null;

  return (
    <div className="np-similar-section">
      <div className="np-similar-header">
        <Radio size={14} className="np-similar-icon" />
        <span>Gợi ý tương tự</span>
      </div>

      {loading ? (
        <div className="np-similar-loading">
          <Loader2 size={18} className="np-similar-spinner" />
          <span>Đang tìm bản nhạc phù hợp...</span>
        </div>
      ) : (
        <div className="np-similar-list">
          {songs.map((song) => (
            <button
              key={song.id}
              type="button"
              className="np-similar-item"
              onClick={() => { setViewingSong(song, songs); }}
              onDoubleClick={() => { startPlayback(song, songs); }}
              title="Click xem chi tiết · Double click phát ngay"
            >
              <div className="np-similar-thumb">
                {song.thumbnail && (
                  <Image src={song.thumbnail} alt="" fill sizes="44px" className="object-cover" />
                )}
                <div className="np-similar-thumb-overlay">
                  <Music2 size={14} />
                </div>
              </div>
              <div className="np-similar-info">
                <p className="np-similar-title">{decodeSongTitle(song.title)}</p>
                <p className="np-similar-artist">{song.artist}</p>
              </div>
            </button>
          ))}
        </div>
      )}
    </div>
  );
}


function SongStats({ song, language }) {
  if (!song) return null;
  const isSoundCloud = song.source === 'soundcloud';

  return (
    <div className="np-stats-section">
      <div className="np-info-section-header">
        <span className="np-info-section-label">
          {language === 'vi' ? 'Thông tin' : 'Info'}
        </span>
      </div>
      <div className="np-stats-grid">
        {song.publishedAt && (
          <div className="np-stats-item">
            <span className="np-stats-item-label">
              {language === 'vi' ? 'Phát hành' : 'Released'}
            </span>
            <span className="np-stats-item-value">
              {formatDate(song.publishedAt, language)}
            </span>
          </div>
        )}
        <div className="np-stats-item">
          <span className="np-stats-item-label">
            {language === 'vi' ? 'Nguồn' : 'Source'}
          </span>
          <span className={`np-track-badge ${isSoundCloud ? 'np-track-badge--sc' : 'np-track-badge--yt'}`}>
            {isSoundCloud ? 'SoundCloud' : 'YouTube'}
          </span>
        </div>
        {song.id && !isSoundCloud && (
          <div className="np-stats-item">
            <span className="np-stats-item-label">Video ID</span>
            <a
              href={`https://youtube.com/watch?v=${song.id}`}
              target="_blank"
              rel="noopener noreferrer"
              className="np-stats-link"
            >
              {song.id}
            </a>
          </div>
        )}
      </div>
    </div>
  );
}


export default function NowPlayingDetails({ song, language }) {
  return <div className="focus-details"><SongStats song={song} language={language} /><SimilarSongs currentSong={song} /></div>;
}
