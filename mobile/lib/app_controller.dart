import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'lyrics.dart';
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
  (List<String>, int)? _originalSourceQueue;
  List<PlaybackQueueItem>? _originalSourceQueueItems;
  List<PlaybackQueueItem> get sourceQueueItems => _sourceQueueItems;
  int? get sourceQueueIndex => _sourceQueue?.$2;
  List<String>? _offlineQueueIds;
  final _queuedBeforePlayback = <PlaybackQueueItem>[];
  String? _handledEnd;

  PlaybackQueueItem? _queueItemFor(OfflineTrack? track) => track == null
      ? null
      : PlaybackQueueItem(
          url: track.sourceUrl,
          title: track.title,
          artist: track.artist,
          artworkUrl: track.artworkUrl,
        );

  bool enqueueSong(PlaybackQueueItem item) {
    if (openingSource) return false;
    final current = _queueItemFor(
      playback.track ??
          tracks.where((track) => track.id == playback.trackId).firstOrNull,
    );
    if (_sourceQueue case (final urls, final index)) {
      if (urls.contains(item.url)) return false;
      _sourceQueue = ([...urls, item.url], index);
      _sourceQueueItems = [..._sourceQueueItems, item];
      if (_originalSourceQueue != null && _originalSourceQueueItems != null) {
        _originalSourceQueue = (
          [..._originalSourceQueue!.$1, item.url],
          _originalSourceQueue!.$2,
        );
        _originalSourceQueueItems = [..._originalSourceQueueItems!, item];
      }
    } else if (current != null) {
      final ready = {
        if (playback.offline)
          for (final track in tracks.where((track) => track.isReady))
            track.id: track,
      };
      final entries = <PlaybackQueueItem>[
        for (final id in _offlineQueueIds ?? ready.keys)
          ?_queueItemFor(ready[id]),
      ];
      final currentIndex = entries.indexWhere(
        (entry) => entry.url == current.url,
      );
      if (currentIndex < 0) entries.insert(0, current);
      if (entries.any((entry) => entry.url == item.url)) return false;
      entries.add(item);
      final entryUrls = entries.map((entry) => entry.url).toList();
      final currentPos = currentIndex < 0 ? 0 : currentIndex;
      _sourceQueue = (entryUrls, currentPos);
      _sourceQueueItems = entries;
      _originalSourceQueue = (List.of(entryUrls), currentPos);
      _originalSourceQueueItems = List.of(entries);
    } else {
      if (_queuedBeforePlayback.any((entry) => entry.url == item.url)) {
        return false;
      }
      _queuedBeforePlayback.add(item);
    }
    _notify();
    return true;
  }

  late final LyricsRepository lyricsRepository =
      LyricsRepository(platform: platform);

  Future<void> prefetchLyrics(OfflineTrack track) async {
    try {
      await lyricsRepository.getLyrics(
        trackId: track.id,
        rawTitle: track.title,
        rawArtist: track.artist,
        durationMs: track.durationMs,
      );
    } catch (_) {}
  }

  Timer? _sleepTimer;
  DateTime? _sleepTimerEnd;
  int? _sleepTimerMinutes;
  bool _sleepAtEndOfTrack = false;
  String? _sleepTargetTrackId;

  bool get sleepTimerActive => _sleepTimerEnd != null || _sleepAtEndOfTrack;
  int? get sleepTimerMinutes => _sleepTimerMinutes;
  bool get sleepAtEndOfTrack => _sleepAtEndOfTrack;
  Duration? get sleepTimerRemaining {
    if (_sleepTimerEnd == null) return null;
    final diff = _sleepTimerEnd!.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void setSleepTimer(int? minutes, {bool atEndOfTrack = false}) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    if (atEndOfTrack) {
      _sleepAtEndOfTrack = true;
      _sleepTimerMinutes = null;
      _sleepTimerEnd = null;
      _sleepTargetTrackId = playback.trackId;
      unawaited(platform.setSleepTimer(null, atEndOfTrack: true));
      _notify();
      return;
    }
    if (minutes != null) {
      _sleepAtEndOfTrack = false;
      _sleepTimerMinutes = minutes;
      _sleepTimerEnd = DateTime.now().add(Duration(minutes: minutes));
      unawaited(platform.setSleepTimer(minutes, atEndOfTrack: false));
      _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        checkSleepTimer();
      });
      _notify();
      return;
    }
    cancelSleepTimer();
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepTimerEnd = null;
    _sleepTimerMinutes = null;
    _sleepAtEndOfTrack = false;
    _sleepTargetTrackId = null;
    unawaited(platform.cancelSleepTimer());
    _notify();
  }

  bool checkSleepTimer() {
    if (!sleepTimerActive) return false;

    bool shouldStop = false;

    if (_sleepAtEndOfTrack) {
      if ((_sleepTargetTrackId != null && playback.trackId != _sleepTargetTrackId) ||
          playback.ended) {
        shouldStop = true;
      }
    } else if (_sleepTimerEnd != null) {
      if (!DateTime.now().isBefore(_sleepTimerEnd!)) {
        shouldStop = true;
      }
    }

    if (shouldStop) {
      _handledEnd = playback.trackId ?? _sleepTargetTrackId;
      unawaited(platform.pause());
      cancelSleepTimer();
      return true;
    } else {
      _notify();
      return false;
    }
  }

  bool _disposed = false;
  int _request = 0, _shareSequence = 0;
  final Set<String> _pending = {};
  List<OfflineTrack> get tracks => snapshot.tracks;
  void recordSearch(String query) {
    if (platform case final AndroidMusicPlatform android) {
      unawaited(_perform(() => android.recordSearch(query)));
    }
  }

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
    if (next.preferences.repeatMode != snapshot.preferences.repeatMode) {
      repeatMode = next.preferences.repeatMode;
    }
    if (next.preferences.shuffle != snapshot.preferences.shuffle) {
      shuffle = next.preferences.shuffle;
      if (_sourceQueue != null) {
        if (shuffle) {
          _applyOnlineShuffle();
        } else {
          _restoreOnlineOrder();
        }
      }
    }
    snapshot = next;
    final account = next.account;
    final key = account?.id ?? account?.username;
    if (key != _favoriteAccount) {
      _favoriteAccount = key;
      _favoriteSession++;
      _favoriteLoad = null;
      _favoriteIds = null;
    }
    if (!next.playback.ended) _handledEnd = null;
    if (!openingSource && next.playback.track != null) {
      if (_sourceQueue case (final urls, final index)) {
        final actual = urls.indexOf(next.playback.track!.sourceUrl);
        if (actual >= 0 && actual != index) _sourceQueue = (urls, actual);
      }
    }
    final stoppedByTimer = checkSleepTimer();
    if (!stoppedByTimer &&
        !openingSource &&
        !repeatOne &&
        next.playback.ended &&
        _sourceQueue != null &&
        _handledEnd != next.playback.trackId) {
      if (canSkip(1)) {
        _handledEnd = next.playback.trackId;
        unawaited(skip(1, autoTransition: true));
      } else if (repeatMode == 'all' && _sourceQueueItems.isNotEmpty) {
        _handledEnd = next.playback.trackId;
        unawaited(skipToQueueIndex(0, autoTransition: true));
      }
    }
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
      unawaited(prefetchLyrics(track));
      // A new preview can arrive while Android accepts this request.
      if (preview?.id == track.id) preview = null;
    }
    downloading = false;
    _notify();
  }

  Future<void> downloadSource(String url) async {
    final request = _request + 1;
    await inspect(url);
    if (!_disposed && request == _request) await downloadPreview();
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
        _originalSourceQueue = null;
        _originalSourceQueueItems = null;
        _offlineQueueIds = queueIds;
        final pending = List<PlaybackQueueItem>.of(_queuedBeforePlayback);
        _queuedBeforePlayback.clear();
        if (pending.isNotEmpty) {
          final ready = {
            for (final item in tracks.where((item) => item.isReady))
              item.id: item,
          };
          final items = <PlaybackQueueItem>[
            for (final id in queueIds ?? ready.keys) ?_queueItemFor(ready[id]),
          ];
          if (!items.any((item) => item.url == track.sourceUrl)) {
            items.insert(0, _queueItemFor(track)!);
          }
          for (final entry in pending) {
            if (!items.any((item) => item.url == entry.url)) items.add(entry);
          }
          _sourceQueue = (
            items.map((item) => item.url).toList(),
            items.indexWhere((item) => item.url == track.sourceUrl),
          );
          _sourceQueueItems = items;
        }
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
      final urls = <String>{
        ...queue,
        if (queue.isEmpty && _queuedBeforePlayback.isNotEmpty) source,
        ..._queuedBeforePlayback.map((item) => item.url),
      }.toList(growable: false);
      final index = urls.indexOf(source);
      final metadata = {
        for (final item in [...queueItems, ..._queuedBeforePlayback])
          item.url: item,
      };
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
      if (error == null && sourceQueueIndex != null) {
        _queuedBeforePlayback.removeWhere((item) => urls.contains(item.url));
      }
    } on FormatException catch (error) {
      _setError(error);
    }
  }

  Future<void> _openSource(
    String url,
    (List<String>, int)? selection, {
    List<PlaybackQueueItem>? queueItems,
    bool autoTransition = false,
  }) async {
    final request = ++_playRequest;
    openingSource = true;
    error = null;
    _notify();
    try {
      await platform.playSource(url, autoTransition: autoTransition);
      if (request == _playRequest) {
        final isAdvancingSameQueue = _sourceQueue != null &&
            selection != null &&
            _sourceQueue!.$1.length == selection.$1.length &&
            _sourceQueue!.$1.firstOrNull == selection.$1.firstOrNull;

        _sourceQueue = selection;
        _sourceQueueItems = selection == null
            ? const []
            : queueItems ?? _sourceQueueItems;

        if (!isAdvancingSameQueue) {
          _originalSourceQueue = _sourceQueue;
          _originalSourceQueueItems = List.of(_sourceQueueItems);
          if (shuffle && _sourceQueue != null) {
            _applyOnlineShuffle();
          }
        }
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

  Future<void> createPlaylist(
    String name, {
    OfflineTrack? initialTrack,
    String? trackId,
    String? url,
    bool enqueueIfMissing = false,
  }) async {
    final id = initialTrack?.id ?? trackId;
    final trackUrl = url ?? initialTrack?.sourceUrl;
    await _perform(
      () => platform.createPlaylist(
        name,
        trackId: id,
        url: trackUrl,
        enqueueIfMissing: enqueueIfMissing,
      ),
    );
  }

  Future<void> enqueueAndAddToPlaylist(
    String playlistId,
    String trackId, {
    String? url,
  }) async {
    await _perform(
      () => platform.enqueueAndAddToPlaylist(playlistId, trackId, url: url),
    );
  }

  Future<void> playAccountPlaylist(
    AccountPlaylist playlist, {
    bool shuffle = false,
  }) async {
    final items = playlist.songs.values.toList();
    if (items.isEmpty) return;
    final queue = List<PlaybackQueueItem>.from(items);
    if (shuffle) {
      queue.shuffle();
    }
    final first = queue.first;
    await playSource(
      first.url,
      queue: queue.map((e) => e.url),
      queueItems: queue,
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

  final _guestLikes = <String>{};
  String? _favoriteAccount;
  int _favoriteSession = 0;
  Set<String>? _favoriteIds;
  Future<void>? _favoriteLoad;
  bool savingFavorite = false;

  String? _favoriteId(OfflineTrack track) {
    if (track.provider == 'youtube') {
      return Uri.tryParse(track.sourceUrl)?.queryParameters['v'];
    }
    final match = RegExp(r'^soundcloud_(\d+)$').firstMatch(track.id);
    return match == null ? null : 'sc_${match[1]}';
  }

  bool isLiked(OfflineTrack? track) =>
      track != null &&
      (_favoriteAccount == null
          ? _guestLikes.contains(track.id)
          : _favoriteIds?.contains(_favoriteId(track)) == true);

  Future<void> refreshFavorites() async {
    final android = platform;
    final account = _favoriteAccount;
    if (android is! AndroidMusicPlatform || account == null || savingFavorite) {
      return;
    }
    if (_favoriteLoad case final pending?) return pending;
    final request = _loadFavorites(android, _favoriteSession);
    _favoriteLoad = request;
    try {
      await request;
    } finally {
      if (identical(_favoriteLoad, request)) _favoriteLoad = null;
    }
  }

  Future<void> _loadFavorites(AndroidMusicPlatform android, int session) async {
    try {
      final ids = await android.getFavoriteIds();
      if (!_disposed && _favoriteSession == session) {
        _favoriteIds = ids.toSet();
        _notify();
      }
    } on Exception {
      // The player stays available if favorites cannot be refreshed.
    }
  }

  Future<bool> toggleLiked(OfflineTrack track) async {
    final account = _favoriteAccount;
    final session = _favoriteSession;
    final android = platform;
    if (account == null) {
      if (!_guestLikes.add(track.id)) _guestLikes.remove(track.id);
      _notify();
      return true;
    }
    final id = _favoriteId(track);
    if (android is! AndroidMusicPlatform || id == null || savingFavorite) {
      return false;
    }
    if (_favoriteIds == null || _favoriteLoad != null) await refreshFavorites();
    final favorites = _favoriteIds;
    if (favorites == null ||
        session != _favoriteSession ||
        savingFavorite ||
        _disposed) {
      return false;
    }
    savingFavorite = true;
    _notify();
    final liked = !favorites.contains(id);
    final thumbnail =
        track.artworkUrl ??
        (track.provider == 'youtube'
            ? 'https://i.ytimg.com/vi/$id/hqdefault.jpg'
            : null);
    try {
      await android.setFavorite(account, {
        'id': id,
        'sourceUrl': track.sourceUrl,
        'title': track.title,
        'artist': track.artist,
        'thumbnail': ?thumbnail,
      }, liked);
      if (session == _favoriteSession) {
        if (liked) {
          favorites.add(id);
        } else {
          favorites.remove(id);
        }
      }
      return true;
    } on Exception {
      return false;
    } finally {
      savingFavorite = false;
      _notify();
    }
  }

  String repeatMode = 'off'; // 'off', 'all', 'one'
  bool shuffle = false;

  bool get repeatOne => repeatMode == 'one';
  bool get repeatAll => repeatMode == 'all';

  Future<void> setRepeatMode(String mode) async {
    final valid = (mode == 'all' || mode == 'one') ? mode : 'off';
    if (!await _perform(() => platform.setRepeatMode(valid))) return;
    repeatMode = valid;
    _notify();
  }

  Future<void> cycleRepeatMode() async {
    final next = switch (repeatMode) {
      'off' => 'all',
      'all' => 'one',
      _ => 'off',
    };
    await setRepeatMode(next);
  }

  Future<void> toggleRepeat() => cycleRepeatMode();

  Future<void> setShuffle(bool enabled) async {
    if (!await _perform(() => platform.setShuffle(enabled))) return;
    shuffle = enabled;
    if (_sourceQueue != null) {
      if (enabled) {
        _applyOnlineShuffle();
      } else {
        _restoreOnlineOrder();
      }
    }
    _notify();
  }

  Future<void> toggleShuffle() => setShuffle(!shuffle);

  void _applyOnlineShuffle({math.Random? random}) {
    if (_sourceQueue case (final urls, final currentIdx)) {
      if (urls.length <= 1) return;
      if (_originalSourceQueue == null || _originalSourceQueueItems == null) {
        _originalSourceQueue = (List.of(urls), currentIdx);
        _originalSourceQueueItems = List.of(_sourceQueueItems);
      }
      final currentItem = _sourceQueueItems[currentIdx];
      final currentUrl = urls[currentIdx];

      final beforeItems = _sourceQueueItems.sublist(0, currentIdx);
      final beforeUrls = urls.sublist(0, currentIdx);

      final upcomingItems = List<PlaybackQueueItem>.from(_sourceQueueItems.sublist(currentIdx + 1));
      if (upcomingItems.length > 1) {
        final original = List.of(upcomingItems);
        upcomingItems.shuffle(random);
        if (_queueItemsEqual(upcomingItems, original)) {
          final first = upcomingItems.removeAt(0);
          upcomingItems.insert(1, first);
        }
      }
      _sourceQueue = ([...beforeUrls, currentUrl, ...upcomingItems.map((e) => e.url)], currentIdx);
      _sourceQueueItems = [...beforeItems, currentItem, ...upcomingItems];
    }
  }

  void _restoreOnlineOrder() {
    if (_originalSourceQueueItems != null && _originalSourceQueue != null && _sourceQueue != null) {
      final currentUrl = _sourceQueue!.$1[_sourceQueue!.$2];
      final origIdx = _originalSourceQueueItems!.indexWhere((it) => it.url == currentUrl);
      if (origIdx >= 0) {
        _sourceQueue = (_originalSourceQueue!.$1, origIdx);
        _sourceQueueItems = List.of(_originalSourceQueueItems!);
      }
    }
  }

  bool _queueItemsEqual(List<PlaybackQueueItem> a, List<PlaybackQueueItem> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].url != b[i].url) return false;
    }
    return true;
  }

  Future<void> skipToQueueIndex(int targetIndex, {bool autoTransition = false}) async {
    if (_sourceQueue case (final queue, _)) {
      if (targetIndex >= 0 && targetIndex < queue.length) {
        await _openSource(
          queue[targetIndex],
          (queue, targetIndex),
          queueItems: _sourceQueueItems,
          autoTransition: autoTransition,
        );
      }
    } else if (playback.offline) {
      final ready = tracks.where((item) => item.isReady).toList();
      final ids = _offlineQueueIds ?? ready.map((t) => t.id).toList();
      if (targetIndex >= 0 && targetIndex < ids.length) {
        final track = ready.where((t) => t.id == ids[targetIndex]).firstOrNull;
        if (track != null) {
          await play(track, queueIds: ids);
        }
      }
    }
  }

  void removeQueueItem(int index) {
    if (_sourceQueue case (final urls, final currentIdx)) {
      if (index < 0 || index >= urls.length) return;
      if (urls.length <= 1) return;
      final removedUrl = urls[index];
      final newUrls = List<String>.from(urls)..removeAt(index);
      final newItems = List<PlaybackQueueItem>.from(_sourceQueueItems)..removeAt(index);
      int newIndex = currentIdx;
      if (index < currentIdx) {
        newIndex = currentIdx - 1;
      } else if (index == currentIdx) {
        newIndex = currentIdx.clamp(0, newUrls.length - 1);
      }
      _sourceQueue = (newUrls, newIndex);
      _sourceQueueItems = newItems;
      if (_originalSourceQueue != null && _originalSourceQueueItems != null) {
        final origUrls = List<String>.from(_originalSourceQueue!.$1);
        final origItems = List<PlaybackQueueItem>.from(_originalSourceQueueItems!);
        final oIdx = origUrls.indexOf(removedUrl);
        if (oIdx >= 0) {
          origUrls.removeAt(oIdx);
          origItems.removeAt(oIdx);
          int newOrigIdx = _originalSourceQueue!.$2;
          if (oIdx < newOrigIdx) {
            newOrigIdx = (newOrigIdx - 1).clamp(0, origUrls.length - 1);
          } else if (oIdx == newOrigIdx) {
            newOrigIdx = newOrigIdx.clamp(0, origUrls.length - 1);
          }
          _originalSourceQueue = (origUrls, newOrigIdx);
          _originalSourceQueueItems = origItems;
        }
      }
      _notify();
    } else if (playback.offline) {
      final ready = {
        for (final item in tracks.where((item) => item.isReady)) item.id: item,
      };
      final ids = _offlineQueueIds ?? ready.keys.toList();
      if (index >= 0 && index < ids.length && ids.length > 1) {
        final newIds = List<String>.from(ids)..removeAt(index);
        _offlineQueueIds = newIds;
        unawaited(_perform(() => platform.removeQueueItem(index)));
        _notify();
      }
    }
  }

  void reorderUpcomingQueue(int oldRelativeIndex, int newRelativeIndex) {
    if (_sourceQueue case (final urls, final currentIdx)) {
      var targetNew = newRelativeIndex;
      if (oldRelativeIndex < targetNew) {
        targetNew -= 1;
      }
      final offset = currentIdx + 1;
      final oldAbs = offset + oldRelativeIndex;
      final newAbs = offset + targetNew;
      if (oldAbs >= offset &&
          oldAbs < urls.length &&
          newAbs >= offset &&
          newAbs < urls.length) {
        final newUrls = List<String>.from(urls);
        final newItems = List<PlaybackQueueItem>.from(_sourceQueueItems);
        final movedUrl = newUrls.removeAt(oldAbs);
        final movedItem = newItems.removeAt(oldAbs);
        newUrls.insert(newAbs, movedUrl);
        newItems.insert(newAbs, movedItem);
        _sourceQueue = (newUrls, currentIdx);
        _sourceQueueItems = newItems;
        _notify();
      }
    } else if (playback.offline) {
      final ready = {
        for (final item in tracks.where((item) => item.isReady)) item.id: item,
      };
      final ids = _offlineQueueIds ?? ready.keys.toList();
      final currentIdx = ids.indexOf(playback.trackId ?? '');
      if (currentIdx >= 0) {
        var targetNew = newRelativeIndex;
        if (oldRelativeIndex < targetNew) {
          targetNew -= 1;
        }
        final offset = currentIdx + 1;
        final oldAbs = offset + oldRelativeIndex;
        final newAbs = offset + targetNew;
        if (oldAbs >= offset &&
            oldAbs < ids.length &&
            newAbs >= offset &&
            newAbs < ids.length) {
          final newIds = List<String>.from(ids);
          final movedId = newIds.removeAt(oldAbs);
          newIds.insert(newAbs, movedId);
          _offlineQueueIds = newIds;
          unawaited(_perform(() => platform.reorderQueue(oldAbs, newAbs)));
          _notify();
        }
      }
    }
  }

  List<PlaybackQueueItem> get currentQueueItems {
    if (_sourceQueueItems.isNotEmpty) {
      return _sourceQueueItems;
    }
    if (playback.offline) {
      final ready = {
        for (final item in tracks.where((item) => item.isReady))
          item.id: item,
      };
      final ids = _offlineQueueIds ?? ready.keys;
      return [
        for (final id in ids)
          if (ready[id] case final item?) ?_queueItemFor(item),
      ];
    }
    return const [];
  }

  int? get currentQueueIndex {
    if (_sourceQueue != null) {
      return _sourceQueue!.$2;
    }
    if (playback.offline) {
      final items = currentQueueItems;
      final currentUrl = playback.track?.sourceUrl;
      final idx = items.indexWhere((item) => item.url == currentUrl);
      return idx >= 0 ? idx : 0;
    }
    return null;
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

  Future<void> skip(int direction, {bool autoTransition = false}) async {
    if (!canSkip(direction)) return;
    if (_sourceQueue case (final queue, final index)) {
      final target = index + direction;
      await _openSource(
        queue[target],
        (queue, target),
        queueItems: _sourceQueueItems,
        autoTransition: autoTransition,
      );
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
    _sleepTimer?.cancel();
    lyricsRepository.dispose();
    lightTheme.dispose();
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
