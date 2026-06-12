"use client";

import { Home, Library, ListMusic, Search, X } from 'lucide-react';
import Link from 'next/link';
import { usePathname, useRouter, useSearchParams } from 'next/navigation';
import { useState, useRef, useEffect } from 'react';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

const navItems = [
  { key: 'home', href: '/', icon: Home },
  { key: 'library', href: '/history', icon: Library },
  { key: 'playlist', href: '/playlist', icon: ListMusic },
];

export default function BottomNav() {
  const pathname = usePathname();
  const router = useRouter();
  const searchParams = useSearchParams();
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  const currentSearch = searchParams.get('search') || '';
  const [isSearchOpen, setIsSearchOpen] = useState(false);
  const [query, setQuery] = useState(currentSearch);
  const inputRef = useRef(null);

  // Sync query state with URL search param
  useEffect(() => {
    setQuery(currentSearch);
    if (currentSearch) {
      setIsSearchOpen(true);
    }
  }, [currentSearch]);

  // Auto-focus input when search opens
  useEffect(() => {
    if (isSearchOpen && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isSearchOpen]);

  const handleSubmit = (event) => {
    event.preventDefault();
    const trimmed = query.trim();

    if (!trimmed) {
      router.push('/');
      setIsSearchOpen(false);
      return;
    }

    router.push(`/?search=${encodeURIComponent(trimmed)}`);
    inputRef.current?.blur();
  };

  const handleClear = () => {
    setQuery('');
    setIsSearchOpen(false);
    router.push('/');
  };

  const toggleSearch = () => {
    if (isSearchOpen) {
      handleClear();
    } else {
      setIsSearchOpen(true);
    }
  };

  return (
    <>
      {/* Search Slide-Up Panel */}
      <div
        className={`nav-search-panel fixed left-1/2 z-40 -translate-x-1/2 transition-all duration-300 ease-out ${
          isSearchOpen
            ? 'pointer-events-auto translate-y-0 opacity-100'
            : 'pointer-events-none translate-y-4 opacity-0'
        }`}
        style={{ bottom: '62px', width: '92%', maxWidth: '480px' }}
      >
        <form
          onSubmit={handleSubmit}
          className="flex items-center gap-2 px-3 py-2.5"
        >
          <div className="relative flex flex-1 items-center">
            <Search size={16} className="pointer-events-none absolute left-3.5 text-[var(--muted-text)]" />
            <input
              ref={inputRef}
              type="text"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder={t.home.searchPlaceholder}
              className="search-input w-full rounded-full py-2.5 pl-10 pr-9 text-sm font-medium"
            />
            {query && (
              <button
                type="button"
                aria-label={t.home.clearSearch}
                onClick={handleClear}
                className="absolute right-3 rounded-full p-0.5 text-[var(--muted-text)] transition hover:text-[var(--app-text)]"
              >
                <X size={14} />
              </button>
            )}
          </div>
          <button
            type="submit"
            className="search-submit-button flex-shrink-0 rounded-full px-4 py-2.5 text-sm font-bold text-white"
          >
            {t.home.searchButton}
          </button>
        </form>
      </div>

      {/* Bottom Nav Bar */}
      <nav className="bottom-nav fixed bottom-0 left-0 right-0 z-40">
        <div className="mx-auto flex max-w-screen-xl items-center justify-around">
          {/* Home */}
          <Link
            href="/"
            className={`bottom-nav-item ${pathname === '/' ? 'is-active' : ''}`}
          >
            <Home size={22} strokeWidth={pathname === '/' ? 2.2 : 1.6} />
            <span className="text-[11px] font-semibold">{t.bottomNav.home}</span>
          </Link>

          {/* Search Toggle */}
          <button
            type="button"
            onClick={toggleSearch}
            className={`bottom-nav-item ${isSearchOpen ? 'is-active' : ''}`}
          >
            {isSearchOpen ? <X size={22} strokeWidth={2.2} /> : <Search size={22} strokeWidth={1.6} />}
            <span className="text-[11px] font-semibold">
              {isSearchOpen ? t.bottomNav.close : t.bottomNav.search}
            </span>
          </button>

          {/* Library */}
          <Link
            href="/history"
            className={`bottom-nav-item ${pathname === '/history' ? 'is-active' : ''}`}
          >
            <Library size={22} strokeWidth={pathname === '/history' ? 2.2 : 1.6} />
            <span className="text-[11px] font-semibold">{t.bottomNav.library}</span>
          </Link>

          {/* Playlist */}
          <Link
            href="/playlist"
            className={`bottom-nav-item ${pathname === '/playlist' ? 'is-active' : ''}`}
          >
            <ListMusic size={22} strokeWidth={pathname === '/playlist' ? 2.2 : 1.6} />
            <span className="text-[11px] font-semibold">{t.bottomNav.playlist}</span>
          </Link>
        </div>
      </nav>
    </>
  );
}
