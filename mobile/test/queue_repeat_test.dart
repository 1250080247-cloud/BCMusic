import 'dart:async';

import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/models.dart';
import 'package:bcmusic/platform_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

class QueueTestMusicPlatform implements MusicPlatform {
  final updates = StreamController<LibrarySnapshot>.broadcast(sync: true);
  final playedSources = <String>[];
  final skips = <int>[];
  final repeatModes = <String>[];
  final shuffles = <bool>[];
  int pauseCalls = 0;
  LibrarySnapshot state = const LibrarySnapshot();

  @override
  Stream<LibrarySnapshot> get events => updates.stream;
  @override
  Future<LibrarySnapshot> getState() async => state;
  @override
  Future<OfflineTrack> resolve(String url) async => const OfflineTrack(
        id: 'test',
        title: 'Title',
        artist: 'Artist',
        sourceUrl: '',
        provider: 'youtube',
        status: 'preview',
      );
  @override
  Future<void> enqueue(String id) async {}
  @override
  Future<void> retry(String id) async {}
  @override
  Future<void> remove(String id) async {}
  @override
  Future<void> play(String id, {List<String>? queueIds}) async {}
  @override
  Future<void> playSource(String url, {bool autoTransition = false}) async {
    playedSources.add(url);
  }
  @override
  Future<void> createPlaylist(
    String name, {
    String? trackId,
    String? url,
    bool enqueueIfMissing = false,
  }) async {}
  @override
  Future<void> deletePlaylist(String playlistId) async {}
  @override
  Future<void> addToPlaylist(String playlistId, String id) async {}
  @override
  Future<void> enqueueAndAddToPlaylist(
    String playlistId,
    String id, {
    String? url,
  }) async {}
  @override
  Future<void> removeFromPlaylist(String playlistId, String id) async {}
  @override
  Future<void> togglePlay() async {}
  @override
  Future<void> seek(int positionMs) async {}
  @override
  Future<void> skip(int direction) async {
    skips.add(direction);
  }
  @override
  Future<void> openWebsite() async {}
  @override
  Future<void> updatePreferences(Map<String, Object> changes) async {}
  @override
  Future<void> authenticate(String username, String password, {String? displayName}) async {}
  @override
  Future<void> startGoogle() async {}
  @override
  Future<void> signOut() async {}
  @override
  Future<void> clearAccountError() async {}
  @override
  Future<void> saveLyrics(String trackId, String data) async {}
  @override
  Future<String?> getLyrics(String trackId) async => null;
  @override
  Future<void> pause() async {
    pauseCalls++;
  }
  @override
  Future<void> setSleepTimer(int? minutes, {bool atEndOfTrack = false}) async {}
  @override
  Future<void> cancelSleepTimer() async {}
  @override
  Future<void> setRepeatMode(String mode) async {
    repeatModes.add(mode);
  }
  @override
  Future<void> setShuffle(bool enabled) async {
    shuffles.add(enabled);
  }
  final removedQueueIndices = <int>[];
  final reorderedQueueMoves = <(int, int)>[];

  @override
  Future<void> removeQueueItem(int index) async {
    removedQueueIndices.add(index);
  }

  @override
  Future<void> reorderQueue(int oldIndex, int newIndex) async {
    reorderedQueueMoves.add((oldIndex, newIndex));
  }

  @override
  Future<PlaylistPreview> resolvePlaylist(String url) async => throw UnimplementedError();

  @override
  Future<LocalPlaylist> importSoundCloudPlaylist({
    required String name,
    required String sourceUrl,
    required List<OfflineTrack> tracks,
  }) async => throw UnimplementedError();
}

void main() {
  test('cycleRepeatMode cycles off -> all -> one -> off', () async {
    final platform = QueueTestMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();

    expect(controller.repeatMode, 'off');
    expect(controller.repeatOne, false);
    expect(controller.repeatAll, false);

    // 1st cycle: all
    await controller.cycleRepeatMode();
    expect(controller.repeatMode, 'all');
    expect(controller.repeatOne, false);
    expect(controller.repeatAll, true);
    expect(platform.repeatModes.last, 'all');

    // 2nd cycle: one
    await controller.cycleRepeatMode();
    expect(controller.repeatMode, 'one');
    expect(controller.repeatOne, true);
    expect(controller.repeatAll, false);
    expect(platform.repeatModes.last, 'one');

    // 3rd cycle: off
    await controller.cycleRepeatMode();
    expect(controller.repeatMode, 'off');
    expect(controller.repeatOne, false);
    expect(controller.repeatAll, false);
    expect(platform.repeatModes.last, 'off');
  });

  test('toggleShuffle toggles false <-> true and calls platform', () async {
    final platform = QueueTestMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();

    expect(controller.shuffle, false);

    await controller.toggleShuffle();
    expect(controller.shuffle, true);
    expect(platform.shuffles.last, true);

    await controller.toggleShuffle();
    expect(controller.shuffle, false);
    expect(platform.shuffles.last, false);
  });

  test('repeatMode ALL loops back to index 0 when last song ends', () async {
    final platform = QueueTestMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();

    // Start playback with 2 songs
    const url1 = 'https://www.youtube.com/watch?v=song1111111';
    const url2 = 'https://www.youtube.com/watch?v=song2222222';
    await controller.playSource(url1, queue: [url1, url2], queueItems: [
      const PlaybackQueueItem(url: url1, title: 'Song 1', artist: 'Artist 1'),
      const PlaybackQueueItem(url: url2, title: 'Song 2', artist: 'Artist 2'),
    ]);

    expect(controller.sourceQueueIndex, 0);

    // Advance to Song 2
    await controller.skip(1);
    expect(controller.sourceQueueIndex, 1);
    expect(platform.playedSources.last, url2);

    // Set repeatMode = all
    await controller.setRepeatMode('all');
    expect(controller.repeatMode, 'all');

    // Emit ended for Song 2
    platform.updates.add(
      LibrarySnapshot(
        playback: const PlaybackState(
          trackId: 'source_song2',
          isPlaying: true,
          ended: true,
          offline: false,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    // Song 2 was last in queue, with repeatMode=all it should loop back to url1
    expect(controller.sourceQueueIndex, 0);
    expect(platform.playedSources.last, url1);
  });

  test('repeatMode ALL with cached song in sourceQueue advances on ended and does not get stuck', () async {
    final platform = QueueTestMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();

    const url1 = 'https://www.youtube.com/watch?v=cSong111111';
    const url2 = 'https://www.youtube.com/watch?v=oSong222222';
    await controller.playSource(url1, queue: [url1, url2], queueItems: [
      const PlaybackQueueItem(url: url1, title: 'Cached Song', artist: 'Artist 1'),
      const PlaybackQueueItem(url: url2, title: 'Online Song', artist: 'Artist 2'),
    ]);

    await controller.setRepeatMode('all');
    expect(controller.repeatAll, true);
    expect(controller.sourceQueueIndex, 0);

    // Song 1 was cached offline so offline is true in playback state
    platform.updates.add(
      LibrarySnapshot(
        tracks: const [
          OfflineTrack(
            id: 'cached_id_1',
            title: 'Cached Song',
            artist: 'Artist 1',
            sourceUrl: url1,
            provider: 'youtube',
            status: 'completed',
          ),
        ],
        playback: const PlaybackState(
          trackId: 'cached_id_1',
          isPlaying: true,
          ended: true,
          offline: true,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    // Dart successfully advanced to song 2 (not stuck on song 1)
    expect(controller.sourceQueueIndex, 1);
    expect(platform.playedSources.last, url2);

    // Song 2 ends as well
    platform.updates.add(
      LibrarySnapshot(
        playback: const PlaybackState(
          trackId: 'source_song2',
          isPlaying: true,
          ended: true,
          offline: false,
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    // With repeatAll=true, looped back to song 1
    expect(controller.sourceQueueIndex, 0);
    expect(platform.playedSources.last, url1);
  });

  test('repeatMode ALL does not loop if Sleep Timer atEndOfTrack is active', () async {
    final platform = QueueTestMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();

    const url1 = 'https://www.youtube.com/watch?v=song1111111';
    const url2 = 'https://www.youtube.com/watch?v=song2222222';
    await controller.playSource(url2, queue: [url1, url2], queueItems: [
      const PlaybackQueueItem(url: url1, title: 'Song 1', artist: 'Artist 1'),
      const PlaybackQueueItem(url: url2, title: 'Song 2', artist: 'Artist 2'),
    ]);

    await controller.setRepeatMode('all');
    controller.setSleepTimer(null, atEndOfTrack: true);

    // Emit ended for Song 2
    platform.updates.add(
      LibrarySnapshot(
        playback: const PlaybackState(
          trackId: 'source_song2',
          isPlaying: true,
          ended: true,
          offline: false,
        ),
      ),
    );

    // Sleep Timer should have paused playback and cancelled loop
    expect(platform.pauseCalls, greaterThanOrEqualTo(1));
    expect(controller.sleepTimerActive, false);
    // Did NOT loop back to url1
    expect(platform.playedSources.last, url2);
  });

  test('queue operations: skipToQueueIndex, removeQueueItem, reorderQueue', () async {
    final platform = QueueTestMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();

    const u1 = 'https://www.youtube.com/watch?v=track111111';
    const u2 = 'https://www.youtube.com/watch?v=track222222';
    const u3 = 'https://www.youtube.com/watch?v=track333333';
    const u4 = 'https://www.youtube.com/watch?v=track444444';

    await controller.playSource(u1, queue: [u1, u2, u3, u4], queueItems: [
      const PlaybackQueueItem(url: u1, title: 'Track 1', artist: 'A1'),
      const PlaybackQueueItem(url: u2, title: 'Track 2', artist: 'A2'),
      const PlaybackQueueItem(url: u3, title: 'Track 3', artist: 'A3'),
      const PlaybackQueueItem(url: u4, title: 'Track 4', artist: 'A4'),
    ]);

    expect(controller.sourceQueueIndex, 0);
    expect(controller.sourceQueueItems.length, 4);

    // 1. skipToQueueIndex directly to index 2 (Track 3)
    await controller.skipToQueueIndex(2);
    expect(controller.sourceQueueIndex, 2);
    expect(platform.playedSources.last, u3);

    // 2. removeQueueItem for an item after current track (remove index 3 - Track 4)
    controller.removeQueueItem(3);
    expect(controller.sourceQueueItems.length, 3);
    expect(controller.sourceQueueIndex, 2);
    expect(controller.sourceQueueItems.any((item) => item.url == u4), false);

    // 3. removeQueueItem for an item before current track (remove index 0 - Track 1)
    // Current track should remain Track 3, but its index shifts from 2 to 1!
    controller.removeQueueItem(0);
    expect(controller.sourceQueueItems.length, 2);
    expect(controller.sourceQueueIndex, 1);
    expect(controller.sourceQueueItems[controller.sourceQueueIndex!].url, u3);

    // 4. reorderQueue: reorder remaining upcoming tracks
    // Right now queue has [Track 2 (idx 0), Track 3 (idx 1)]. Let's add Track 5 & 6 to test upcoming reordering
    controller.enqueueSong(const PlaybackQueueItem(url: 'u5', title: 'T5', artist: 'A5'));
    controller.enqueueSong(const PlaybackQueueItem(url: 'u6', title: 'T6', artist: 'A6'));
    // Queue is [Track 2, Track 3 (current), T5, T6]
    expect(controller.sourceQueueItems.length, 4);
    // Upcoming items after current (index 1) are at absolute index 2 and 3.
    // Reorder upcoming relative index 0 (T5) and 1 (T6): swap them so T6 comes before T5
    controller.reorderUpcomingQueue(0, 2); // Flutter ReorderableListView calls newIndex=2 when moving past index 1
    expect(controller.sourceQueueItems[2].title, 'T6');
    expect(controller.sourceQueueItems[3].title, 'T5');
    expect(controller.sourceQueueIndex, 1); // Current song not affected
  });

  test('toggleShuffle on online queue actually shuffles upcoming order and restores original order when toggled off', () async {
    final platform = QueueTestMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();

    const u1 = 'https://www.youtube.com/watch?v=track111111';
    const u2 = 'https://www.youtube.com/watch?v=track222222';
    const u3 = 'https://www.youtube.com/watch?v=track333333';
    const u4 = 'https://www.youtube.com/watch?v=track444444';
    const u5 = 'https://www.youtube.com/watch?v=track555555';

    await controller.playSource(u1, queue: [u1, u2, u3, u4, u5], queueItems: [
      const PlaybackQueueItem(url: u1, title: 'Track 1', artist: 'A1'),
      const PlaybackQueueItem(url: u2, title: 'Track 2', artist: 'A2'),
      const PlaybackQueueItem(url: u3, title: 'Track 3', artist: 'A3'),
      const PlaybackQueueItem(url: u4, title: 'Track 4', artist: 'A4'),
      const PlaybackQueueItem(url: u5, title: 'Track 5', artist: 'A5'),
    ]);

    expect(controller.sourceQueueIndex, 0);
    final originalUpcoming = controller.sourceQueueItems.sublist(1).map((e) => e.url).toList();
    expect(originalUpcoming, [u2, u3, u4, u5]);

    // Bật Shuffle
    await controller.setShuffle(true);
    expect(controller.shuffle, true);
    expect(controller.sourceQueueIndex, 0); // Vẫn phát Track 1 không bị gián đoạn
    expect(controller.sourceQueueItems[0].url, u1);

    final shuffledUpcoming = controller.sourceQueueItems.sublist(1).map((e) => e.url).toList();
    // Danh sách bài tiếp theo đã bị xáo trộn khác ban đầu
    expect(shuffledUpcoming, isNot(equals(originalUpcoming)));
    // Nhưng vẫn đủ 4 bài sắp tới
    expect(shuffledUpcoming.toSet(), equals({u2, u3, u4, u5}));

    // Tắt Shuffle -> Khôi phục lại thứ tự gốc ban đầu tính từ bài đang phát
    await controller.setShuffle(false);
    expect(controller.shuffle, false);
    expect(controller.sourceQueueIndex, 0);
    final restoredUpcoming = controller.sourceQueueItems.sublist(1).map((e) => e.url).toList();
    expect(restoredUpcoming, equals(originalUpcoming));
  });

  test('offline queue operations sync removeQueueItem and reorderQueue to platform', () async {
    final platform = QueueTestMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();

    // Giả lập thư viện có 4 bài offline đã tải xong
    final tracks = [
      const OfflineTrack(id: 't1', title: 'T1', artist: 'A', sourceUrl: 'u1', provider: 'youtube', status: 'completed'),
      const OfflineTrack(id: 't2', title: 'T2', artist: 'A', sourceUrl: 'u2', provider: 'youtube', status: 'completed'),
      const OfflineTrack(id: 't3', title: 'T3', artist: 'A', sourceUrl: 'u3', provider: 'youtube', status: 'completed'),
      const OfflineTrack(id: 't4', title: 'T4', artist: 'A', sourceUrl: 'u4', provider: 'youtube', status: 'completed'),
    ];
    platform.updates.add(LibrarySnapshot(
      tracks: tracks,
      playback: const PlaybackState(trackId: 't1', isPlaying: true, offline: true),
    ));
    await Future<void>.delayed(Duration.zero);

    await controller.play(tracks[0], queueIds: ['t1', 't2', 't3', 't4']);

    // 1. Xóa bài ở index 2 (t3)
    controller.removeQueueItem(2);
    expect(platform.removedQueueIndices, contains(2));

    // 2. Đổi chỗ bài trong danh sách tiếp theo: T2 (rel 0) và T4 (rel 1)
    controller.reorderUpcomingQueue(0, 2); // Flutter newIndex = 2
    expect(platform.reorderedQueueMoves, isNotEmpty);
    // Absolute index: current is 0, offset = 1. oldAbs = 1, newAbs = 2
    expect(platform.reorderedQueueMoves.last, (1, 2));
  });
}
