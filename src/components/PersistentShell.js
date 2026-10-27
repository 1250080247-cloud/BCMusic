"use client";

import { Suspense, useEffect } from 'react';
import { useSession } from 'next-auth/react';
import { useMusicStore } from '@/lib/store';
import BottomNav from '@/components/BottomNav';
import NowPlayingPanel from '@/components/NowPlayingPanel';
import Player from '@/components/Player';
import Sidebar from '@/components/Sidebar';
import SongModal from '@/components/SongModal';
import PageMotion from '@/components/PageMotion';

export default function PersistentShell({ children }) {
  const { data: session } = useSession();
  const setFavorites = useMusicStore((state) => state.setFavorites);
  const userId = session?.user?.id;

  useEffect(() => {
    const controller = new AbortController();
    setFavorites([]);
    if (userId) {
      fetch('/api/favorites', { signal: controller.signal })
        .then((res) => res.json())
        .then((data) => {
          if (!controller.signal.aborted && data.success) {
            setFavorites(data.data || []);
          }
        })
        .catch((err) => {
          if (!controller.signal.aborted) console.error('Error fetching favorites:', err);
        });
    }
    return () => controller.abort();
  }, [userId, setFavorites]);

  return (
    <>
      <Sidebar />
      <div className="app-layout-main">
        <PageMotion>{children}</PageMotion>
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
