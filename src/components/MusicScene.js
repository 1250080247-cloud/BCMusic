'use client';

import Image from 'next/image';
import { ArrowDown, ArrowUpRight, Headphones, Pause, Play, Sparkles } from 'lucide-react';
import { useEffect, useRef, useState } from 'react';
import gsap from 'gsap';
import { useGSAP } from '@gsap/react';
import { useMusicStore, useSettingsStore } from '@/lib/store';
import { decodeSongTitle } from '@/lib/song-title';
import usePlaybackState from './usePlaybackState';
import './music-scene.css';

if (typeof window !== 'undefined') gsap.registerPlugin(useGSAP);

export default function MusicScene() {
  const root = useRef(null);
  const scene = useRef(null);
  const deck = useRef(null);
  const song = useMusicStore(state => state.currentSong);
  const openPlayer = useMusicStore(state => state.setNowPlayingOpen);
  const vi = useSettingsStore(state => state.language) === 'vi';
  const playing = usePlaybackState(song?.id);
  const [motion, setMotion] = useState(true);
  const [failedImage, setFailedImage] = useState(null);
  const cover = song?.thumbnail && song.thumbnail !== failedImage ? song.thumbnail : '/logo.jpg';

  useEffect(() => {
    const element = root.current;
    let inView = false;
    const update = () => { element.dataset.active = String(motion && inView && !document.hidden); };
    const observer = new IntersectionObserver(([entry]) => { inView = entry.isIntersecting; update(); });
    observer.observe(element);
    document.addEventListener('visibilitychange', update);
    return () => {
      observer.disconnect();
      document.removeEventListener('visibilitychange', update);
      element.dataset.active = 'false';
    };
  }, [motion]);

  useGSAP(() => {
    if (!motion) return;
    const media = gsap.matchMedia();
    media.add('(hover: hover) and (pointer: fine) and (prefers-reduced-motion: no-preference)', () => {
      const surface = scene.current;
      const tiltX = gsap.quickTo(deck.current, 'rotationX', { duration: 0.7, ease: 'power3.out' });
      const tiltY = gsap.quickTo(deck.current, 'rotationY', { duration: 0.7, ease: 'power3.out' });
      gsap.set(deck.current, { rotationX: 28, rotationY: -14, rotationZ: -12 });
      const move = event => {
        if (event.pointerType === 'touch') return;
        const bounds = surface.getBoundingClientRect();
        tiltX(28 - (event.clientY - bounds.top - bounds.height / 2) / bounds.height * 12);
        tiltY(-14 + (event.clientX - bounds.left - bounds.width / 2) / bounds.width * 18);
      };
      const reset = () => { tiltX(28); tiltY(-14); };
      surface.addEventListener('pointermove', move);
      surface.addEventListener('pointerleave', reset);
      return () => {
        surface.removeEventListener('pointermove', move);
        surface.removeEventListener('pointerleave', reset);
      };
    });
    return () => media.revert();
  }, { scope: root, dependencies: [motion], revertOnUpdate: true });

  return (
    <section ref={root} className="music-scene" data-playing={playing} data-active="false" aria-label={vi ? 'Không gian âm nhạc' : 'Your listening space'}>
      <div className="music-scene-copy">
        <p className="music-scene-eyebrow"><Headphones size={14} /> {vi ? 'KHÔNG GIAN CỦA BẠN' : 'YOUR LISTENING SPACE'}</p>
        <h2>{vi ? <>Bật nhạc.<br /><span>Chạm cảm xúc.</span></> : <>Press play.<br /><span>Feel everything.</span></>}</h2>
        <p className="music-scene-caption">{vi ? 'Một bài hát, một tâm trạng. Tìm nhịp điệu của riêng bạn.' : 'A song for every mood. Find your own rhythm.'}</p>
        {song ? (
          <button className="music-scene-link" onClick={() => openPlayer(true)}>{vi ? 'Mở trình phát' : 'Open player'} <ArrowUpRight size={16} /></button>
        ) : (
          <a className="music-scene-link" href="#music-discovery">{vi ? 'Khám phá âm nhạc' : 'Discover music'} <ArrowDown size={16} /></a>
        )}
      </div>
      <div ref={scene} className="music-scene-stage" aria-hidden="true">
        <div className="music-scene-halo" />
        <div className="music-scene-float">
          <div ref={deck} className="music-scene-deck">
            <div className="music-scene-platter">
              <div className="music-scene-vinyl">
                <div className="music-scene-label">
                  <Image src={cover} alt="" fill sizes="80px" unoptimized onError={() => setFailedImage(cover)} />
                </div>
                <i className="music-scene-spindle" />
              </div>
            </div>
            <div className="music-scene-arm"><i /></div>
            <span className="music-scene-brand">BC / 01</span>
            <span className="music-scene-led" />
            <div className="music-scene-levels">{[0, 1, 2, 3, 4, 5, 6].map(i => <i key={i} style={{ '--bar': i }} />)}</div>
          </div>
        </div>
      </div>
      <div className="music-scene-footer">
        <p className="music-scene-track"><span className={playing ? 'is-playing' : ''} />
          {song ? <><span className="music-scene-status">{playing ? (vi ? 'ĐANG PHÁT' : 'NOW PLAYING') : (vi ? 'ĐÃ CHỌN' : 'SELECTED')}</span><span className="music-scene-title">{decodeSongTitle(song.title)}</span></> : <span>{vi ? 'Sẵn sàng cho giai điệu tiếp theo' : 'Ready for your next favorite'}</span>}
        </p>
        <button type="button" className="music-scene-motion" aria-pressed={motion} aria-label={vi ? 'Chuyển động 3D' : '3D motion'} onClick={() => setMotion(value => !value)}>
          {motion ? <Pause size={13} /> : <Play size={13} />} <span>3D</span><Sparkles size={12} />
        </button>
      </div>
    </section>
  );
}
