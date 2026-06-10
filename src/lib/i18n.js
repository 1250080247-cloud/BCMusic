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
      },
      noSongsTitle: 'Hệ thống chưa tìm thấy bài hát nào!',
      noSongsDescription: 'Hãy thử kiểm tra lại API Key hoặc đổi sang thể loại nhạc khác.',
      nextPage: 'Trang tiếp',
      previousPage: 'Trang trước',
      openHistory: 'Lịch sử',
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
      },
      noSongsTitle: 'No songs found yet!',
      noSongsDescription: 'Check the API key or try another music category.',
      nextPage: 'Next page',
      previousPage: 'Previous page',
      openHistory: 'History',
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
