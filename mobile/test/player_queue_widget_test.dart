import 'dart:async';

import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/app_theme.dart';
import 'package:bcmusic/models.dart';
import 'package:bcmusic/platform_bridge.dart';
import 'package:bcmusic/player_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class WidgetTestPlatform implements MusicPlatform {
  final updates = StreamController<LibrarySnapshot>.broadcast(sync: true);
  final playedSources = <String>[];
  final repeatModes = <String>[];
  final shuffles = <bool>[];
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
  Future<void> skip(int direction) async {}
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
  Future<void> pause() async {}
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
  @override
  Future<void> removeQueueItem(int index) async {}
  @override
  Future<void> reorderQueue(int oldIndex, int newIndex) async {}
}

void main() {
  testWidgets('Full Player controls render Shuffle, Repeat and Tab 1 queue interactions',
      (tester) async {
    tester.view.physicalSize = const Size(800, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final platform = WidgetTestPlatform();
    final controller = MusicController(platform);
    await controller.initialize();

    const u1 = 'https://www.youtube.com/watch?v=song1111111';
    const u2 = 'https://www.youtube.com/watch?v=song2222222';
    const u3 = 'https://www.youtube.com/watch?v=song3333333';

    await controller.playSource(u1, queue: [u1, u2, u3], queueItems: [
      const PlaybackQueueItem(url: u1, title: 'Bài Một', artist: 'Ca Sĩ A'),
      const PlaybackQueueItem(url: u2, title: 'Bài Hai', artist: 'Ca Sĩ B'),
      const PlaybackQueueItem(url: u3, title: 'Bài Ba', artist: 'Ca Sĩ C'),
    ]);

    platform.updates.add(
      const LibrarySnapshot(
        playback: PlaybackState(
          trackId: 'song1',
          isPlaying: true,
          positionMs: 1000,
          durationMs: 180000,
          track: OfflineTrack(
            id: 'song1',
            title: 'Bài Một',
            artist: 'Ca Sĩ A',
            sourceUrl: u1,
            provider: 'youtube',
            status: 'streaming',
          ),
        ),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: bcmusicTheme(light: false),
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

    // 1. Open Full Player by tapping mini player
    await tester.tap(find.text('Bài Một'));
    await tester.pumpAndSettle();

    // 2. Verify 5 buttons exist: Shuffle, Prev, Play/Pause, Next, Repeat
    expect(find.byTooltip('Bật trộn bài'), findsOneWidget);
    expect(find.byTooltip('Bài trước'), findsOneWidget);
    expect(find.byTooltip('Tạm dừng'), findsOneWidget);
    expect(find.byTooltip('Bài tiếp'), findsOneWidget);
    expect(find.byTooltip('Lặp lại: Tắt'), findsOneWidget);

    // 3. Test tapping Shuffle (toggle ON then toggle OFF to restore order)
    await tester.tap(find.byTooltip('Bật trộn bài'));
    await tester.pumpAndSettle();
    expect(controller.shuffle, true);
    expect(find.byTooltip('Tắt trộn bài'), findsOneWidget);

    await tester.tap(find.byTooltip('Tắt trộn bài'));
    await tester.pumpAndSettle();
    expect(controller.shuffle, false);
    expect(find.byTooltip('Bật trộn bài'), findsOneWidget);

    // 4. Test tapping Repeat: cycle to ALL
    await tester.tap(find.byTooltip('Lặp lại: Tắt'));
    await tester.pumpAndSettle();
    expect(controller.repeatMode, 'all');
    expect(find.byTooltip('Lặp lại: Tất cả'), findsOneWidget);

    // Cycle to ONE
    await tester.tap(find.byTooltip('Lặp lại: Tất cả'));
    await tester.pumpAndSettle();
    expect(controller.repeatMode, 'one');
    expect(find.byTooltip('Lặp lại: 1 bài'), findsOneWidget);

    // 5. Switch to Tab 1 ('Tiếp theo')
    await tester.tap(find.text('Tiếp theo'));
    await tester.pumpAndSettle();

    // Upcoming queue should show 'Bài Hai' and 'Bài Ba'
    expect(find.text('Bài Hai'), findsOneWidget);
    expect(find.text('Bài Ba'), findsOneWidget);

    // 6. Tap on 'Bài Ba' in Tab 1 to jump directly to it
    await tester.tap(find.text('Bài Ba'));
    await tester.pumpAndSettle();
    expect(platform.playedSources.last, u3);
    expect(controller.sourceQueueIndex, 2);
  });
}
