import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/models.dart';
import 'package:bcmusic/platform_bridge.dart';

class _FakePlatform implements MusicPlatform {
  final updates = StreamController<LibrarySnapshot>.broadcast(sync: true);
  int toggled = 0;
  int paused = 0;
  int skips = 0;
  int? nativeSleepMinutes;
  bool? nativeSleepAtEnd;
  bool nativeSleepCancelled = false;

  LibrarySnapshot state = const LibrarySnapshot();

  @override
  Stream<LibrarySnapshot> get events => updates.stream;
  @override
  Future<LibrarySnapshot> getState() async => state;
  @override
  Future<OfflineTrack> resolve(String url) async => throw UnimplementedError();
  @override
  Future<void> enqueue(String id) async {}
  @override
  Future<void> retry(String id) async {}
  @override
  Future<void> remove(String id) async {}
  @override
  Future<void> play(String id, {List<String>? queueIds}) async {}
  @override
  Future<void> playSource(String url, {bool autoTransition = false}) async {}
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
  Future<void> togglePlay() async {
    toggled++;
  }
  @override
  Future<void> pause() async {
    paused++;
  }
  @override
  Future<void> setSleepTimer(int? minutes, {bool atEndOfTrack = false}) async {
    nativeSleepMinutes = minutes;
    nativeSleepAtEnd = atEndOfTrack;
    nativeSleepCancelled = false;
  }
  @override
  Future<void> cancelSleepTimer() async {
    nativeSleepCancelled = true;
    nativeSleepMinutes = null;
    nativeSleepAtEnd = false;
  }
  @override
  Future<void> seek(int positionMs) async {}
  @override
  Future<void> skip(int direction) async {
    skips += direction;
  }
  @override
  Future<void> openWebsite() async {}
  @override
  Future<void> updatePreferences(Map<String, Object> changes) async {}
  @override
  Future<void> authenticate(String u, String p, {String? displayName}) async {}
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
  Future<void> setRepeatMode(String mode) async {}
  @override
  Future<void> setShuffle(bool enabled) async {}
  @override
  Future<void> removeQueueItem(int index) async {}
  @override
  Future<void> reorderQueue(int oldIndex, int newIndex) async {}
}

void main() {
  group('Sleep timer tests', () {
    test('sets and cancels sleep timer with target duration', () {
      final platform = _FakePlatform();
      final controller = MusicController(platform);

      expect(controller.sleepTimerActive, isFalse);
      expect(controller.sleepTimerRemaining, isNull);

      controller.setSleepTimer(15);
      expect(controller.sleepTimerActive, isTrue);
      expect(controller.sleepTimerMinutes, 15);
      expect(controller.sleepAtEndOfTrack, isFalse);
      expect(controller.sleepTimerRemaining, isNotNull);
      expect(controller.sleepTimerRemaining!.inMinutes, lessThanOrEqualTo(15));
      expect(platform.nativeSleepMinutes, 15);
      expect(platform.nativeSleepAtEnd, isFalse);

      controller.cancelSleepTimer();
      expect(controller.sleepTimerActive, isFalse);
      expect(controller.sleepTimerRemaining, isNull);
      expect(platform.nativeSleepCancelled, isTrue);
      controller.dispose();
    });

    test('sets sleep timer for end of current track', () {
      final platform = _FakePlatform();
      final controller = MusicController(platform);

      controller.setSleepTimer(null, atEndOfTrack: true);
      expect(controller.sleepTimerActive, isTrue);
      expect(controller.sleepAtEndOfTrack, isTrue);
      expect(platform.nativeSleepAtEnd, isTrue);

      controller.cancelSleepTimer();
      expect(controller.sleepTimerActive, isFalse);
      expect(controller.sleepAtEndOfTrack, isFalse);
      expect(platform.nativeSleepCancelled, isTrue);
      controller.dispose();
    });

    test('does not toggle play when timer expires if already paused', () {
      final platform = _FakePlatform();
      final controller = MusicController(platform);

      // Trạng thái hiện tại: isPlaying == false
      controller.setSleepTimer(0);
      controller.checkSleepTimer();
      expect(platform.toggled, 0); // Không toggle khi đang pause
      expect(platform.paused, 1);  // Gọi pause tường minh để chặn nạp tiếp
      expect(controller.sleepTimerActive, isFalse);
      controller.dispose();
    });

    test('stops playback explicitly when timer expires while playing', () async {
      final platform = _FakePlatform();
      final controller = MusicController(platform);
      await controller.initialize();

      // Giả lập trạng thái đang phát
      platform.updates.add(
        const LibrarySnapshot(
          playback: PlaybackState(
            trackId: 'youtube_track_1',
            isPlaying: true,
            durationMs: 180000,
            positionMs: 60000,
          ),
        ),
      );

      controller.setSleepTimer(0);
      final stopped = controller.checkSleepTimer();
      expect(stopped, isTrue);
      expect(platform.paused, 1);
      expect(platform.toggled, 0); // Chỉ gọi pause tường minh một lần, không togglePlay
      expect(controller.sleepTimerActive, isFalse);
      controller.dispose();
    });

    test('does not skip to next song in queue when end of track sleep timer triggers', () async {
      final platform = _FakePlatform();
      final controller = MusicController(platform);
      await controller.initialize();

      // Enqueue 2 bài hát
      controller.enqueueSong(
        const PlaybackQueueItem(
          url: 'https://www.youtube.com/watch?v=firstSong123',
          title: 'Bài 1',
          artist: 'Ca sĩ 1',
        ),
      );
      controller.enqueueSong(
        const PlaybackQueueItem(
          url: 'https://www.youtube.com/watch?v=secondSong45',
          title: 'Bài 2',
          artist: 'Ca sĩ 2',
        ),
      );

      // Phát bài 1
      platform.updates.add(
        const LibrarySnapshot(
          playback: PlaybackState(
            trackId: 'youtube_firstSong123',
            isPlaying: true,
            durationMs: 180000,
            positionMs: 50000,
            track: OfflineTrack(
              id: 'youtube_firstSong123',
              title: 'Bài 1',
              artist: 'Ca sĩ 1',
              sourceUrl: 'https://www.youtube.com/watch?v=firstSong123',
              provider: 'youtube',
              status: 'streaming',
            ),
          ),
        ),
      );

      // Kích hoạt hẹn giờ khi hết bài hiện tại
      controller.setSleepTimer(null, atEndOfTrack: true);
      expect(controller.sleepTimerActive, isTrue);

      // Báo snapshot bài 1 kết thúc (ended = true)
      platform.updates.add(
        const LibrarySnapshot(
          playback: PlaybackState(
            trackId: 'youtube_firstSong123',
            isPlaying: false,
            ended: true,
            durationMs: 180000,
            positionMs: 180000,
            track: OfflineTrack(
              id: 'youtube_firstSong123',
              title: 'Bài 1',
              artist: 'Ca sĩ 1',
              sourceUrl: 'https://www.youtube.com/watch?v=firstSong123',
              provider: 'youtube',
              status: 'streaming',
            ),
          ),
        ),
      );

      // Kiểm tra: sleep timer phải dừng phát và KHÔNG skip sang bài 2
      expect(platform.skips, 0); // Không gọi skip(1)
      expect(platform.paused, greaterThanOrEqualTo(1));
      expect(controller.sleepTimerActive, isFalse);
      controller.dispose();
    });
  });
}
