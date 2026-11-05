class SourceLink {
  const SourceLink(this.url, this.provider);
  final String url;
  final String provider;

  factory SourceLink.parse(String input) {
    if (input.length > 8192) {
      throw const FormatException('Link quá dài.');
    }
    final matches = RegExp(r'''https?://[^\s<>"']+''').allMatches(input.trim());
    if (matches.length != 1) {
      throw const FormatException('Hãy dán hoặc chia sẻ một link bài hát.');
    }
    final raw = matches.single.group(0)!.replaceAll(RegExp(r'[).,]+$'), '');
    final uri = Uri.tryParse(raw);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        (uri.hasPort && uri.port != 443)) {
      throw const FormatException(
        'Hãy dùng link HTTPS của YouTube hoặc SoundCloud.',
      );
    }
    final host = uri.host.toLowerCase();
    final parts = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if ([
      'youtube.com',
      'www.youtube.com',
      'm.youtube.com',
      'music.youtube.com',
      'youtu.be',
      'www.youtu.be',
    ].contains(host)) {
      final id = host.endsWith('youtu.be')
          ? (parts.length == 1 ? parts.first : null)
          : (uri.path == '/watch'
                ? uri.queryParameters['v']
                : (parts.length == 2 &&
                          ['shorts', 'embed', 'live'].contains(parts[0])
                      ? parts[1]
                      : null));
      if (id == null || !RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id)) {
        throw const FormatException(
          'Cần link một video YouTube, không phải playlist.',
        );
      }
      return SourceLink('https://www.youtube.com/watch?v=$id', 'youtube');
    }
    if ([
      'soundcloud.com',
      'www.soundcloud.com',
      'm.soundcloud.com',
      'on.soundcloud.com',
    ].contains(host)) {
      final isShort = host == 'on.soundcloud.com' && parts.length == 1;
      final isTrack =
          host != 'on.soundcloud.com' &&
          parts.length == 2 &&
          !['sets', 'likes', 'tracks', 'albums', 'reposts'].contains(parts[1]);
      if (isShort || isTrack) {
        return SourceLink(
          Uri.https(
            isShort ? host : 'soundcloud.com',
            '/${parts.join('/')}',
          ).toString(),
          'soundcloud',
        );
      }
    }
    throw const FormatException(
      'Chỉ hỗ trợ link một bài YouTube hoặc SoundCloud.',
    );
  }
}

class OfflineTrack {
  const OfflineTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.sourceUrl,
    required this.provider,
    required this.status,
    this.progress,
    this.bytes = 0,
    this.durationMs = 0,
    this.artworkPath,
    this.artworkUrl,
    this.error,
  });
  final String id, title, artist, sourceUrl, provider, status;
  final double? progress;
  final int bytes, durationMs;
  final String? artworkPath, artworkUrl, error;
  bool get isReady => status == 'completed';
  bool get isActive => ['queued', 'downloading', 'restarting'].contains(status);

  factory OfflineTrack.fromMap(Map<Object?, Object?> map) {
    final percent = (map['progress'] as num?)?.toDouble();
    return OfflineTrack(
      id: map['id'] as String,
      title: (map['title'] as String?) ?? 'Chưa có tên',
      artist: (map['artist'] as String?) ?? '',
      sourceUrl: map['sourceUrl'] as String,
      provider: map['provider'] as String,
      status: (map['status'] as String?) ?? 'preview',
      progress: percent != null && percent.isFinite && percent >= 0
          ? (percent / 100).clamp(0, 1)
          : null,
      bytes: (map['bytes'] as num?)?.toInt() ?? 0,
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      artworkPath: map['artworkPath'] as String?,
      artworkUrl: map['artworkUrl'] as String?,
      error: map['error'] as String?,
    );
  }

  Map<String, Object?> toMap() => {
    'id': id,
    'title': title,
    'artist': artist,
    'sourceUrl': sourceUrl,
    'provider': provider,
    'status': status,
    'progress': progress == null ? -1 : progress! * 100,
    'bytes': bytes,
    'durationMs': durationMs,
    'artworkPath': artworkPath,
    'artworkUrl': artworkUrl,
    'error': error,
  };
}

class PlaybackState {
  const PlaybackState({
    this.trackId,
    this.isPlaying = false,
    this.positionMs = 0,
    this.durationMs = 0,
    this.error,
    this.track,
    this.offline = true,
    this.hasNext = false,
    this.hasPrevious = false,
  });
  final String? trackId, error;
  final bool isPlaying;
  final int positionMs, durationMs;
  final OfflineTrack? track;
  final bool offline, hasNext, hasPrevious;

  factory PlaybackState.fromMap(Map<Object?, Object?> map) => PlaybackState(
    trackId: map['trackId'] as String?,
    isPlaying: map['isPlaying'] == true,
    positionMs: ((map['positionMs'] as num?)?.toInt() ?? 0).clamp(0, 1 << 53),
    durationMs: ((map['durationMs'] as num?)?.toInt() ?? 0).clamp(0, 1 << 53),
    error: map['error'] as String?,
    track: map['track'] is Map
        ? OfflineTrack.fromMap(Map<Object?, Object?>.from(map['track'] as Map))
        : null,
    offline: map['offline'] != false,
    hasNext: map['hasNext'] == true,
    hasPrevious: map['hasPrevious'] == true,
  );
}

class PlaybackQueueItem {
  const PlaybackQueueItem({
    required this.url,
    required this.title,
    required this.artist,
    this.artworkUrl,
  });

  final String url, title, artist;
  final String? artworkUrl;
}

class LibrarySnapshot {
  const LibrarySnapshot({
    this.tracks = const [],
    this.playback = const PlaybackState(),
    this.incomingText,
    this.shareSequence = 0,
    this.initialized = true,
    this.networkAvailable = true,
    this.playlists = const [],
    this.playlistError,
    this.preferences = const AppPreferences(),
    this.account,
    this.accountError,
  });
  final List<OfflineTrack> tracks;
  final PlaybackState playback;
  final String? incomingText;
  final int shareSequence;
  final bool initialized;
  final bool networkAvailable;
  final List<LocalPlaylist> playlists;
  final String? playlistError;
  final AppPreferences preferences;
  final AccountProfile? account;
  final String? accountError;

  factory LibrarySnapshot.fromMap(Map<Object?, Object?> map) => LibrarySnapshot(
    tracks: ((map['tracks'] as List?) ?? [])
        .map(
          (value) =>
              OfflineTrack.fromMap(Map<Object?, Object?>.from(value as Map)),
        )
        .toList(),
    playback: PlaybackState.fromMap(
      Map<Object?, Object?>.from((map['playback'] as Map?) ?? {}),
    ),
    incomingText: map['incomingText'] as String?,
    shareSequence: (map['shareSequence'] as num?)?.toInt() ?? 0,
    initialized: map['initialized'] != false,
    networkAvailable: map['networkAvailable'] != false,
    playlists: ((map['playlists'] as List?) ?? [])
        .map(
          (value) =>
              LocalPlaylist.fromMap(Map<Object?, Object?>.from(value as Map)),
        )
        .toList(),
    playlistError: map['playlistError'] as String?,
    preferences: AppPreferences.fromMap(
      Map<Object?, Object?>.from((map['preferences'] as Map?) ?? {}),
    ),
    account: map['account'] is Map
        ? AccountProfile.fromMap(
            Map<Object?, Object?>.from(map['account'] as Map),
          )
        : null,
    accountError: map['accountError'] as String?,
  );
}

class AccountProfile {
  const AccountProfile({required this.name, required this.username, this.id});
  final String name, username;
  final String? id;

  Uri? get avatarUri {
    final userId = id;
    if (userId == null ||
        !RegExp(r'^[a-f0-9]{24}$', caseSensitive: false).hasMatch(userId)) {
      return null;
    }
    return Uri.https('bc-music-gilt.vercel.app', '/api/user/avatar', {
      'userId': userId,
    });
  }

  factory AccountProfile.fromMap(Map<Object?, Object?> data) => AccountProfile(
    name: (data['name'] as String?) ?? 'BCMusic',
    username: (data['username'] as String?) ?? '',
    id: data['id'] as String?,
  );
}

class AppPreferences {
  const AppPreferences({
    this.light = false,
    this.volume = 100,
    this.speed = 1,
    this.motion = true,
  });

  final bool light, motion;
  final int volume;
  final double speed;
  static const speeds = [0.75, 1.0, 1.25, 1.5];

  factory AppPreferences.fromMap(Map<Object?, Object?> data) {
    final speed = (data['speed'] as num?)?.toDouble();
    return AppPreferences(
      light: data['light'] == true,
      volume: ((data['volume'] as num?)?.toInt() ?? 100).clamp(0, 100),
      speed: speeds.contains(speed) ? speed! : 1,
      motion: data['motion'] != false,
    );
  }
}

class LocalPlaylist {
  const LocalPlaylist({
    required this.id,
    required this.name,
    this.trackIds = const [],
  });
  final String id, name;
  final List<String> trackIds;
  factory LocalPlaylist.fromMap(Map<Object?, Object?> map) => LocalPlaylist(
    id: map['id'] as String,
    name: map['name'] as String,
    trackIds: ((map['trackIds'] as List?) ?? []).whereType<String>().toList(
      growable: false,
    ),
  );
}

String formatTime(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
