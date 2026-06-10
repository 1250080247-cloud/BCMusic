"use client";

import Image from 'next/image';
import Link from 'next/link';
import SettingsPanel from '@/components/SettingsPanel';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

export default function HomeHeader({ categories, currentQuery }) {
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  return (
    <header className="px-4 pt-10 sm:px-8 sm:pt-12">
      <div className="mx-auto flex max-w-screen-xl flex-col items-center text-center">
        <div className="relative mb-7 flex w-full items-center justify-center">
          <div className="absolute right-0 top-0 flex items-center gap-2">
            <Link href="/history" className="hidden sm:inline-flex">
              <span className="pill-button px-5 py-2 text-sm font-semibold">
                {t.home.openHistory}
              </span>
            </Link>
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

        <Link href="/history" className="mb-5 sm:hidden">
          <span className="pill-button px-5 py-2 text-sm font-semibold">{t.home.openHistory}</span>
        </Link>

        <nav className="scrollbar-hide flex w-full max-w-3xl justify-start gap-3 overflow-x-auto pb-4 sm:justify-center">
          {categories.map((category) => {
            const isActive = currentQuery === category.query;

            return (
              <Link key={category.key} href={`/?genre=${encodeURIComponent(category.query)}`}>
                <span className={`category-pill ${isActive ? 'is-active' : ''}`}>
                  {t.home.categories[category.key]}
                </span>
              </Link>
            );
          })}
        </nav>
      </div>
    </header>
  );
}
