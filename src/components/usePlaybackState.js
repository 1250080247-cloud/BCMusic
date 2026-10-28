'use client';

import { useEffect, useState } from 'react';

export default function usePlaybackState(songId) {
  const [state, setState] = useState(null);
  useEffect(() => {
    const onState = event => setState(event.detail);
    window.addEventListener('bcmusic:playstate', onState);
    // The home page can mount while the persistent player is already playing.
    window.dispatchEvent(new Event('bcmusic:requestplaystate'));
    return () => window.removeEventListener('bcmusic:playstate', onState);
  }, [songId]);
  return Boolean(songId && state?.songId === songId && state?.isPlaying);
}
