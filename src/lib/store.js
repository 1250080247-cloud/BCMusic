import { create } from 'zustand';
import { persist } from 'zustand/middleware';

export const useMusicStore = create((set, get) => ({
  currentSong: null,
  playlist: [],
  favorites: [],
  setCurrentSong: (song) => set({ currentSong: song }),
  setPlaylist: (list) => set({ playlist: list }),
  setFavorites: (list) => set({ favorites: list }),
  addFavorite: (song) => set((state) => ({ favorites: [song, ...state.favorites] })),
  removeFavorite: (songId) => set((state) => ({ favorites: state.favorites.filter((s) => s.id !== songId) })),

  viewingSong: null,
  setViewingSong: (song) => set({ viewingSong: song }),

  // Now Playing panel
  nowPlayingOpen: false,
  setNowPlayingOpen: (open) => set({ nowPlayingOpen: open }),
  toggleNowPlaying: () => set((state) => ({ nowPlayingOpen: !state.nowPlayingOpen })),

  // Repeat mode: 'off' | 'all' | 'one'
  repeatMode: 'off',
  setRepeatMode: (mode) => set({ repeatMode: mode }),
  cycleRepeatMode: () => {
    const current = get().repeatMode;
    const next = current === 'off' ? 'all' : current === 'all' ? 'one' : 'off';
    set({ repeatMode: next });
  },
}));

export const useSettingsStore = create(
  persist(
    (set, get) => ({
      theme: 'dark',
      language: 'vi',
      volume: 80,
      playbackRate: 1,
      searchHistory: [],
      setTheme: (theme) => set({ theme }),
      toggleTheme: () => set({ theme: get().theme === 'dark' ? 'light' : 'dark' }),
      setLanguage: (language) => set({ language }),
      setVolume: (volume) => set({ volume: Math.min(100, Math.max(0, Number(volume))) }),
      setPlaybackRate: (playbackRate) => set({ playbackRate: Number(playbackRate) }),
      addSearchHistory: (term) => {
        const trimmed = term.trim();
        if (!trimmed) return;
        const prev = get().searchHistory.filter((t) => t !== trimmed);
        set({ searchHistory: [trimmed, ...prev].slice(0, 20) });
      },
      removeSearchHistory: (term) => {
        set({ searchHistory: get().searchHistory.filter((t) => t !== term) });
      },
      clearSearchHistory: () => set({ searchHistory: [] }),
    }),
    {
      name: 'bcmusic-settings',
      partialize: (state) => ({
        theme: state.theme,
        language: state.language,
        volume: state.volume,
        playbackRate: state.playbackRate,
        searchHistory: state.searchHistory,
      }),
    }
  )
);

export const useUserStore = create(
  persist(
    (set, get) => ({
      userId: null,
      getUserId: () => {
        const existing = get().userId;
        if (existing) return existing;
        const newId = Date.now().toString(36) + Math.random().toString(36).slice(2, 9);
        set({ userId: newId });
        return newId;
      },
    }),
    {
      name: 'bcmusic-user',
      partialize: (state) => ({ userId: state.userId }),
    }
  )
);
