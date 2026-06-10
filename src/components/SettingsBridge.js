"use client";

import { useEffect } from 'react';
import { useSettingsStore } from '@/lib/store';

export default function SettingsBridge() {
  const theme = useSettingsStore((state) => state.theme);
  const language = useSettingsStore((state) => state.language);

  useEffect(() => {
    document.documentElement.dataset.theme = theme;
    document.documentElement.lang = language;
  }, [theme, language]);

  return null;
}
