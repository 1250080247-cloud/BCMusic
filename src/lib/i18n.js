export const dictionaries = {
  vi: {
    common: {
      brand: 'BCMusic',
      home: 'Trang chủ',
      history: 'Lịch sử',
      settings: 'Cài đặt',
      unknownArtist: 'Kênh YouTube',
      unknownDate: 'Chưa rõ',
      unavailable: 'Chưa có dữ liệu',
    },
    home: {
      categories: {
        tiktokRemix: 'TikTok Remix',
        chineseMusic: 'Nhạc Trung',
        lofi: 'Lofi Chill',
        edm: 'EDM',
        acoustic: 'Acoustic',
        kpop: 'K-Pop',
        rapViet: 'Rap Việt',
        rnb: 'R&B / Soul',
        piano: 'Piano',
        popHits: 'Pop Hits',
      },
      noSongsTitle: 'Hệ thống chưa tìm thấy bài hát nào!',
      noSongsDescription: 'Hãy thử kiểm tra lại API Key hoặc đổi sang thể loại nhạc khác.',
      nextPage: 'Trang tiếp',
      previousPage: 'Trang trước',
      openHistory: 'Lịch sử',
      searchPlaceholder: 'Tìm bài hát, nghệ sĩ...',
      searchButton: 'Tìm kiếm',
      searchResultsFor: 'Kết quả cho',
      clearSearch: 'Xoá tìm kiếm',
    },
    ranking: {
      title: 'Top Thịnh Hành',
      subtitle: 'Những bài hát được xem nhiều nhất trên YouTube',
    },
    dualView: {
      mostViewed: '🔥 Xem nhiều nhất',
      newest: '✨ Mới nhất',
    },
    settings: {
      title: 'Cài đặt',
      subtitle: 'Tùy chỉnh trải nghiệm nghe nhạc của cậu.',
      audio: 'Âm thanh',
      volume: 'Âm lượng',
      playbackSpeed: 'Tốc độ phát',
      normalSpeed: 'Bình thường',
      theme: 'Giao diện',
      light: 'Sáng',
      dark: 'Tối',
      language: 'Ngôn ngữ',
      vietnamese: 'Tiếng Việt',
      english: 'English',
      saved: 'Tự lưu trên trình duyệt này.',
    },
    modal: {
      details: 'Thông tin bài hát',
      artistChannel: 'Ca sĩ / Kênh',
      releaseDate: 'Ngày phát hành',
      playNow: 'Phát nhạc ngay',
      close: 'Đóng',
      videoId: 'Mã video',
      source: 'Nguồn phát',
      listenedAt: 'Nghe lúc',
      openOnYouTube: 'Mở trên YouTube',
      thumbnail: 'Ảnh đại diện',
    },
    player: {
      coverAlt: 'Ảnh bài hát',
      previous: 'Bài trước',
      play: 'Phát',
      pause: 'Tạm dừng',
      next: 'Bài tiếp',
      showDetails: 'Xem thông tin bài hát',
      repeatOff: 'Tắt lặp lại',
      repeatAll: 'Lặp lại tất cả',
      repeatOne: 'Lặp lại một bài',
    },
    lyrics: {
      title: 'Lời bài hát',
      open: 'Mở lời bài hát',
      close: 'Đóng lời bài hát',
      unavailableTitle: 'Chưa có lời bài hát',
      unavailableDescription: 'BCMusic đã dựng sẵn khung lời. Muốn có lời thật, mình cần nối thêm nguồn lyrics/API hợp lệ.',
      hint: 'Khi có lyrics, phần này sẽ hiện song song lúc phát nhạc.',
    },
    history: {
      title: 'Lịch sử nghe',
      subtitle: 'Những bài cậu vừa mở sẽ được xếp gọn ở đây.',
      backHome: 'Quay lại Trang chủ',
      emptyTitle: 'Chưa có bài nào trong lịch sử',
      emptyDescription: 'Ra trang chủ chọn một bài, BCMusic sẽ tự lưu lại cho cậu.',
      recentlyPlayed: 'Vừa nghe gần đây',
      totalTracks: 'bài gần đây',
      latestListen: 'Lần nghe mới nhất',
      listenedAt: 'Nghe lúc',
      tipTitle: 'Mẹo nhỏ',
      tipDescription: 'Click một lần để xem chi tiết, double click để phát lại ngay.',
    },
    bottomNav: {
      home: 'Trang chủ',
      library: 'Thư viện',
      playlist: 'Playlist',
      search: 'Tìm kiếm',
      close: 'Đóng',
      soundcloud: 'SoundCloud',
    },
    playlist: {
      title: 'Danh sách phát',
      subtitle: 'Tạo và quản lý danh sách nhạc theo sở thích của cậu.',
      createNew: 'Tạo playlist mới',
      namePlaceholder: 'Tên playlist...',
      create: 'Tạo',
      emptyTitle: 'Chưa có playlist nào',
      emptyDescription: 'Nhấn nút "Tạo" để bắt đầu xây dựng danh sách nhạc riêng.',
      deletePlaylist: 'Xoá playlist',
      removeSong: 'Xoá khỏi playlist',
      playAll: 'Phát tất cả',
      songCount: 'bài hát',
      addToPlaylist: 'Thêm vào playlist',
      selectPlaylist: 'Chọn playlist',
      alreadyInPlaylist: 'Đã có trong playlist này',
      addedToPlaylist: 'Đã thêm vào',
      noPlaylistYet: 'Chưa có playlist — tạo một cái trước nhé!',
      createdAt: 'Tạo lúc',
      songsInPlaylist: 'Bài hát trong playlist',
    },
    soundcloud: {
      title: 'SoundCloud',
      subtitle: 'Dán link SoundCloud để thêm bài hát yêu thích vào thư viện.',
      placeholder: 'Dán link SoundCloud tại đây... (vd: https://soundcloud.com/artist/track)',
      importButton: 'Thêm',
      importSuccess: 'Đã thêm thành công:',
      importError: 'Không thể import bài hát. Kiểm tra lại link.',
      invalidUrl: 'Link không hợp lệ. Hãy dùng link từ soundcloud.com.',
      alreadyImported: 'Bài hát này đã có trong thư viện.',
      emptyTitle: 'Chưa có bài nào từ SoundCloud',
      emptyDescription: 'Dán link SoundCloud ở trên để bắt đầu thêm nhạc.',
      hintTitle: '💡 Cách lấy link',
      hintDescription: 'Mở soundcloud.com → tìm bài hát → copy link từ thanh địa chỉ hoặc nút "Share".',
      libraryLabel: 'Thư viện SoundCloud',
      tracksCount: 'bài hát',
      deleteTrack: 'Xoá khỏi thư viện',
      openOnSoundCloud: 'Mở trên SoundCloud',
      importedAt: 'Đã thêm lúc',
    },
  },
  en: {
    common: {
      brand: 'BCMusic',
      home: 'Home',
      history: 'History',
      settings: 'Settings',
      unknownArtist: 'YouTube Channel',
      unknownDate: 'Unknown',
      unavailable: 'Unavailable',
    },
    home: {
      categories: {
        tiktokRemix: 'TikTok Remix',
        chineseMusic: 'Chinese Hits',
        lofi: 'Lofi Chill',
        edm: 'EDM',
        acoustic: 'Acoustic',
        kpop: 'K-Pop',
        rapViet: 'Viet Rap',
        rnb: 'R&B / Soul',
        piano: 'Piano',
        popHits: 'Pop Hits',
      },
      noSongsTitle: 'No songs found yet!',
      noSongsDescription: 'Check the API key or try another music category.',
      nextPage: 'Next page',
      previousPage: 'Previous page',
      openHistory: 'History',
      searchPlaceholder: 'Search songs, artists...',
      searchButton: 'Search',
      searchResultsFor: 'Results for',
      clearSearch: 'Clear search',
    },
    ranking: {
      title: 'Top Trending',
      subtitle: 'Most viewed music videos on YouTube',
    },
    dualView: {
      mostViewed: '🔥 Most Viewed',
      newest: '✨ Newest',
    },
    settings: {
      title: 'Settings',
      subtitle: 'Tune the listening experience your way.',
      audio: 'Audio',
      volume: 'Volume',
      playbackSpeed: 'Playback speed',
      normalSpeed: 'Normal',
      theme: 'Theme',
      light: 'Light',
      dark: 'Dark',
      language: 'Language',
      vietnamese: 'Tiếng Việt',
      english: 'English',
      saved: 'Saved on this browser automatically.',
    },
    modal: {
      details: 'Song details',
      artistChannel: 'Artist / Channel',
      releaseDate: 'Release date',
      playNow: 'Play now',
      close: 'Close',
      videoId: 'Video ID',
      source: 'Playback source',
      listenedAt: 'Listened at',
      openOnYouTube: 'Open on YouTube',
      thumbnail: 'Thumbnail',
    },
    player: {
      coverAlt: 'Song cover',
      previous: 'Previous song',
      play: 'Play',
      pause: 'Pause',
      next: 'Next song',
      showDetails: 'Show song details',
      repeatOff: 'Repeat off',
      repeatAll: 'Repeat all',
      repeatOne: 'Repeat one',
    },
    lyrics: {
      title: 'Lyrics',
      open: 'Open lyrics',
      close: 'Close lyrics',
      unavailableTitle: 'No lyrics yet',
      unavailableDescription: 'BCMusic has the lyrics panel ready. To show real lyrics, we need to connect a valid lyrics source/API.',
      hint: 'When lyrics are available, they will appear alongside playback here.',
    },
    history: {
      title: 'Listening History',
      subtitle: 'Recently played tracks live here, neat and ready.',
      backHome: 'Back Home',
      emptyTitle: 'No listening history yet',
      emptyDescription: 'Pick a song on the home page and BCMusic will save it here.',
      recentlyPlayed: 'Recently played',
      totalTracks: 'recent tracks',
      latestListen: 'Latest listen',
      listenedAt: 'Listened at',
      tipTitle: 'Quick tip',
      tipDescription: 'Single click for details, double click to replay instantly.',
    },
    bottomNav: {
      home: 'Home',
      library: 'Library',
      playlist: 'Playlist',
      search: 'Search',
      close: 'Close',
      soundcloud: 'SoundCloud',
    },
    playlist: {
      title: 'Playlists',
      subtitle: 'Create and manage your own music collections.',
      createNew: 'Create new playlist',
      namePlaceholder: 'Playlist name...',
      create: 'Create',
      emptyTitle: 'No playlists yet',
      emptyDescription: 'Tap "Create" to start building your own music collection.',
      deletePlaylist: 'Delete playlist',
      removeSong: 'Remove from playlist',
      playAll: 'Play all',
      songCount: 'songs',
      addToPlaylist: 'Add to playlist',
      selectPlaylist: 'Select playlist',
      alreadyInPlaylist: 'Already in this playlist',
      addedToPlaylist: 'Added to',
      noPlaylistYet: 'No playlists yet — create one first!',
      createdAt: 'Created at',
      songsInPlaylist: 'Songs in playlist',
    },
    soundcloud: {
      title: 'SoundCloud',
      subtitle: 'Paste a SoundCloud link to add your favorite tracks to your library.',
      placeholder: 'Paste SoundCloud link here... (e.g. https://soundcloud.com/artist/track)',
      importButton: 'Add',
      importSuccess: 'Successfully added:',
      importError: 'Could not import track. Please check the link.',
      invalidUrl: 'Invalid link. Please use a link from soundcloud.com.',
      alreadyImported: 'This track is already in your library.',
      emptyTitle: 'No SoundCloud tracks yet',
      emptyDescription: 'Paste a SoundCloud link above to start adding music.',
      hintTitle: '💡 How to get a link',
      hintDescription: 'Open soundcloud.com → find a track → copy the link from the address bar or the "Share" button.',
      libraryLabel: 'SoundCloud Library',
      tracksCount: 'tracks',
      deleteTrack: 'Remove from library',
      openOnSoundCloud: 'Open on SoundCloud',
      importedAt: 'Added at',
    },
  },
};

export function getDictionary(language = 'vi') {
  return dictionaries[language] || dictionaries.vi;
}

export function formatDate(value, language = 'vi') {
  if (!value) return getDictionary(language).common.unknownDate;

  try {
    return new Intl.DateTimeFormat(language === 'vi' ? 'vi-VN' : 'en-US', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    }).format(new Date(value));
  } catch {
    return getDictionary(language).common.unknownDate;
  }
}

export function formatDateTime(value, language = 'vi') {
  if (!value) return getDictionary(language).common.unknownDate;

  try {
    return new Intl.DateTimeFormat(language === 'vi' ? 'vi-VN' : 'en-US', {
      hour: '2-digit',
      minute: '2-digit',
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    }).format(new Date(value));
  } catch {
    return getDictionary(language).common.unknownDate;
  }
}

export function formatViewCount(count, language = 'vi') {
  if (!count) return null;
  const n = Number(count);
  if (Number.isNaN(n)) return null;

  const suffix = language === 'vi'
    ? { B: 'B', M: 'Tr', K: 'N' }
    : { B: 'B', M: 'M', K: 'K' };
  const viewLabel = language === 'vi' ? 'lượt xem' : 'views';

  let formatted;
  if (n >= 1_000_000_000) {
    formatted = `${(n / 1_000_000_000).toFixed(1).replace(/\.0$/, '')}${suffix.B}`;
  } else if (n >= 1_000_000) {
    formatted = `${(n / 1_000_000).toFixed(1).replace(/\.0$/, '')}${suffix.M}`;
  } else if (n >= 1_000) {
    formatted = `${(n / 1_000).toFixed(1).replace(/\.0$/, '')}${suffix.K}`;
  } else {
    formatted = n.toString();
  }

  return `${formatted} ${viewLabel}`;
}

