"use client";

import { useEffect, useState, useRef, Suspense } from 'react';
import { Search, X, Trash2, ArrowLeft, ArrowRight, Loader2, History } from 'lucide-react';
import { useRouter, useSearchParams } from 'next/navigation';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';
import SongCard from '@/components/SongCard';

function SearchContent() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  // Store history actions & state
  const searchHistory = useSettingsStore((state) => state.searchHistory) || [];
  const addSearchHistory = useSettingsStore((state) => state.addSearchHistory);
  const removeSearchHistory = useSettingsStore((state) => state.removeSearchHistory);
  const clearSearchHistory = useSettingsStore((state) => state.clearSearchHistory);

  const initialQuery = searchParams.get('q') || '';
  const [query, setQuery] = useState(initialQuery);
  const [activeSearch, setActiveSearch] = useState(initialQuery);
  const [results, setResults] = useState([]);
  const [loading, setLoading] = useState(false);
  const [nextPageToken, setNextPageToken] = useState(null);
  const [prevPageToken, setPrevPageToken] = useState(null);
  const inputRef = useRef(null);

  const performSearch = async (searchTerm, token = '') => {
    if (!searchTerm.trim()) {
      setResults([]);
      setNextPageToken(null);
      setPrevPageToken(null);
      setActiveSearch('');
      return;
    }

    setLoading(true);
    try {
      const response = await fetch(
        `/api/search?q=${encodeURIComponent(searchTerm)}&pageToken=${token}&maxResults=10`
      );
      const data = await response.json();
      setResults(data.items || []);
      setNextPageToken(data.nextPageToken || null);
      setPrevPageToken(data.prevPageToken || null);
      setActiveSearch(searchTerm);

      // Save to search history
      addSearchHistory(searchTerm);
    } catch (error) {
      console.error('Search error:', error);
    } finally {
      setLoading(false);
    }
  };

  // Sync state and perform search when query parameters change
  useEffect(() => {
    const q = searchParams.get('q') || '';
    const token = searchParams.get('token') || '';
    setQuery(q);
    performSearch(q, token);
  }, [searchParams]);

  const handleSubmit = (e) => {
    e.preventDefault();
    const trimmed = query.trim();
    if (!trimmed) {
      router.push('/search');
      return;
    }
    router.push(`/search?q=${encodeURIComponent(trimmed)}`);
  };

  const handleRecentClick = (term) => {
    setQuery(term);
    router.push(`/search?q=${encodeURIComponent(term)}`);
  };

  const handleClearInput = () => {
    setQuery('');
    router.push('/search');
    inputRef.current?.focus();
  };

  const handlePageChange = (token) => {
    router.push(`/search?q=${encodeURIComponent(activeSearch)}&token=${token}`);
  };

  return (
    <div className="mx-auto px-4 sm:px-8 w-full" style={{ maxWidth: '80rem' }}>
      <h1 className="text-2xl font-extrabold mb-6 text-[var(--app-text)] tracking-tight sm:text-3xl">
        {t.searchPage.title}
      </h1>

      {/* Input bar */}
      <form onSubmit={handleSubmit} className="relative flex items-center gap-3 w-full">
        <div className="relative flex-1">
          <Search size={20} className="absolute left-4 top-1/2 -translate-y-1/2 text-[var(--muted-text)]" />
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder={t.searchPage.placeholder}
            className="w-full bg-[var(--surface)] hover:bg-[var(--surface-hover)] focus:bg-[var(--surface-strong)] text-[var(--app-text)] pl-12 pr-10 py-3 rounded-full border border-[var(--border)] focus:border-pink-500/50 outline-none transition-all text-sm font-medium shadow-inner sm:text-base sm:py-3.5"
          />
          {query && (
            <button
              type="button"
              onClick={handleClearInput}
              className="absolute right-4 top-1/2 -translate-y-1/2 text-[var(--muted-text)] hover:text-[var(--app-text)] p-0.5 rounded-full hover:bg-white/10 transition-all"
            >
              <X size={18} />
            </button>
          )}
        </div>
        <button
          type="submit"
          className="px-5 py-3 rounded-full bg-pink-500 hover:bg-pink-600 active:scale-95 text-white font-bold text-sm transition-all shadow-[0_0_20px_rgba(236,72,153,0.3)] flex-shrink-0 sm:px-6 sm:py-3.5 sm:text-base"
        >
          {t.searchPage.button}
        </button>
      </form>

      {/* Main Content Area */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-20 gap-4">
          <Loader2 size={36} className="text-pink-500 animate-spin" />
          <p className="text-sm font-medium text-[var(--muted-text)]">
            {t.searchPage.searching}
          </p>
        </div>
      ) : activeSearch ? (
        /* Results Section */
        <div className="mt-8 animate-fade-in">
          <h2 className="text-lg font-bold mb-4 text-[var(--app-text)]">
            {t.searchPage.resultsFor} <span className="text-pink-400">"{activeSearch}"</span>
          </h2>

          {results.length === 0 ? (
            <div className="surface-card rounded-3xl p-12 text-center border border-[var(--border)]">
              <Search size={48} className="mx-auto mb-4 text-[var(--muted-text)] opacity-40" />
              <p className="font-bold text-lg text-[var(--app-text)]">{t.searchPage.noResults}</p>
              <p className="muted-text mt-1 text-sm">{t.searchPage.noResultsHint}</p>
            </div>
          ) : (
            <>
              <div className="flex flex-col gap-4">
                {results.map((song) => (
                  <SongCard key={song.id} song={song} playlist={results} />
                ))}
              </div>

              {/* Pagination controls */}
              <div className="mt-8 flex items-center justify-center gap-4">
                {prevPageToken && (
                  <button
                    onClick={() => handlePageChange(prevPageToken)}
                    className="pill-button px-5 py-2 text-sm font-semibold flex items-center gap-1"
                  >
                    <ArrowLeft size={16} />
                    {t.home.previousPage}
                  </button>
                )}
                {nextPageToken && (
                  <button
                    onClick={() => handlePageChange(nextPageToken)}
                    className="pill-button px-5 py-2 text-sm font-semibold flex items-center gap-1"
                  >
                    {t.home.nextPage}
                    <ArrowRight size={16} />
                  </button>
                )}
              </div>
            </>
          )}
        </div>
      ) : (
        /* History Section */
        <div className="search-history-container mt-8 animate-fade-in">
          <div className="mb-4 flex items-center justify-between">
            <h2 className="text-base font-bold text-[var(--app-text)] flex items-center gap-2 sm:text-lg">
              <History size={18} className="text-pink-400" />
              {t.searchPage.recentSearches}
            </h2>
            {searchHistory.length > 0 && (
              <button
                onClick={clearSearchHistory}
                className="text-xs font-semibold text-pink-400 hover:text-pink-300 transition-colors flex items-center gap-1"
              >
                <Trash2 size={13} />
                {t.searchPage.clearAll}
              </button>
            )}
          </div>

          {searchHistory.length === 0 ? (
            <div className="surface-card rounded-3xl p-8 text-center border border-[var(--border)]">
              <History size={36} className="mx-auto mb-3 text-[var(--muted-text)] opacity-40" />
              <p className="font-bold text-[var(--app-text)]">{t.searchPage.noHistory}</p>
              <p className="muted-text mt-1 text-sm">{t.searchPage.noHistoryHint}</p>
            </div>
          ) : (
            <div className="flex flex-col gap-2 max-w-2xl">
              {searchHistory.map((term, index) => (
                <div
                  key={index}
                  className="flex items-center justify-between px-4 py-2.5 rounded-2xl bg-[var(--surface)] hover:bg-[var(--surface-hover)] transition-all group border border-[var(--border)]/30"
                >
                  <button
                    onClick={() => handleRecentClick(term)}
                    className="flex items-center gap-3 text-left font-medium text-sm text-[var(--app-text)] hover:text-pink-400 transition-colors flex-1"
                  >
                    <Search size={15} className="text-[var(--muted-text)]" />
                    <span>{term}</span>
                  </button>
                  <button
                    onClick={() => removeSearchHistory(term)}
                    className="text-[var(--muted-text)] hover:text-red-400 p-1 rounded-full hover:bg-red-500/10 transition-all md:opacity-0 md:group-hover:opacity-100 focus:opacity-100"
                    aria-label={`Remove ${term}`}
                  >
                    <X size={15} />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default function SearchView() {
  return (
    <main className="app-shell relative pb-32 pt-6">
      <Suspense fallback={
        <div className="flex items-center justify-center min-h-[50vh]">
          <Loader2 size={36} className="text-pink-500 animate-spin" />
        </div>
      }>
        <SearchContent />
      </Suspense>
    </main>
  );
}
