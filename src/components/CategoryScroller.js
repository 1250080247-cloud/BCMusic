"use client";

import { ChevronLeft, ChevronRight } from 'lucide-react';
import Link from 'next/link';
import { useCallback, useEffect, useRef, useState } from 'react';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

export default function CategoryScroller({ categories, currentQuery }) {
  const scrollRef = useRef(null);
  const [canScrollLeft, setCanScrollLeft] = useState(false);
  const [canScrollRight, setCanScrollRight] = useState(false);
  const isDragging = useRef(false);
  const startX = useRef(0);
  const scrollLeftStart = useRef(0);
  const hasMoved = useRef(false);
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  const updateScrollState = useCallback(() => {
    const el = scrollRef.current;
    if (!el) return;
    setCanScrollLeft(el.scrollLeft > 2);
    setCanScrollRight(el.scrollLeft < el.scrollWidth - el.clientWidth - 2);
  }, []);

  useEffect(() => {
    const el = scrollRef.current;
    if (!el) return;

    updateScrollState();
    el.addEventListener('scroll', updateScrollState, { passive: true });
    window.addEventListener('resize', updateScrollState);

    return () => {
      el.removeEventListener('scroll', updateScrollState);
      window.removeEventListener('resize', updateScrollState);
    };
  }, [updateScrollState]);

  const scrollBy = (direction) => {
    const el = scrollRef.current;
    if (!el) return;
    el.scrollBy({ left: direction * 200, behavior: 'smooth' });
  };

  const handleMouseDown = (event) => {
    isDragging.current = true;
    hasMoved.current = false;
    startX.current = event.pageX;
    scrollLeftStart.current = scrollRef.current.scrollLeft;
    scrollRef.current.style.cursor = 'grabbing';
    scrollRef.current.style.userSelect = 'none';
  };

  const handleMouseMove = (event) => {
    if (!isDragging.current) return;
    const dx = event.pageX - startX.current;
    if (Math.abs(dx) > 3) hasMoved.current = true;
    scrollRef.current.scrollLeft = scrollLeftStart.current - dx;
  };

  const handleMouseUp = () => {
    isDragging.current = false;
    if (scrollRef.current) {
      scrollRef.current.style.cursor = 'grab';
      scrollRef.current.style.removeProperty('user-select');
    }
  };

  useEffect(() => {
    document.addEventListener('mouseup', handleMouseUp);
    document.addEventListener('mousemove', handleMouseMove);

    return () => {
      document.removeEventListener('mouseup', handleMouseUp);
      document.removeEventListener('mousemove', handleMouseMove);
    };
  }, []);

  return (
    <div className="category-scroller-wrapper relative w-full max-w-4xl">
      {canScrollLeft && (
        <>
          <div className="category-scroller-fade-left" />
          <button
            type="button"
            aria-label="Scroll left"
            onClick={() => scrollBy(-1)}
            className="category-scroller-arrow category-scroller-arrow-left"
          >
            <ChevronLeft size={18} />
          </button>
        </>
      )}

      <nav
        ref={scrollRef}
        onMouseDown={handleMouseDown}
        className="scrollbar-hide flex w-full gap-3 overflow-x-auto pb-4"
        style={{ cursor: 'grab' }}
      >
        {categories.map((category) => {
          const isActive = currentQuery === category.query;

          return (
            <Link
              key={category.key}
              href={`/?genre=${encodeURIComponent(category.query)}`}
              onClick={(event) => {
                if (hasMoved.current) event.preventDefault();
              }}
              draggable={false}
            >
              <span className={`category-pill ${isActive ? 'is-active' : ''}`}>
                {t.home.categories[category.key]}
              </span>
            </Link>
          );
        })}
      </nav>

      {canScrollRight && (
        <>
          <div className="category-scroller-fade-right" />
          <button
            type="button"
            aria-label="Scroll right"
            onClick={() => scrollBy(1)}
            className="category-scroller-arrow category-scroller-arrow-right"
          >
            <ChevronRight size={18} />
          </button>
        </>
      )}
    </div>
  );
}
