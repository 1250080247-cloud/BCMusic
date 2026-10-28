"use client";

import { Music } from 'lucide-react';
import Image from 'next/image';
import { useState } from 'react';

function ArtworkTile({ song, collage }) {
  const [failed, setFailed] = useState(false);
  return (
    <div className="relative flex min-h-0 min-w-0 items-center justify-center overflow-hidden bg-gradient-to-br from-purple-500/20 to-pink-500/20 text-purple-400">
      {song?.thumbnail && !failed
        ? <Image src={song.thumbnail} alt="" fill sizes={collage ? '(min-width: 640px) 56px, 40px' : '(min-width: 640px) 112px, 80px'} className="object-cover" onError={() => setFailed(true)} />
        : <Music size={collage ? 18 : 30} />}
    </div>
  );
}

export default function PlaylistArtwork({ songs = [] }) {
  // The playlist API appends new songs; derive the cover without sorting its queue.
  const latest = songs.slice(-4).reverse();
  const collage = latest.length > 1;
  const tiles = Array.from({ length: collage ? 4 : 1 }, (_, index) => latest[index] || null);
  return (
    <div aria-hidden="true" className={`grid h-20 w-20 shrink-0 overflow-hidden rounded-2xl sm:h-28 sm:w-28 ${collage ? 'grid-cols-2 grid-rows-2' : 'grid-cols-1 grid-rows-1'}`}>
      {tiles.map((song, index) => <ArtworkTile key={song ? `${song.id}:${song.thumbnail || ''}` : `empty-${index}`} song={song} collage={collage} />)}
    </div>
  );
}
