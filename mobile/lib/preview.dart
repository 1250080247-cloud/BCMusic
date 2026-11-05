import 'dart:async';

import 'package:flutter/widgets.dart';

import 'app_controller.dart';
import 'discovery.dart';
import 'main.dart' show BCMusicApp;
import 'models.dart';
import 'platform_bridge.dart';

const _songs = [
  DiscoverySong(
    id: 'M7lc1UVf-VE',
    title: 'Sau cơn mưa',
    artist: 'BCMusic Preview',
  ),
  DiscoverySong(
    id: 'jNQXAC9IVRw',
    title: 'Một ngày bình yên',
    artist: 'BCMusic Preview',
  ),
  DiscoverySong(
    id: 'aqz-KE-bpKQ',
    title: 'Giai điệu về đêm',
    artist: 'BCMusic Preview',
  ),
  DiscoverySong(
    id: 'dQw4w9WgXcQ',
    title: 'Qua ô cửa sổ',
    artist: 'BCMusic Preview',
  ),
  DiscoverySong(
    id: 'kJQP7kiw5Fk',
    title: 'Phố lên đèn',
    artist: 'BCMusic Preview',
  ),
  DiscoverySong(
    id: '9bZkp7q19f0',
    title: 'Chuyến xe cuối',
    artist: 'BCMusic Preview',
  ),
  DiscoverySong(
    id: 'JGwWNGJdvx8',
    title: 'Tháng mười một',
    artist: 'BCMusic Preview',
  ),
  DiscoverySong(
    id: 'OPf0YbXqDm0',
    title: 'Bên kia thành phố',
    artist: 'BCMusic Preview',
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

class _PreviewDiscovery implements DiscoveryRepository {
  @override
  Future<List<DiscoverySong>> feed(String query, String order) async => _songs;
  @override
  Future<List<DiscoverySong>> search(String query) async => _songs
      .where((song) => song.title.toLowerCase().contains(query.toLowerCase()))
      .toList();
  @override
  void dispose() {}
}

class _PreviewPlatform extends AndroidMusicPlatform {
  final _updates = StreamController<LibrarySnapshot>.broadcast();
  DiscoverySong? _song;
  var _position = 38000;
  var _playing = false;
  var _preferences = const AppPreferences(volume: 65);

  final _downloads = <String, OfflineTrack>{};
  final _playlists = <String, LocalPlaylist>{};
  int _playlistSequence = 0;

  AccountProfile? _account = const AccountProfile(
    name: "Người nghe nhạc",
    username: "bcmusic-preview",
  );

  LibrarySnapshot get _state => LibrarySnapshot(
    account: _account,
    tracks: _downloads.values.toList(),
    playlists: _playlists.values.toList(),
    preferences: _preferences,
    playback: PlaybackState(
      trackId: _song?.id,
      isPlaying: _playing,
      positionMs: _position,
      durationMs: 282000,
      offline: false,
    ),
  );

  @override
  Stream<LibrarySnapshot> get events => _updates.stream;
  @override
  Future<LibrarySnapshot> getState() async => _state;
  @override
  Future<void> playSource(String url) async {
    _song = _songs.firstWhere((song) => song.sourceUrl == url);
    _position = 38000;
    _updates.add(_state);
  }

  @override
  Future<OfflineTrack> resolve(String url) async {
    final song = _songs.firstWhere((song) => song.sourceUrl == url);
    return OfflineTrack(
      id: song.id,
      title: song.title,
      artist: song.artist,
      sourceUrl: song.sourceUrl,
      provider: 'youtube',
      status: 'preview',
      artworkUrl: song.thumbnail,
    );
  }

  @override
  Future<void> enqueue(String id) async {
    final song = _songs.firstWhere((song) => song.id == id);
    final track = await resolve(song.sourceUrl);
    _downloads[id] = OfflineTrack.fromMap({
      ...track.toMap(),
      'status': 'completed',
    });
    _updates.add(_state);
  }

  @override
  Future<void> createPlaylist(String name, {String? trackId}) async {
    final id = '${++_playlistSequence}';
    _playlists[id] = LocalPlaylist(id: id, name: name, trackIds: [?trackId]);
    _updates.add(_state);
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
      ...changes,
    });
    _updates.add(_state);
  }
}
