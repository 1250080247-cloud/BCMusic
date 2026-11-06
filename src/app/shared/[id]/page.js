import Image from 'next/image';
import { notFound } from 'next/navigation';
import dbConnect from '@/lib/mongodb';
import { isObjectIdString } from '@/lib/input';
import { getDictionary } from '@/lib/i18n';
import { decodeSongTitle } from '@/lib/song-title';
import { safeSourceUrl } from '@/lib/url-policy';
import Playlist from '@/models/Playlist';

// Public, read-only view of a playlist its owner has made public. Owner identity is not shown.
export default async function SharedPlaylistPage({ params }) {
  const { id } = await params;
  if (!isObjectIdString(id)) notFound();

  await dbConnect();
  const playlist = await Playlist.findOne({ _id: id, isPublic: true }).select('name songs').lean();
  if (!playlist) notFound();

  const t = getDictionary('vi');
  return (
    <main className="app-shell relative pb-8">
      <header className="px-4 pt-10 sm:px-8 sm:pt-12">
        <div className="mx-auto max-w-screen-xl text-center">
          <p className="mb-1 text-xs font-semibold uppercase tracking-[0.42em] text-purple-400">
            {t.playlist.sharedTitle}
          </p>
          <h1 className="break-words text-3xl font-extrabold sm:text-4xl">{playlist.name}</h1>
          <p className="muted-text mt-2 text-sm">{playlist.songs.length} {t.playlist.songCount}</p>
        </div>
      </header>

      <section className="mx-auto mt-8 max-w-4xl px-4 sm:px-8">
        <ol className="flex flex-col gap-3">
          {playlist.songs.map((song) => {
            const link = safeSourceUrl(song.sourceUrl);
            return (
              <li key={song.id} className="surface-card flex items-center gap-4 rounded-2xl p-3">
                <div className="relative h-12 w-20 flex-shrink-0 overflow-hidden rounded-xl bg-[var(--surface-strong)]">
                  {song.thumbnail && (
                    <Image src={song.thumbnail} alt="" fill sizes="80px" unoptimized className="object-cover" />
                  )}
                </div>
                <div className="min-w-0 flex-1">
                  <p className="line-clamp-1 text-sm font-semibold">{decodeSongTitle(song.title)}</p>
                  <p className="muted-text truncate text-xs">{song.artist}</p>
                </div>
                {link && (
                  <a href={link} target="_blank" rel="noreferrer" className="pill-button px-4 py-2 text-xs font-bold">
                    {song.source === 'soundcloud' ? (t.soundcloud?.openOnSoundCloud || 'SoundCloud') : t.modal.openOnYouTube}
                  </a>
                )}
              </li>
            );
          })}
        </ol>
      </section>
    </main>
  );
}
