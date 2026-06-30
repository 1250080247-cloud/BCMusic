"use client";

import { Suspense, useEffect } from 'react';
import { useSession } from 'next-auth/react';
import { useMusicStore } from '@/lib/store';
import BottomNav from '@/components/BottomNav';
import NowPlayingPanel from '@/components/NowPlayingPanel';
import Player from '@/components/Player';
import Sidebar from '@/components/Sidebar';
import SongModal from '@/components/SongModal';

export default function PersistentShell({ children }) {
  const { data: session } = useSession();
  const setFavorites = useMusicStore((state) => state.setFavorites);

  useEffect(() => {
    if (session?.user?.id) {
      fetch(`/api/favorites?userId=${session.user.id}`)
        .then((res) => res.json())
        .then((data) => {
          if (data.success) {
            setFavorites(data.data || []);
          }
        })
        .catch((err) => console.error('Error fetching favorites:', err));
    } else {
      setFavorites([]);
    }
  }, [session, setFavorites]);

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
