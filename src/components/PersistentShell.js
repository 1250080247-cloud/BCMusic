"use client";

import { Suspense } from 'react';
import BottomNav from '@/components/BottomNav';
import NowPlayingPanel from '@/components/NowPlayingPanel';
import Player from '@/components/Player';
import Sidebar from '@/components/Sidebar';
import SongModal from '@/components/SongModal';

/**
 * Persistent UI shell that wraps the entire app.
 * Player, SongModal, Sidebar, NowPlayingPanel, and BottomNav live here so they
 * are never unmounted during page navigations — keeping
 * audio playback continuous across routes.
 *
 * All overlay elements (Sidebar, Player, NowPlayingPanel, BottomNav) use
 * position: fixed, so they do NOT participate in the document flow.
 * The main content area gets margin-left via CSS when sidebar is visible.
 *
 * BottomNav uses useSearchParams() which requires a Suspense boundary.
 */
export default function PersistentShell({ children }) {
  return (
    <>
      <Sidebar />
      <div className="app-layout-main">
        {children}
      </div>
      <NowPlayingPanel />
      <Player />
      <SongModal />
      <Suspense fallback={null}>
        <BottomNav />
      </Suspense>
    </>
  );
}
