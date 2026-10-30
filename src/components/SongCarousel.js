'use client';

import { useEffect, useId, useRef, useState } from 'react';
import { ChevronLeft, ChevronRight } from 'lucide-react';
import MotionList from '@/components/MotionList';

export default function SongCarousel({ title, subtitle, genre, icon, language = 'vi', animationKey, children, isLoading = false }) {
  const track = useRef(null);
  const gesture = useRef(null);
  const dragged = useRef(false);
  const id = useId();
  const [edges, setEdges] = useState({ start: true, end: true });
  const vi = language === 'vi';

  useEffect(() => {
    const element = track.current;
    const update = () => {
      const next = { start: element.scrollLeft <= 2, end: element.scrollLeft >= element.scrollWidth - element.clientWidth - 2 };
      setEdges(previous => previous.start === next.start && previous.end === next.end ? previous : next);
    };
    const observer = new ResizeObserver(update);
    observer.observe(element);
    if (element.firstElementChild) observer.observe(element.firstElementChild);
    element.addEventListener('scroll', update, { passive: true });
    update();
    return () => { observer.disconnect(); element.removeEventListener('scroll', update); };
  }, [animationKey, isLoading]);

  const scroll = direction => {
    const element = track.current;
    element.scrollBy({ left: direction * element.clientWidth * .8, behavior: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 'auto' : 'smooth' });
  };
  const pointerDown = event => {
    dragged.current = false;
    if (event.pointerType === 'touch' || event.button !== 0) return;
    gesture.current = { id: event.pointerId, x: event.clientX, left: event.currentTarget.scrollLeft };
  };
  const pointerMove = event => {
    const start = gesture.current;
    if (!start || start.id !== event.pointerId) return;
    const dx = event.clientX - start.x;
    if (!dragged.current && Math.abs(dx) <= 6) return;
    dragged.current = true;
    event.currentTarget.dataset.dragging = 'true';
    event.currentTarget.setPointerCapture(event.pointerId);
    event.currentTarget.scrollLeft = start.left - dx;
  };
  const pointerEnd = event => {
    gesture.current = null;
    event.currentTarget.dataset.dragging = 'false';
    if (event.currentTarget.hasPointerCapture(event.pointerId)) event.currentTarget.releasePointerCapture(event.pointerId);
  };
  const suppressDragClick = event => {
    if (dragged.current && event.detail !== 0) { event.preventDefault(); event.stopPropagation(); }
  };
  const onKeyDown = event => {
    if (event.target !== event.currentTarget) return;
    if (['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) {
      event.preventDefault();
      if (event.key === 'Home' || event.key === 'End') track.current.scrollTo({ left: event.key === 'Home' ? 0 : track.current.scrollWidth, behavior: 'auto' });
      else scroll(event.key === 'ArrowRight' ? 1 : -1);
    }
  };

  return (
    <div className="song-carousel">
      <div className="discovery-section-heading">
        <div className="discovery-heading-copy">
          <span className="discovery-heading-icon" aria-hidden="true">{icon}</span>
          <div>
            <div className="discovery-heading-line"><h2 id={`${id}-heading`}>{title}</h2>{genre && <span className="discovery-genre-label">{genre}</span>}</div>
            {subtitle && <p>{subtitle}</p>}
          </div>
        </div>
        <div className="carousel-controls">
          <button type="button" aria-controls={id} aria-label={`${vi ? 'Cuộn trái' : 'Scroll left'} · ${title}`} disabled={edges.start || isLoading} onClick={() => scroll(-1)}><ChevronLeft size={18} aria-hidden="true" /></button>
          <button type="button" aria-controls={id} aria-label={`${vi ? 'Cuộn phải' : 'Scroll right'} · ${title}`} disabled={edges.end || isLoading} onClick={() => scroll(1)}><ChevronRight size={18} aria-hidden="true" /></button>
        </div>
      </div>
      <div ref={track} id={id} role="region" aria-labelledby={`${id}-heading`} tabIndex={0} className="song-carousel-viewport"
        onPointerDown={pointerDown} onPointerMove={pointerMove} onPointerUp={pointerEnd} onPointerCancel={pointerEnd} onLostPointerCapture={pointerEnd}
        onClickCapture={suppressDragClick} onDoubleClickCapture={suppressDragClick} onKeyDown={onKeyDown} onDragStart={event => event.preventDefault()}>
        <MotionList animationKey={animationKey} className="song-carousel-items">{children}</MotionList>
      </div>
    </div>
  );
}
