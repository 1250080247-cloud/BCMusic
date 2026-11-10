"use client";

import { useEffect, useState } from 'react';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

export default function HomeEmptyState({ unavailable = false }) {
  const [mounted, setMounted] = useState(false);
  const storeLanguage = useSettingsStore((state) => state.language);
  const language = mounted ? storeLanguage : 'vi';
  useEffect(() => { setMounted(true); }, []);
  const t = getDictionary(language);

  return (
    <div className="surface-card rounded-3xl p-10 text-center">
      <p className="mb-2 text-xl font-bold text-pink-400">
        {unavailable
          ? (language === 'vi' ? 'Không thể kết nối nguồn nhạc' : 'Music source unavailable')
          : t.home.noSongsTitle}
      </p>
      <p className="muted-text">
        {unavailable
          ? (language === 'vi' ? 'Đã quá thời gian chờ kết nối. Vui lòng kiểm tra lại mạng hoặc thử lại sau.' : 'Connection timed out. Please check your network and try again.')
          : t.home.noSongsDescription}
      </p>
    </div>
  );
}
