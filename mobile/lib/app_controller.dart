import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models.dart';
import 'platform_bridge.dart';

class MusicController extends ChangeNotifier {
  MusicController(this.platform);
  final MusicPlatform platform;
  final lightTheme = ValueNotifier<bool>(false);
  StreamSubscription<LibrarySnapshot>? _subscription;
  LibrarySnapshot snapshot = const LibrarySnapshot();
  OfflineTrack? preview;
  String? error;
  bool loading = true, resolving = false, downloading = false;
  bool openingSource = false;
  int _playRequest = 0;
  (List<String>, int)? _sourceQueue;
  List<PlaybackQueueItem> _sourceQueueItems = const [];
  List<PlaybackQueueItem> get sourceQueueItems => _sourceQueueItems;
  int? get sourceQueueIndex => _sourceQueue?.$2;
  bool _disposed = false;
  int _request = 0, _shareSequence = 0;
  final Set<String> _pending = {};
  List<OfflineTrack> get tracks => snapshot.tracks;
  PlaybackState get playback => snapshot.playback;
  bool isPending(String id) => _pending.contains(id);

  bool canSkip(int direction) {
    if (openingSource || (direction != -1 && direction != 1)) return false;
    if (_sourceQueue case (final queue, final index)) {
      final target = index + direction;
      return target >= 0 && target < queue.length;
    }
    return direction < 0 ? playback.hasPrevious : playback.hasNext;
  }

  Future<void> initialize() async {
    if (_subscription != null) return;
    _subscription = platform.events.listen(
      _accept,
      onError: (Object e) {
        _setError(e);
      },
    );
    try {
      _accept(await platform.getState());
    } catch (e) {
      _setError(e);
    } finally {
      loading = false;
      _notify();
    }
  }

  void _accept(LibrarySnapshot next) {
    if (_disposed) return;
    snapshot = next;
    lightTheme.value = next.preferences.light;
    loading = !next.initialized;
    _notify();
    if (next.incomingText != null && next.shareSequence > _shareSequence) {
      _shareSequence = next.shareSequence;
      unawaited(inspect(next.incomingText!));
    }
  }

  Future<void> inspect(String input, {bool soundCloudOnly = false}) async {
    final request = ++_request;
    preview = null;
    error = null;
    resolving = true;
    _notify();
    try {
      final source = SourceLink.parse(input);
      if (soundCloudOnly && source.provider != 'soundcloud') {
        throw const FormatException('Hãy nhập link một bài SoundCloud.');
      }
      final result = await platform.resolve(source.url);
      if (!_disposed && request == _request) preview = result;
    } catch (e) {
      if (!_disposed && request == _request) _setError(e);
    } finally {
      if (!_disposed && request == _request) {
        resolving = false;
        _notify();
      }
    }
  }

  void dismissPreview() {
    _request++;
    preview = null;
    resolving = false;
    _notify();
  }

  Future<void> downloadPreview() async {
    final track = preview;
    if (track == null || downloading) return;
    downloading = true;
    _notify();
    if (await _perform(() => platform.enqueue(track.id))) {
      // A new preview can arrive while Android accepts this request.
      if (preview?.id == track.id) preview = null;
    }
    downloading = false;
    _notify();
  }

  Future<void> retry(OfflineTrack track) =>
      _forTrack(track.id, () => platform.retry(track.id));
  Future<void> remove(OfflineTrack track) =>
      _forTrack(track.id, () => platform.remove(track.id));
  Future<void> play(OfflineTrack track, {List<String>? queueIds}) {
    if (isPending(track.id)) return Future.value();
    final request = ++_playRequest;
    openingSource = false;
    return _forTrack(track.id, () async {
      await platform.play(track.id, queueIds: queueIds);
      if (request == _playRequest) {
        _sourceQueue = null;
        _sourceQueueItems = const [];
      }
    });
  }

  Future<void> playSource(
    String input, {
    Iterable<String> queue = const [],
    Iterable<PlaybackQueueItem> queueItems = const [],
  }) async {
    try {
      final source = SourceLink.parse(input).url;
      final urls = queue.toSet().toList(growable: false);
      final index = urls.indexOf(source);
      final metadata = {for (final item in queueItems) item.url: item};
      final items = [
        for (final url in urls)
          metadata[url] ??
              PlaybackQueueItem(
                url: url,
                title: Uri.tryParse(url)?.host ?? 'Bài hát',
                artist: '',
              ),
      ];
      await _openSource(
        source,
        index < 0 ? null : (urls, index),
        queueItems: items,
      );
    } on FormatException catch (error) {
      _setError(error);
    }
  }

  Future<void> _openSource(
    String url,
    (List<String>, int)? selection, {
    List<PlaybackQueueItem>? queueItems,
  }) async {
    final request = ++_playRequest;
    openingSource = true;
    error = null;
    _notify();
    try {
      await platform.playSource(url);
      if (request == _playRequest) {
        _sourceQueue = selection;
        _sourceQueueItems = selection == null
            ? const []
            : queueItems ?? _sourceQueueItems;
      }
    } catch (e) {
      if (request == _playRequest) _setError(e);
    } finally {
      if (request == _playRequest) {
        openingSource = false;
        _notify();
      }
    }
  }

  Future<void> createPlaylist(String name, {OfflineTrack? initialTrack}) async {
    await _perform(
      () => platform.createPlaylist(name, trackId: initialTrack?.id),
    );
  }

  Future<void> deletePlaylist(String id) async {
    await _perform(() => platform.deletePlaylist(id));
  }

  Future<void> addToPlaylist(String playlistId, OfflineTrack track) async {
    await _perform(() => platform.addToPlaylist(playlistId, track.id));
  }

  Future<void> removeFromPlaylist(String playlistId, OfflineTrack track) async {
    await _perform(() => platform.removeFromPlaylist(playlistId, track.id));
  }

  final _liked = <String>{};
  bool isLiked(String? id) => _liked.contains(id);
  void toggleLiked(String id) {
    if (!_liked.add(id)) _liked.remove(id);
    _notify();
  }

  bool repeatOne = false;
  Future<void> toggleRepeat() async {
    final target = !repeatOne;
    if (platform case final AndroidMusicPlatform android) {
      if (!await _perform(() => android.setRepeatOne(target))) return;
    }
    repeatOne = target;
    _notify();
  }

  Future<bool> exportCoverMp4(String url, String title) async {
    if (platform case final AndroidMusicPlatform android) {
      return android.exportCoverMp4(url, title);
    }
    return false;
  }

  Future<bool> shareTrack(String url) async {
    if (platform case final AndroidMusicPlatform android) {
      return _perform(() => android.shareTrack(url));
    }
    return false;
  }

  Future<void> togglePlay() async {
    await _perform(platform.togglePlay);
  }

  Future<void> seek(int positionMs) async {
    await _perform(() => platform.seek(positionMs));
  }

  Future<void> skip(int direction) async {
    if (!canSkip(direction)) return;
    if (_sourceQueue case (final queue, final index)) {
      final target = index + direction;
      await _openSource(queue[target], (
        queue,
        target,
      ), queueItems: _sourceQueueItems);
    } else {
      await _perform(() => platform.skip(direction));
    }
  }

  Future<void> openWebsite() async {
    await _perform(platform.openWebsite);
  }

  Future<void> updatePreferences(Map<String, Object> changes) async {
    await _perform(() => platform.updatePreferences(changes));
  }

  Future<void> authenticate(
    String username,
    String password, {
    String? displayName,
  }) => platform.authenticate(username, password, displayName: displayName);

  Future<void> startGoogle() => platform.startGoogle();
  Future<void> signOut() async {
    await _perform(platform.signOut);
  }

  Future<void> clearAccountError() async {
    await _perform(platform.clearAccountError);
  }

  Future<void> _forTrack(String id, Future<void> Function() action) async {
    if (!_pending.add(id)) return;
    _notify();
    await _perform(action);
    _pending.remove(id);
    _notify();
  }

  Future<bool> _perform(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e) {
      _setError(e);
      return false;
    }
  }

  void clearError() {
    error = null;
    _notify();
  }

  void _setError(Object e) {
    if (_disposed) return;
    error = switch (e) {
      FormatException() => e.message,
      PlatformException() =>
        e.message ?? 'Không thể thực hiện thao tác. Hãy thử lại.',
      MissingPluginException() =>
        'Chức năng tải và phát nhạc cần chạy trên Android.',
      _ => 'Không thể kết nối bộ phát. Hãy mở lại ứng dụng và thử lại.',
    };
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    lightTheme.dispose();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
