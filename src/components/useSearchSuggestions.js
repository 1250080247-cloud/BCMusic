"use client";

import { useEffect, useState } from 'react';
import { mergeSearchSuggestions } from '@/lib/search-suggestions';

export default function useSearchSuggestions({ query, history, language, onSelect }) {
  const term = query.trim();
  const key = JSON.stringify([term, language]);
  const [opened, setOpened] = useState(false);
  const [response, setResponse] = useState(null);
  const [active, setActive] = useState(null);
  const current = response?.key === key ? response : null;
  const isOpen = opened && Boolean(term);
  const canFetch = term.length >= 2 && term.length <= 120;
  const items = mergeSearchSuggestions(term, history, current?.items);
  const activeIndex = active?.key === key && active.index < items.length ? active.index : -1;

  useEffect(() => {
    if (!isOpen || !canFetch || current) return;
    const controller = new AbortController();
    const timer = setTimeout(async () => {
      try {
        const parameters = new URLSearchParams({ q: term, language });
        const result = await fetch(`/api/search/suggestions?${parameters}`, { signal: controller.signal });
        if (!result.ok) throw new Error('suggestions_unavailable');
        const data = await result.json();
        if (!Array.isArray(data.suggestions)) throw new Error('invalid_suggestions');
        if (!controller.signal.aborted) setResponse({ key, items: data.suggestions, unavailable: Boolean(data.unavailable) });
      } catch {
        if (!controller.signal.aborted) setResponse({ key, items: [], unavailable: true });
      }
    }, 300);
    return () => { clearTimeout(timer); controller.abort(); };
  }, [isOpen, canFetch, current, key, term, language]);

  const close = () => { setOpened(false); setActive(null); };
  const open = () => {
    setOpened(true);
    setActive(null);
    if (current?.unavailable) setResponse(null);
  };
  const select = value => { close(); onSelect(value); };
  const onKeyDown = event => {
    if (event.nativeEvent?.isComposing || event.isComposing) return;
    if (event.key === 'Escape' && isOpen) { event.preventDefault(); close(); }
    if (['ArrowDown', 'ArrowUp'].includes(event.key) && items.length) {
      event.preventDefault();
      setOpened(true);
      const index = isOpen ? activeIndex : -1;
      setActive({ key, index: event.key === 'ArrowDown' ? (index + 1) % items.length : (index < 0 ? items.length - 1 : (index - 1 + items.length) % items.length) });
    }
    if (event.key === 'Enter' && isOpen && activeIndex >= 0) { event.preventDefault(); select(items[activeIndex]); }
  };

  return {
    items, activeIndex, open, close, select, onKeyDown,
    show: isOpen && (items.length > 0 || canFetch),
    loading: isOpen && canFetch && !current,
    unavailable: Boolean(current?.unavailable),
    setActiveIndex: index => setActive({ key, index }),
    onBlur: event => { if (!event.currentTarget.contains(event.relatedTarget)) close(); },
  };
}
