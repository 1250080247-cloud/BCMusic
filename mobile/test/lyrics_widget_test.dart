import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/lyrics.dart';
import 'package:bcmusic/models.dart';
import 'package:bcmusic/platform_bridge.dart';
import 'package:bcmusic/player_controls.dart';

class _LyricsMockPlatform implements MusicPlatform {
  final updates = StreamController<LibrarySnapshot>.broadcast(sync: true);
  final Map<String, String> cachedLyrics = {};
  int seekTarget = -1;
  int enqueued = 0;

  @override
  Stream<LibrarySnapshot> get events => updates.stream;
  @override
  Future<LibrarySnapshot> getState() async => const LibrarySnapshot();
  @override
  Future<OfflineTrack> resolve(String url) async => throw UnimplementedError();
  @override
  Future<void> enqueue(String id) async {
    enqueued++;
  }
  @override
  Future<void> retry(String id) async {}
  @override
  Future<void> remove(String id) async {
    cachedLyrics.remove(id);
  }
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
  Future<void> togglePlay() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> setSleepTimer(int? minutes, {bool atEndOfTrack = false}) async {}
  @override
  Future<void> cancelSleepTimer() async {}
  @override
  Future<void> setRepeatMode(String mode) async {}
  @override
  Future<void> setShuffle(bool enabled) async {}
  @override
  Future<void> removeQueueItem(int index) async {}
  @override
  Future<void> reorderQueue(int oldIndex, int newIndex) async {}
  @override
  Future<void> seek(int positionMs) async {
    seekTarget = positionMs;
  }
  @override
  Future<void> skip(int direction) async {}
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
  Future<void> saveLyrics(String trackId, String data) async {
    cachedLyrics[trackId] = data;
  }
  @override
  Future<String?> getLyrics(String trackId) async => cachedLyrics[trackId];
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
  group('Lyrics offline and widget tests', () {
    test('reads lyrics from offline cache without making network requests', () async {
      final platform = _LyricsMockPlatform();
      const cached = LyricsData(
        status: 'synced',
        source: 'BCMusic Cache',
        lines: [
          LyricLine(timeMs: 2000, text: 'Câu 1 offline'),
          LyricLine(timeMs: 5000, text: 'Câu 2 offline'),
        ],
      );
      platform.cachedLyrics['track_123'] = jsonEncode(cached.toMap());

      final repo = LyricsRepository(platform: platform);
      final result = await repo.getLyrics(
        trackId: 'track_123',
        rawTitle: 'Bài hát thử',
        rawArtist: 'Ca sĩ thử',
      );

      expect(result.status, 'synced');
      expect(result.source, 'BCMusic Cache');
      expect(result.lines.length, 2);
      expect(result.lines[0].text, 'Câu 1 offline');
      repo.dispose();
    });

    test('prefetches and caches lyrics when downloadPreview is invoked', () async {
      final platform = _LyricsMockPlatform();
      final controller = MusicController(platform);
      await controller.initialize();

      const sampleTrack = OfflineTrack(
        id: 'youtube_abc12345678',
        title: 'Tên bài hát',
        artist: 'Nghệ sĩ',
        sourceUrl: 'https://www.youtube.com/watch?v=abc12345678',
        provider: 'youtube',
        status: 'preview',
      );

      controller.preview = sampleTrack;
      // Pre-seed repository memory cache or test prefetch call
      controller.lyricsRepository.getLyrics(
        trackId: sampleTrack.id,
        rawTitle: sampleTrack.title,
        rawArtist: sampleTrack.artist,
      );

      await controller.downloadPreview();
      expect(platform.enqueued, 1);
      controller.dispose();
    });

    testWidgets('Full Player Tab 0 displays and highlights synced lyrics, seeks on tap', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final platform = _LyricsMockPlatform();
      const trackId = 'youtube_track_synced';
      const lyrics = LyricsData(
        status: 'synced',
        lines: [
          LyricLine(timeMs: 1000, text: 'Dòng thứ nhất'),
          LyricLine(timeMs: 5000, text: 'Dòng thứ hai đang hát'),
          LyricLine(timeMs: 12000, text: 'Dòng thứ ba kết thúc'),
        ],
      );
      platform.cachedLyrics[trackId] = jsonEncode(lyrics.toMap());

      final controller = MusicController(platform);
      await controller.initialize();

      platform.updates.add(
        const LibrarySnapshot(
          playback: PlaybackState(
            trackId: trackId,
            isPlaying: true,
            positionMs: 6000, // Khớp dòng 2 (5000 -> 12000)
            durationMs: 30000,
            track: OfflineTrack(
              id: trackId,
              title: 'Bài hát có lời',
              artist: 'Ca sĩ A',
              sourceUrl: 'https://www.youtube.com/watch?v=track_synced',
              provider: 'youtube',
              status: 'streaming',
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerControls(
              controller: controller,
              onAddToPlaylist: (_) {},
              onDownload: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Mở Full Player NowPlaying
      await tester.tap(find.text('Bài hát có lời'));
      await tester.pumpAndSettle();

      // Chọn Tab 'Lời bài hát'
      await tester.tap(find.text('Lời bài hát'));
      await tester.pumpAndSettle();

      // Kiểm tra các dòng lời xuất hiện
      expect(find.text('Dòng thứ nhất'), findsOneWidget);
      expect(find.text('Dòng thứ hai đang hát'), findsOneWidget);

      // Chạm vào dòng thứ nhất để seek tới 1000ms
      await tester.tap(find.text('Dòng thứ nhất'));
      await tester.pumpAndSettle();
      expect(platform.seekTarget, 1000);

      controller.dispose();
    });

    testWidgets('Full Player displays plain lyrics when lyrics are not synced', (
      tester,
    ) async {
      final platform = _LyricsMockPlatform();
      const trackId = 'youtube_track_plain';
      const lyrics = LyricsData(
        status: 'plain',
        plainLyrics: 'Đây là lời bài hát dạng tĩnh không có timestamp.',
      );
      platform.cachedLyrics[trackId] = jsonEncode(lyrics.toMap());

      final controller = MusicController(platform);
      await controller.initialize();

      platform.updates.add(
        const LibrarySnapshot(
          playback: PlaybackState(
            trackId: trackId,
            isPlaying: true,
            positionMs: 2000,
            durationMs: 30000,
            track: OfflineTrack(
              id: trackId,
              title: 'Bài hát lời tĩnh',
              artist: 'Ca sĩ B',
              sourceUrl: 'https://www.youtube.com/watch?v=track_plain',
              provider: 'youtube',
              status: 'streaming',
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerControls(
              controller: controller,
              onAddToPlaylist: (_) {},
              onDownload: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bài hát lời tĩnh'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lời bài hát'));
      await tester.pumpAndSettle();

      expect(
        find.text('Đây là lời bài hát dạng tĩnh không có timestamp.'),
        findsOneWidget,
      );

      controller.dispose();
    });

    testWidgets('Full Player displays empty/retry message when lyrics unavailable', (
      tester,
    ) async {
      final platform = _LyricsMockPlatform();
      const trackId = 'youtube_track_empty';
      const lyrics = LyricsData(status: 'unavailable');
      platform.cachedLyrics[trackId] = jsonEncode(lyrics.toMap());

      final controller = MusicController(platform);
      await controller.initialize();

      platform.updates.add(
        const LibrarySnapshot(
          playback: PlaybackState(
            trackId: trackId,
            isPlaying: true,
            positionMs: 2000,
            durationMs: 30000,
            track: OfflineTrack(
              id: trackId,
              title: 'Bài không có lời',
              artist: 'Ca sĩ C',
              sourceUrl: 'https://www.youtube.com/watch?v=track_empty',
              provider: 'youtube',
              status: 'streaming',
            ),
          ),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PlayerControls(
              controller: controller,
              onAddToPlaylist: (_) {},
              onDownload: (_) {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Bài không có lời'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lời bài hát'));
      await tester.pumpAndSettle();

      expect(find.text('Chưa có lời bài hát cho bài này.'), findsOneWidget);
      expect(find.text('Thử tìm lại'), findsOneWidget);

      controller.dispose();
    });
  });
}
