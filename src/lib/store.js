import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export const useMusicStore = create((set) => ({
  currentSong: null,
  playlist: [],
  setCurrentSong: (song) => set({ currentSong: song }),
  setPlaylist: (list) => set({ playlist: list }),

  viewingSong: null,
  setViewingSong: (song) => set({ viewingSong: song }),
}));

export const useSettingsStore = create(
  persist(
    (set, get) => ({
      theme: 'dark',
      language: 'vi',
      volume: 80,
      playbackRate: 1,
      setTheme: (theme) => set({ theme }),
      toggleTheme: () => set({ theme: get().theme === 'dark' ? 'light' : 'dark' }),
      setLanguage: (language) => set({ language }),
      setVolume: (volume) => set({ volume: Math.min(100, Math.max(0, Number(volume))) }),
      setPlaybackRate: (playbackRate) => set({ playbackRate: Number(playbackRate) }),
    }),
    {
      name: 'bcmusic-settings',
      partialize: (state) => ({
        theme: state.theme,
        language: state.language,
        volume: state.volume,
        playbackRate: state.playbackRate,
      }),
    }
  )
);
