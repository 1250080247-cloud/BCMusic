import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';

import 'app_controller.dart';
import 'discovery.dart';
import 'main.dart' show BCMusicApp;
import 'models.dart';
import 'platform_bridge.dart';

// Danh sách bài hát mẫu đồng bộ từ App.tsx
const _songs = [
  DiscoverySong(
    id: 'M7lc1UVf-VE',
    title: 'Chìm Sâu',
    artist: 'RPT MCK · Trung Trần',
    durationMs: 156000,
  ),
  DiscoverySong(
    id: 'jNQXAC9IVRw',
    title: 'Có em',
    artist: 'Madihu · Low G',
    durationMs: 217000,
  ),
  DiscoverySong(
    id: 'aqz-KE-bpKQ',
    title: 'Một Ngày Chẳng Nắng',
    artist: 'Pháo · Thịnh Suy',
    durationMs: 245000,
  ),
  DiscoverySong(
    id: 'dQw4w9WgXcQ',
    title: 'Nàng Thơ',
    artist: 'Hoàng Dũng',
    durationMs: 254000,
  ),
  DiscoverySong(
    id: 'kJQP7kiw5Fk',
    title: 'Bước Qua Nhau',
    artist: 'Vũ.',
    durationMs: 270000,
  ),
  DiscoverySong(
    id: '9bZkp7q19f0',
    title: 'Va Vào Giai Điệu Này',
    artist: 'RPT MCK',
    durationMs: 210000,
  ),
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = MusicController(_PreviewPlatform());
  unawaited(
    controller.initialize().then((_) async {
      await controller.playSource(
        _songs.first.sourceUrl,
        queue: _songs.map((song) => song.sourceUrl),
        queueItems: _songs.map(
          (song) => PlaybackQueueItem(
            url: song.sourceUrl,
            title: song.title,
            artist: song.artist,
            artworkUrl: song.thumbnail,
          ),
        ),
      );
    }),
  );
  runApp(
    BCMusicApp(
      controller: controller,
      phonePreview: true,
      discovery: DiscoveryController(_PreviewDiscovery()),
    ),
  );
}

class _PreviewDiscovery implements DiscoveryRepository, SearchSuggestions {
  @override
  Future<List<DiscoverySong>> feed(String query, String order) async => _songs;
  @override
  Future<List<DiscoverySong>> search(String query) async => _songs
      .where(
        (song) => '${song.title} ${song.artist}'.toLowerCase().contains(
          query.toLowerCase(),
        ),
      )
      .toList();
  @override
  Future<List<String>> suggestions(String query) async =>
      (await search(query)).map((song) => song.title).take(6).toList();
  @override
  void dispose() {}
}

class _PreviewPlatform extends AndroidMusicPlatform {
  final _updates = StreamController<LibrarySnapshot>.broadcast();
  DiscoverySong? _song;
  var _position = 38000;
  var _playing = false;
  var _preferences = const AppPreferences(volume: 75);
  final _searches = <String>['Chìm Sâu', 'Hoàng Dũng', 'Nhạc lofi'];
  final _history = <String, OfflineTrack>{};
  final _favorites = <String, Map<String, String>>{
    for (final song in _songs.take(2))
      song.id: {
        'id': song.id,
        'title': song.title,
        'artist': song.artist,
        'sourceUrl': song.sourceUrl,
        'thumbnail': song.thumbnail,
      },
  };

  @override
  Stream<List<double>> get spectrum => _previewSpectrum;

  late final Stream<List<double>> _previewSpectrum = Stream.multi((stream) {
    const samples = [
      [.24, .73, .38],
      [.71, .35, .57],
      [.45, .28, .65],
      [.85, .53, .24],
    ];
    final timer = Timer.periodic(const Duration(milliseconds: 125), (tick) {
      stream.add(samples[tick.tick % samples.length]);
    });
    stream.onCancel = timer.cancel;
  }, isBroadcast: true);

  final _downloads = <String, OfflineTrack>{
    for (final song in _songs.take(3))
      song.id: OfflineTrack(
        id: song.id,
        title: song.title,
        artist: song.artist,
        sourceUrl: song.sourceUrl,
        provider: 'youtube',
        status: 'completed',
        bytes: 4850000,
        durationMs: song.durationMs,
        artworkUrl: song.thumbnail,
      ),
  };

  final _playlists = <String, LocalPlaylist>{
    '1': LocalPlaylist(
      id: '1',
      name: 'Một mình cũng vui',
      trackIds: _songs.take(3).map((s) => s.id).toList(),
    ),
  };

  final _webPlaylists =
      <String, ({String name, Map<String, Map<String, String>> songs})>{
        'web_1': (
          name: 'Những ngày rất chill',
          songs: {
            for (final song in _songs.take(4))
              song.id: {
                'id': song.id,
                'title': song.title,
                'artist': song.artist,
                'sourceUrl': song.sourceUrl,
                'thumbnail': song.thumbnail,
              },
          },
        ),
        'web_2': (
          name: 'On repeat',
          songs: {
            for (final song in _songs.skip(1).take(4))
              song.id: {
                'id': song.id,
                'title': song.title,
                'artist': song.artist,
                'sourceUrl': song.sourceUrl,
                'thumbnail': song.thumbnail,
              },
          },
        ),
      };
  int _playlistSequence = 3;

  AccountProfile? _account = const AccountProfile(
    name: 'An Nguyễn',
    username: 'an.nguyen',
  );

  LibrarySnapshot get _state => LibrarySnapshot(
    account: _account,
    tracks: _downloads.values.toList(),
    playlists: _playlists.values.toList(),
    searchHistory: List.of(_searches),
    listeningHistory: _history.values.toList().reversed.toList(),
    preferences: _preferences,
    playback: PlaybackState(
      trackId: _song?.id,
      track: _song == null
          ? null
          : OfflineTrack(
              id: _song!.id,
              title: _song!.title,
              artist: _song!.artist,
              sourceUrl: _song!.sourceUrl,
              provider: 'youtube',
              status: 'streaming',
              durationMs: _song!.durationMs,
              artworkUrl: _song!.thumbnail,
            ),
      isPlaying: _playing,
      positionMs: _position,
      durationMs: _song?.durationMs ?? 240000,
      offline: false,
      repeatMode: _repeatMode,
      shuffle: _shuffle,
    ),
  );

  @override
  Stream<LibrarySnapshot> get events => _updates.stream;
  @override
  Future<LibrarySnapshot> getState() async => _state;
  @override
  Future<void> playSource(String url, {bool autoTransition = false}) async {
    _song = _songs.firstWhere(
      (song) => song.sourceUrl == url,
      orElse: () => _songs.first,
    );
    _playing = true;
    _position = 24000;
    _history.remove(url);
    _history[url] = _state.playback.track!;
    _updates.add(_state);
  }

  @override
  Future<void> recordSearch(String query) async {
    _searches.removeWhere((term) => term.toLowerCase() == query.toLowerCase());
    _searches.insert(0, query);
    if (_searches.length > 12) _searches.removeLast();
    _updates.add(_state);
  }

  @override
  Future<OfflineTrack> resolve(String url) async {
    final song = _songs.firstWhere(
      (song) => song.sourceUrl == url,
      orElse: () => _songs.first,
    );
    return OfflineTrack(
      id: song.id,
      title: song.title,
      artist: song.artist,
      sourceUrl: song.sourceUrl,
      provider: 'youtube',
      status: 'preview',
      durationMs: song.durationMs,
      artworkUrl: song.thumbnail,
    );
  }

  @override
  Future<PlaylistPreview> resolvePlaylist(String url) async {
    return PlaylistPreview(
      id: 'preview_playlist',
      name: 'SoundCloud Preview Playlist',
      uploader: 'SoundCloud Artist',
      sourceUrl: url,
      provider: 'soundcloud',
      tracks: _songs
          .take(3)
          .map(
            (s) => OfflineTrack(
              id: 'soundcloud_${s.id}',
              title: s.title,
              artist: s.artist,
              sourceUrl: s.sourceUrl,
              provider: 'soundcloud',
              status: 'preview',
              durationMs: s.durationMs,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<LocalPlaylist> importSoundCloudPlaylist({
    required String name,
    required String sourceUrl,
    required List<OfflineTrack> tracks,
  }) async {
    final id = '${++_playlistSequence}';
    final playlist = LocalPlaylist(
      id: id,
      name: name,
      trackIds: tracks.map((t) => t.id).toList(),
    );
    _playlists[id] = playlist;
    for (final track in tracks) {
      _downloads[track.id] = OfflineTrack.fromMap({
        ...track.toMap(),
        'status': 'completed',
      });
    }
    _updates.add(_state);
    return playlist;
  }

  @override
  Future<void> enqueue(String id) async {
    final song = _songs.firstWhere(
      (song) => song.id == id,
      orElse: () => _songs.first,
    );
    final track = await resolve(song.sourceUrl);
    _downloads[id] = OfflineTrack.fromMap({
      ...track.toMap(),
      'status': 'completed',
      'bytes': 4600000,
    });
    _updates.add(_state);
  }

  @override
  Future<void> createPlaylist(
    String name, {
    String? trackId,
    String? url,
    bool enqueueIfMissing = false,
  }) async {
    final id = '${++_playlistSequence}';
    _playlists[id] = LocalPlaylist(id: id, name: name, trackIds: [?trackId]);
    _updates.add(_state);
  }

  @override
  Future<void> enqueueAndAddToPlaylist(
    String playlistId,
    String id, {
    String? url,
  }) async {
    await addToPlaylist(playlistId, id);
  }

  @override
  Future<void> addToPlaylist(String playlistId, String id) async {
    final playlist = _playlists[playlistId]!;
    _playlists[playlistId] = LocalPlaylist(
      id: playlist.id,
      name: playlist.name,
      trackIds: {...playlist.trackIds, id}.toList(),
    );
    _updates.add(_state);
  }

  @override
  Future<String?> getProfileCollections() async => jsonEncode({
    'favorites': _favorites.values.toList().reversed.toList(),
    'playlists': [
      for (final entry in _webPlaylists.entries)
        {
          'id': entry.key,
          'name': entry.value.name,
          'songs': entry.value.songs.values.toList(),
        },
    ],
  });

  @override
  Future<List<String>> getFavoriteIds() async => _favorites.keys.toList();

  @override
  Future<void> setFavorite(
    String accountId,
    Map<String, String> song,
    bool liked,
  ) async {
    final id = song['id']!;
    if (liked) {
      _favorites[id] = song;
    } else {
      _favorites.remove(id);
    }
  }

  @override
  Future<void> saveWebPlaylistSong(
    Map<String, String> song, {
    String? playlistId,
    String? playlistName,
  }) async {
    final id = playlistId ?? '${++_playlistSequence}';
    final playlist = _webPlaylists.putIfAbsent(
      id,
      () => (
        name: playlistName ?? 'Playlist mới',
        songs: <String, Map<String, String>>{},
      ),
    );
    if (song['id'] != null) {
      playlist.songs[song['id']!] = song;
    }
  }

  @override
  Future<void> removeWebPlaylistSong(String playlistId, String songId) async {
    _webPlaylists[playlistId]?.songs.remove(songId);
  }

  @override
  Future<void> updateProfile(String displayName, {String? image}) async {
    final account = _account;
    if (account == null) return;
    _account = AccountProfile(name: displayName, username: account.username);
    _updates.add(_state);
  }

  @override
  Future<void> play(String id, {List<String>? queueIds}) =>
      playSource(_songs.firstWhere((song) => song.id == id).sourceUrl);

  @override
  Future<void> removeFromPlaylist(String playlistId, String id) async {
    final playlist = _playlists[playlistId]!;
    _playlists[playlistId] = LocalPlaylist(
      id: playlist.id,
      name: playlist.name,
      trackIds: playlist.trackIds.where((trackId) => trackId != id).toList(),
    );
    _updates.add(_state);
  }

  @override
  Future<void> signOut() async {
    _account = null;
    _updates.add(_state);
  }

  @override
  Future<void> authenticate(
    String username,
    String password, {
    String? displayName,
  }) async {
    _account = AccountProfile(
      name: displayName ?? username,
      username: username,
    );
    _updates.add(_state);
  }

  @override
  Future<void> setRepeatOne(bool enabled) async {}

  @override
  Future<void> togglePlay() async {
    _playing = !_playing;
    _updates.add(_state);
  }

  @override
  Future<void> pause() async {
    _playing = false;
    _updates.add(_state);
  }

  final _lyricsCache = <String, String>{};
  static final String _defaultSyncedLyrics = jsonEncode({
    'status': 'synced',
    'source': 'BCMusic Concept',
    'plainLyrics': '',
    'lines': [
      {'timeMs': 0, 'text': 'Khi đêm buông xuống thật êm'},
      {'timeMs': 12000, 'text': 'Một giai điệu khẽ gọi tên'},
      {'timeMs': 22000, 'text': 'Để giai điệu dẫn lối'},
      {'timeMs': 35000, 'text': 'Để cảm xúc lên tiếng'},
      {'timeMs': 50000, 'text': 'Chạm vào những giấc mơ'},
      {'timeMs': 68000, 'text': 'Và để tâm hồn tự do'},
    ],
  });

  @override
  Future<void> saveLyrics(String trackId, String data) async {
    _lyricsCache[trackId] = data;
  }

  @override
  Future<String?> getLyrics(String trackId) async =>
      _lyricsCache[trackId] ?? _defaultSyncedLyrics;

  @override
  Future<void> setSleepTimer(int? minutes, {bool atEndOfTrack = false}) async {}

  @override
  Future<void> cancelSleepTimer() async {}

  var _repeatMode = 'off';
  var _shuffle = false;

  @override
  Future<void> setRepeatMode(String mode) async {
    _repeatMode = mode;
    _preferences = AppPreferences.fromMap({
      'light': _preferences.light,
      'volume': _preferences.volume,
      'speed': _preferences.speed,
      'motion': _preferences.motion,
      'repeatMode': _repeatMode,
      'shuffle': _shuffle,
      'downloadQuality': _preferences.downloadQuality,
      'crossfade': _preferences.crossfade,
    });
    _updates.add(_state);
  }

  @override
  Future<void> setShuffle(bool enabled) async {
    _shuffle = enabled;
    _preferences = AppPreferences.fromMap({
      'light': _preferences.light,
      'volume': _preferences.volume,
      'speed': _preferences.speed,
      'motion': _preferences.motion,
      'repeatMode': _repeatMode,
      'shuffle': _shuffle,
      'downloadQuality': _preferences.downloadQuality,
      'crossfade': _preferences.crossfade,
    });
    _updates.add(_state);
  }

  @override
  Future<void> removeQueueItem(int index) async {}

  @override
  Future<void> reorderQueue(int oldIndex, int newIndex) async {}

  @override
  Future<void> seek(int positionMs) async {
    _position = positionMs;
    _updates.add(_state);
  }

  @override
  Future<void> updatePreferences(Map<String, Object> changes) async {
    _preferences = AppPreferences.fromMap({
      'light': _preferences.light,
      'volume': _preferences.volume,
      'speed': _preferences.speed,
      'motion': _preferences.motion,
      'repeatMode': _preferences.repeatMode,
      'shuffle': _preferences.shuffle,
      'downloadQuality': _preferences.downloadQuality,
      'crossfade': _preferences.crossfade,
      ...changes,
    });
    _updates.add(_state);
  }
}