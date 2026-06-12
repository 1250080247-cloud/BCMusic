"use client";

import BottomNav from '@/components/BottomNav';
import Player from '@/components/Player';
import SongModal from '@/components/SongModal';

/**
 * Persistent UI shell that wraps the entire app.
 * Player, SongModal, and BottomNav live here so they
 * are never unmounted during page navigations — keeping
 * audio playback continuous across routes.
 */
export default function PersistentShell({ children }) {
  return (
    <>
      {children}
      <Player />
      <SongModal />
      <BottomNav />
    </>
  );
}
