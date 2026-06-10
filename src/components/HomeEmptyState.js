"use client";

import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

export default function HomeEmptyState() {
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  return (
    <div className="surface-card rounded-3xl p-10 text-center">
      <p className="mb-2 text-xl font-bold text-pink-400">{t.home.noSongsTitle}</p>
      <p className="muted-text">{t.home.noSongsDescription}</p>
    </div>
  );
}
