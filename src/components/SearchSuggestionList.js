"use client";

import { Loader2, Search } from 'lucide-react';
import { useEffect, useRef } from 'react';

export default function SearchSuggestionList({ menu, listId, copy }) {
  const listRef = useRef(null);
  useEffect(() => {
    const list = listRef.current;
    const option = list?.querySelector('[aria-selected="true"]');
    if (!menu.show || !option) return;
    const area = list.getBoundingClientRect();
    const item = option.getBoundingClientRect();
    if (item.top < area.top) list.scrollTop -= area.top - item.top;
    else if (item.bottom > area.bottom) list.scrollTop += item.bottom - area.bottom;
  }, [menu.activeIndex, menu.show]);
  if (!menu.show) return null;
  return (
    <div className="absolute left-0 right-0 top-full z-50 mt-2 overflow-hidden rounded-2xl border border-[var(--border)] bg-[var(--surface-strong)] shadow-xl backdrop-blur-xl">
      <p id={`${listId}-label`} className="px-4 pb-2 pt-3 text-xs font-semibold text-[var(--muted-text)]">{copy.suggestions}</p>
      <ul ref={listRef} id={listId} role="listbox" aria-labelledby={`${listId}-label`} className="max-h-80 overflow-y-auto pb-2">
        {menu.items.map((term, index) => (
          <li key={term} role="presentation">
            <button type="button" role="option" tabIndex={-1} id={`${listId}-${index}`} aria-selected={menu.activeIndex === index}
              onPointerDown={event => event.preventDefault()} onPointerMove={() => menu.setActiveIndex(index)} onClick={() => menu.select(term)}
              className={`flex min-h-11 w-full items-center gap-3 px-4 py-2.5 text-left text-sm text-[var(--app-text)] transition-colors ${menu.activeIndex === index ? 'bg-pink-500/15' : 'hover:bg-[var(--surface-hover)]'}`}>
              <Search size={15} className="shrink-0 text-[var(--muted-text)]" /><span className="truncate">{term}</span>
            </button>
          </li>
        ))}
      </ul>
      {(menu.loading || menu.unavailable || !menu.items.length) && <p role="status" className="flex items-center gap-2 border-t border-[var(--border)] px-4 py-3 text-xs text-[var(--muted-text)]">
        {menu.loading && <Loader2 size={14} className="animate-spin motion-reduce:animate-none" />}
        {menu.loading ? copy.suggestionsLoading : menu.unavailable ? copy.suggestionsUnavailable : copy.suggestionsEmpty}
      </p>}
    </div>
  );
}
