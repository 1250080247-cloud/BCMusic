"use client";

import Link from 'next/link';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

export default function PaginationControls({ currentQuery, prevPageToken, nextPageToken, currentSearch }) {
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  if (!prevPageToken && !nextPageToken) return null;

  const buildHref = (token) => {
    if (currentSearch) {
      return `/?search=${encodeURIComponent(currentSearch)}&token=${token}`;
    }
    return `/?genre=${encodeURIComponent(currentQuery)}&token=${token}`;
  };

  return (
    <div className="mb-8 mt-10 flex items-center justify-center gap-4">
      {prevPageToken && (
        <Link href={buildHref(prevPageToken)}>
          <span className="pill-button px-5 py-2 text-sm font-semibold">
            &larr; {t.home.previousPage}
          </span>
        </Link>
      )}
      {nextPageToken && (
        <Link href={buildHref(nextPageToken)}>
          <span className="pill-button px-5 py-2 text-sm font-semibold">
            {t.home.nextPage} &rarr;
          </span>
        </Link>
      )}
    </div>
  );
}
