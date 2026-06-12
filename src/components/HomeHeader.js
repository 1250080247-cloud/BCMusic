"use client";

import Image from 'next/image';
import CategoryScroller from '@/components/CategoryScroller';
import SettingsPanel from '@/components/SettingsPanel';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

export default function HomeHeader({ categories, currentQuery, currentSearch }) {
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  return (
    <header className="px-4 pt-10 sm:px-8 sm:pt-12">
      <div className="mx-auto flex max-w-screen-xl flex-col items-center text-center">
        <div className="relative mb-7 flex w-full items-center justify-center">
          <div className="absolute right-0 top-0">
            <SettingsPanel />
          </div>

          <div className="flex flex-col items-center gap-4 sm:flex-row">
            <div className="h-16 w-16 overflow-hidden rounded-full border-2 border-pink-500 shadow-[0_0_24px_rgba(236,72,153,0.45)]">
              <Image src="/logo.jpg" alt="BCMusic Logo" width={64} height={64} className="h-full w-full object-cover" />
            </div>
            <div>
              <p className="mb-1 text-xs font-semibold uppercase tracking-[0.45em] text-pink-400">
                Stream your vibe
              </p>
              <h1 className="bg-gradient-to-r from-purple-400 via-pink-400 to-red-500 bg-clip-text text-4xl font-extrabold text-transparent sm:text-5xl">
                {t.common.brand}
              </h1>
            </div>
          </div>
        </div>

        {!currentSearch && (
          <CategoryScroller categories={categories} currentQuery={currentQuery} />
        )}
      </div>
    </header>
  );
}
