"use client";

import { Search, X } from 'lucide-react';
import { useRouter } from 'next/navigation';
import { useState } from 'react';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

export default function SearchBar({ currentSearch }) {
  const [query, setQuery] = useState(currentSearch || '');
  const router = useRouter();
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  const handleSubmit = (event) => {
    event.preventDefault();
    const trimmed = query.trim();

    if (!trimmed) {
      router.push('/');
      return;
    }

    router.push(`/?search=${encodeURIComponent(trimmed)}`);
  };

  const handleClear = () => {
    setQuery('');
    router.push('/');
  };

  return (
    <form onSubmit={handleSubmit} className="search-bar mx-auto mb-6 flex w-full max-w-xl items-center gap-2">
      <div className="relative flex flex-1 items-center">
        <Search size={18} className="pointer-events-none absolute left-4 text-[var(--muted-text)]" />
        <input
          type="text"
          value={query}
          onChange={(event) => setQuery(event.target.value)}
          placeholder={t.home.searchPlaceholder}
          className="search-input w-full rounded-full py-3 pl-11 pr-10 text-sm font-medium"
        />
        {query && (
          <button
            type="button"
            aria-label={t.home.clearSearch}
            onClick={handleClear}
            className="absolute right-3 rounded-full p-1 text-[var(--muted-text)] transition hover:text-[var(--app-text)]"
          >
            <X size={16} />
          </button>
        )}
      </div>
      <button
        type="submit"
        className="search-submit-button flex-shrink-0 rounded-full px-5 py-3 text-sm font-bold text-white"
      >
        {t.home.searchButton}
      </button>
    </form>
  );
}
