"use client";

import { SessionProvider, useSession } from 'next-auth/react';
import { useEffect } from 'react';

const MERGED_FOR_KEY = 'bcmusic-guest-merged-for';

// After sign-in, moves guest playlists and history into the account. Runs once per signed-in user per tab.
function GuestDataMerger() {
  const { data: session, status } = useSession();
  const userId = session?.user?.id;

  useEffect(() => {
    if (status !== 'authenticated' || !userId || userId.startsWith('guest:')) return;
    if (window.sessionStorage.getItem(MERGED_FOR_KEY) === userId) return;
    window.sessionStorage.setItem(MERGED_FOR_KEY, userId);
    fetch('/api/user/merge-guest', { method: 'POST' }).catch((error) => {
      window.sessionStorage.removeItem(MERGED_FOR_KEY);
      console.error('Guest data merge failed:', error);
    });
  }, [status, userId]);

  return null;
}

export default function Providers({ children }) {
  return (
    <SessionProvider>
      <GuestDataMerger />
      {children}
    </SessionProvider>
  );
}
