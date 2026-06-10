"use client";

import { useEffect, useState } from 'react';
import { Gauge, Languages, Moon, Settings, Sun, Volume2, X } from 'lucide-react';
import { getDictionary } from '@/lib/i18n';
import { useSettingsStore } from '@/lib/store';

const playbackRates = [0.75, 1, 1.25, 1.5];

export default function SettingsPanel() {
  const [isOpen, setIsOpen] = useState(false);
  const {
    theme,
    language,
    volume,
    playbackRate,
    setTheme,
    setLanguage,
    setVolume,
    setPlaybackRate,
  } = useSettingsStore();
  const t = getDictionary(language);

  useEffect(() => {
    if (!isOpen) return;

    const closeOnEscape = (event) => {
      if (event.key === 'Escape') setIsOpen(false);
    };

    window.addEventListener('keydown', closeOnEscape);
    return () => window.removeEventListener('keydown', closeOnEscape);
  }, [isOpen]);

  return (
    <div className="relative z-[130]">
      <button
        type="button"
        aria-label={t.common.settings}
        title={t.common.settings}
        onClick={() => setIsOpen((value) => !value)}
        className="settings-trigger"
      >
        <Settings size={20} />
      </button>

      {isOpen && (
        <>
          <button
            type="button"
            aria-label={t.modal.close}
            className="fixed inset-0 z-[120] cursor-default bg-black/20 backdrop-blur-[1px]"
            onClick={() => setIsOpen(false)}
          />

          <section className="settings-panel absolute right-0 top-14 z-[140] w-[min(22rem,calc(100vw-2rem))] rounded-3xl p-5 shadow-2xl">
            <div className="mb-5 flex items-start justify-between gap-4">
              <div>
                <p className="text-sm font-semibold uppercase tracking-[0.25em] text-pink-400">
                  {t.settings.title}
                </p>
                <p className="muted-text mt-1 text-sm">{t.settings.subtitle}</p>
              </div>
              <button
                type="button"
                aria-label={t.modal.close}
                onClick={() => setIsOpen(false)}
                className="rounded-full p-2 text-[var(--muted-text)] transition hover:bg-[var(--surface-hover)] hover:text-[var(--app-text)]"
              >
                <X size={18} />
              </button>
            </div>

            <div className="space-y-5">
              <div className="surface-card rounded-2xl p-4">
                <div className="mb-4 flex items-center gap-2 font-semibold">
                  <Volume2 size={18} className="text-pink-400" />
                  {t.settings.audio}
                </div>
                <label className="muted-text flex items-center justify-between text-sm">
                  <span>{t.settings.volume}</span>
                  <span>{volume}%</span>
                </label>
                <input
                  type="range"
                  min="0"
                  max="100"
                  value={volume}
                  onChange={(event) => setVolume(event.target.value)}
                  className="music-range mt-3 w-full"
                />

                <div className="mt-4">
                  <div className="muted-text mb-2 flex items-center gap-2 text-sm">
                    <Gauge size={16} />
                    {t.settings.playbackSpeed}
                  </div>
                  <div className="grid grid-cols-4 gap-2">
                    {playbackRates.map((rate) => (
                      <button
                        type="button"
                        key={rate}
                        onClick={() => setPlaybackRate(rate)}
                        className={`rounded-xl px-3 py-2 text-sm font-semibold transition ${
                          playbackRate === rate
                            ? 'bg-pink-500 text-white shadow-lg shadow-pink-500/25'
                            : 'bg-[var(--surface-strong)] text-[var(--muted-text)] hover:text-[var(--app-text)]'
                        }`}
                      >
                        {rate === 1 ? '1x' : `${rate}x`}
                      </button>
                    ))}
                  </div>
                </div>
              </div>

              <div className="grid grid-cols-2 gap-3">
                <div className="surface-card rounded-2xl p-4">
                  <div className="mb-3 text-sm font-semibold">{t.settings.theme}</div>
                  <div className="grid gap-2">
                    <button
                      type="button"
                      onClick={() => setTheme('dark')}
                      className={`settings-choice ${theme === 'dark' ? 'is-active' : ''}`}
                    >
                      <Moon size={16} />
                      {t.settings.dark}
                    </button>
                    <button
                      type="button"
                      onClick={() => setTheme('light')}
                      className={`settings-choice ${theme === 'light' ? 'is-active' : ''}`}
                    >
                      <Sun size={16} />
                      {t.settings.light}
                    </button>
                  </div>
                </div>

                <div className="surface-card rounded-2xl p-4">
                  <div className="mb-3 flex items-center gap-2 text-sm font-semibold">
                    <Languages size={16} />
                    {t.settings.language}
                  </div>
                  <div className="grid gap-2">
                    <button
                      type="button"
                      onClick={() => setLanguage('vi')}
                      className={`settings-choice ${language === 'vi' ? 'is-active' : ''}`}
                    >
                      VI
                      {t.settings.vietnamese}
                    </button>
                    <button
                      type="button"
                      onClick={() => setLanguage('en')}
                      className={`settings-choice ${language === 'en' ? 'is-active' : ''}`}
                    >
                      EN
                      {t.settings.english}
                    </button>
                  </div>
                </div>
              </div>

              <p className="muted-text text-center text-xs">{t.settings.saved}</p>
            </div>
          </section>
        </>
      )}
    </div>
  );
}
