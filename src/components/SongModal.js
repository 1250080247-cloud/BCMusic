"use client";

import { ExternalLink, FileText, Hash, Image as ImageIcon, Play, Radio, X } from 'lucide-react';
import Image from 'next/image';
import { formatDate, formatDateTime, getDictionary } from '@/lib/i18n';
import { useMusicStore, useSettingsStore } from '@/lib/store';

export default function SongModal() {
  const { viewingSong, setViewingSong, setCurrentSong } = useMusicStore();
  const language = useSettingsStore((state) => state.language);
  const t = getDictionary(language);

  if (!viewingSong) return null;

  const youtubeUrl = viewingSong.id ? `https://www.youtube.com/watch?v=${viewingSong.id}` : null;
  const songDetails = [
    {
      icon: Radio,
      label: t.modal.artistChannel,
      value: viewingSong.artist || t.common.unknownArtist,
    },
    {
      icon: Hash,
      label: t.modal.videoId,
      value: viewingSong.id || t.common.unavailable,
    },
    {
      icon: ImageIcon,
      label: t.modal.thumbnail,
      value: viewingSong.thumbnail ? 'YouTube thumbnail' : t.common.unavailable,
    },
  ];

  if (viewingSong.publishedAt) {
    songDetails.push({
      icon: FileText,
      label: t.modal.releaseDate,
      value: formatDate(viewingSong.publishedAt, language),
    });
  }

  if (viewingSong.listenedAt) {
    songDetails.push({
      icon: FileText,
      label: t.modal.listenedAt,
      value: formatDateTime(viewingSong.listenedAt, language),
    });
  }

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center bg-black/70 p-4 backdrop-blur-md">
      <div className="modal-shell relative max-h-[92vh] w-full max-w-3xl overflow-y-auto rounded-3xl p-6 shadow-2xl shadow-pink-500/10">
        <button
          type="button"
          aria-label={t.modal.close}
          onClick={() => setViewingSong(null)}
          className="absolute right-4 top-4 rounded-full p-2 text-[var(--muted-text)] transition hover:bg-[var(--surface-hover)] hover:text-[var(--app-text)]"
        >
          <X size={22} />
        </button>

        <div className="mt-4 grid gap-6 md:grid-cols-[1fr_1.05fr]">
          <div>
            <div className="aspect-video w-full overflow-hidden rounded-3xl bg-[var(--surface-strong)] shadow-lg">
              {viewingSong.thumbnail && (
                <Image
                  src={viewingSong.thumbnail}
                  alt=""
                  width={640}
                  height={360}
                  className="h-full w-full object-cover"
                />
              )}
            </div>

            <div className="mt-4 flex flex-wrap gap-3">
              <button
                type="button"
                onClick={() => {
                  setCurrentSong(viewingSong);
                  setViewingSong(null);
                }}
                className="flex flex-1 items-center justify-center gap-2 rounded-full bg-gradient-to-r from-purple-500 to-pink-600 px-5 py-3 font-bold text-white transition-all hover:scale-[1.02] hover:from-purple-400 hover:to-pink-500"
              >
                <Play fill="white" size={20} />
                {t.modal.playNow}
              </button>
              {youtubeUrl && (
                <a
                  href={youtubeUrl}
                  target="_blank"
                  rel="noreferrer"
                  className="pill-button gap-2 px-5 py-3 text-sm font-bold"
                >
                  <ExternalLink size={18} />
                  {t.modal.openOnYouTube}
                </a>
              )}
            </div>
          </div>

          <div>
            <p className="mb-2 text-sm font-semibold uppercase tracking-[0.28em] text-pink-400">
              {t.modal.details}
            </p>
            <h2
              className="mb-5 text-2xl font-extrabold leading-tight text-[var(--app-text)]"
              dangerouslySetInnerHTML={{ __html: viewingSong.title }}
            />

            <div className="grid gap-3">
              {songDetails.map((item) => {
                const Icon = item.icon;

                return (
                  <div key={`${item.label}-${item.value}`} className="detail-chip">
                    <div className="mb-1 flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.18em] text-cyan-400">
                      <Icon size={15} />
                      {item.label}
                    </div>
                    <p className="break-words text-sm font-semibold">{item.value}</p>
                  </div>
                );
              })}
            </div>

            <section className="detail-chip mt-4">
              <div className="mb-2 flex items-center gap-2 text-xs font-semibold uppercase tracking-[0.18em] text-pink-400">
                <FileText size={15} />
                {t.lyrics.title}
              </div>
              {viewingSong.lyrics ? (
                <p className="max-h-40 overflow-y-auto whitespace-pre-line text-sm leading-7">
                  {viewingSong.lyrics}
                </p>
              ) : (
                <div>
                  <p className="font-semibold text-[var(--app-text)]">{t.lyrics.unavailableTitle}</p>
                  <p className="muted-text mt-1 text-sm leading-6">{t.lyrics.unavailableDescription}</p>
                </div>
              )}
            </section>
          </div>
        </div>
      </div>
    </div>
  );
}
