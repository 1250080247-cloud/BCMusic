"use client";

import { useEffect, useMemo, useRef, useState } from 'react';
import { AudioLines, Loader2, RefreshCw } from 'lucide-react';
import { activeLineAt, lyricsMetadata } from '@/lib/lyrics';

const messages = {
  vi: { title: 'Lời bài hát', loading: 'Đang tìm lời bài hát…', unavailable: 'Chưa tìm thấy lời phù hợp', hint: 'Lời sẽ xuất hiện ở đây khi có bản khớp với bài đang phát.', error: 'Chưa kết nối được nguồn lời', retry: 'Thử lại', instrumental: 'Thả mình vào giai điệu.', instrumentalHint: 'Bản nhạc này không có lời.', synced: 'Đồng bộ theo dòng', plain: 'Lời chưa có thời gian đồng bộ', follow: 'Theo dõi lời', interlude: 'Nhạc dạo', seek: 'Phát từ câu này' },
  en: { title: 'Lyrics', loading: 'Finding the lyrics…', unavailable: 'No matching lyrics yet', hint: 'Lyrics will appear here when a matching recording is available.', error: 'Lyrics are temporarily unavailable', retry: 'Try again', instrumental: 'Just you and the music.', instrumentalHint: 'This recording is instrumental.', synced: 'Line-synced lyrics', plain: 'Lyrics without timing', follow: 'Follow lyrics', interlude: 'Instrumental', seek: 'Play from this line' },
};
const providerLinks = new Map([['LRCLIB', 'https://lrclib.net'], ['lyrics.ovh', 'https://lyrics.ovh']]);

export default function LyricsPanel({ song, duration, currentTime, language }) {
  const copy = messages[language] || messages.en;
  const metadata = useMemo(() => lyricsMetadata(song, duration), [song, duration]);
  const [response, setResponse] = useState(null);
  const [retry, setRetry] = useState(0);
  const [follow, setFollow] = useState(true);
  const active = useRef(null);
  const scroll = useRef(null);
  const key = JSON.stringify([song?.id, metadata.title, metadata.artist, metadata.duration, retry]);
  const canLookup = Boolean(metadata.title && metadata.artist);
  const result = response?.key === key ? response.data : null;
  const fallback = typeof song?.lyrics === 'string' && song.lyrics.trim()
    ? { status: 'plain', plainLyrics: song.lyrics, lines: [], source: null } : null;
  const data = result?.status === 'synced' || result?.status === 'instrumental' || result?.plainLyrics
    ? result : fallback || result;
  const lines = data?.status === 'synced' ? data.lines : [];
  const activeIndex = activeLineAt(lines, currentTime);
  const loading = canLookup && !result;
  const sourceUrl = providerLinks.get(data?.source);

  useEffect(() => {
    if (!canLookup) return;
    const controller = new AbortController();
    const parameters = new URLSearchParams({ title: metadata.title, artist: metadata.artist, duration: String(metadata.duration) });
    fetch(`/api/lyrics?${parameters}`, { signal: controller.signal })
      .then(async res => {
        if (!res.ok) throw new Error('lyrics_unavailable');
        return res.json();
      })
      .then(value => {
        if (!controller.signal.aborted) setResponse({ key, data: value });
      })
      .catch(() => {
        if (!controller.signal.aborted) setResponse({ key, data: { status: 'error', lines: [] } });
      });
    return () => controller.abort();
  }, [key, canLookup, metadata.title, metadata.artist, metadata.duration]);

  useEffect(() => {
    if (!follow || !active.current || !scroll.current || activeIndex < 0) return;
    const reduced = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    const line = active.current.getBoundingClientRect();
    const container = scroll.current.getBoundingClientRect();
    scroll.current.scrollTo({ top: scroll.current.scrollTop + line.top - container.top - (container.height - line.height) / 2, behavior: reduced ? 'instant' : 'smooth' });
  }, [activeIndex, follow]);

  return (
    <section className="focus-lyrics" aria-label={copy.title}>
      <header className="focus-lyrics-heading">
        <div>
          <h2>{copy.title}</h2>
          {sourceUrl && <a href={sourceUrl} target="_blank" rel="noopener noreferrer">{data.source}</a>}
        </div>
        {lines.length > 0 && <button type="button" className="focus-pill" aria-pressed={follow} onClick={() => setFollow(value => !value)}>{copy.follow}</button>}
      </header>

      <div ref={scroll} className="focus-lyrics-scroll" tabIndex={0} aria-label={copy.title} onWheel={() => setFollow(false)} onTouchStart={() => setFollow(false)}>
        {lines.length > 0 ? (
          <div className="focus-lyrics-lines">
            {lines.map((line, index) => (
              <button key={`${line.time}-${index}`} type="button"
                ref={index === activeIndex ? active : null}
                className={`focus-lyric-line${index === activeIndex ? ' focus-lyric-line--active' : ''}`}
                aria-current={index === activeIndex ? 'true' : undefined}
                title={copy.seek}
                onFocus={() => setFollow(false)}
                onClick={() => window.dispatchEvent(new CustomEvent('bcmusic:seekto', { detail: { time: line.time } }))}>
                {line.text || <span className="focus-interlude">{copy.interlude}</span>}
              </button>
            ))}
          </div>
        ) : data?.plainLyrics ? (
          <div className="focus-plain-lyrics">{data.plainLyrics}</div>
        ) : (
          <div className="focus-lyrics-empty" role="status">
            {loading ? <Loader2 size={30} className="focus-loading-icon" /> : <AudioLines size={34} strokeWidth={1.3} />}
            <h3>{loading ? copy.loading : data?.status === 'instrumental' ? copy.instrumental : data?.status === 'error' ? copy.error : copy.unavailable}</h3>
            <p>{data?.status === 'instrumental' ? copy.instrumentalHint : copy.hint}</p>
            {data?.status === 'error' && <button type="button" className="focus-pill" onClick={() => setRetry(value => value + 1)}><RefreshCw size={14} />{copy.retry}</button>}
          </div>
        )}
      </div>
      <p className="focus-lyrics-caption">{lines.length ? copy.synced : data?.plainLyrics ? copy.plain : ''}</p>
    </section>
  );
}
