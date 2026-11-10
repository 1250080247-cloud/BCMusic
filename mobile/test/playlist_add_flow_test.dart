import 'dart:async';

import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/app_theme.dart';
import 'package:bcmusic/models.dart';
import 'package:bcmusic/playlist_screen.dart';
import 'package:bcmusic/platform_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class PlaylistAddFlowMockPlatform implements MusicPlatform {
  final updates = StreamController<LibrarySnapshot>.broadcast(sync: true);
  final enqueuedPlaylistTracks = <(String, String, String?)>[];
  final createdPlaylists = <(String, String?, String?, bool)>[];
  final addedToLocal = <(String, String)>[];
  LibrarySnapshot state = const LibrarySnapshot(
    playlists: [
      LocalPlaylist(id: 'pl-offline-1', name: 'Playlist Cũ 1', trackIds: []),
    ],
  );

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
  }) async {
    createdPlaylists.add((name, trackId, url, enqueueIfMissing));
  }
  @override
  Future<void> deletePlaylist(String playlistId) async {}
  @override
  Future<void> addToPlaylist(String playlistId, String id) async {
    addedToLocal.add((playlistId, id));
  }
  @override
  Future<void> enqueueAndAddToPlaylist(
    String playlistId,
    String id, {
    String? url,
  }) async {
    enqueuedPlaylistTracks.add((playlistId, id, url));
  }
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
  Future<void> setRepeatMode(String mode) async {}
  @override
  Future<void> setShuffle(bool enabled) async {}
  @override
  Future<void> removeQueueItem(int index) async {}
  @override
  Future<void> reorderQueue(int oldIndex, int newIndex) async {}
}

void main() {
  testWidgets('promptAddToPlaylist shows 2 choices and passes source URL to enqueueAndAddToPlaylist', (tester) async {
    final platform = PlaylistAddFlowMockPlatform();
    final controller = MusicController(platform);
    await controller.initialize();

    const song = PlaybackQueueItem(
      url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      title: 'Never Gonna Give You Up',
      artist: 'Rick Astley',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: bcmusicTheme(light: false),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => promptAddToPlaylist(
                context,
                controller,
                song: song,
                rawTrackId: 'youtube_dQw4w9WgXcQ',
              ),
              child: const Text('Mở Thêm Playlist'),
            ),
          ),
        ),
      ),
    );

    // Tap button to open sheet
    await tester.tap(find.text('Mở Thêm Playlist'));
    await tester.pumpAndSettle();

    // Verify sheet with 2 choices
    expect(find.text('Tải và thêm vào playlist offline'), findsOneWidget);
    expect(find.text('Thêm ngay vào playlist có sẵn'), findsOneWidget);

    // Select choice 1: Tải và thêm vào playlist offline
    await tester.tap(find.text('Tải và thêm vào playlist offline'));
    await tester.pumpAndSettle();

    // Verify offline playlist dialog
    expect(find.text('Chọn playlist offline'), findsOneWidget);
    expect(find.text('Playlist Cũ 1'), findsOneWidget);

    // Tap 'Playlist Cũ 1'
    await tester.tap(find.text('Playlist Cũ 1'));
    await tester.pumpAndSettle();

    // Verify enqueueAndAddToPlaylist was triggered with correct arguments INCLUDING url!
    expect(platform.enqueuedPlaylistTracks.length, 1);
    expect(platform.enqueuedPlaylistTracks.single.$1, 'pl-offline-1');
    expect(platform.enqueuedPlaylistTracks.single.$2, 'youtube_dQw4w9WgXcQ');
    expect(platform.enqueuedPlaylistTracks.single.$3, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await platform.updates.close();
  });

  testWidgets('promptAddToPlaylist creating a new offline playlist passes source URL and enqueueIfMissing=true', (tester) async {
    final platform = PlaylistAddFlowMockPlatform();
    final controller = MusicController(platform);
    await controller.initialize();

    const song = PlaybackQueueItem(
      url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      title: 'Never Gonna Give You Up',
      artist: 'Rick Astley',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: bcmusicTheme(light: false),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => promptAddToPlaylist(
                context,
                controller,
                song: song,
                rawTrackId: 'youtube_dQw4w9WgXcQ',
              ),
              child: const Text('Mở Thêm Playlist'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở Thêm Playlist'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tải và thêm vào playlist offline'));
    await tester.pumpAndSettle();

    // Tap 'Tạo playlist mới'
    await tester.tap(find.text('Tạo playlist mới'));
    await tester.pumpAndSettle();

    // Enter name
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Danh Sách Mới Tuyệt Vời');
    await tester.pump();
    await tester.tap(find.text('Tạo'));
    await tester.pumpAndSettle();

    // Verify createPlaylist was called with URL and enqueueIfMissing=true
    expect(platform.createdPlaylists.length, 1);
    expect(platform.createdPlaylists.single.$1, 'Danh Sách Mới Tuyệt Vời');
    expect(platform.createdPlaylists.single.$2, 'youtube_dQw4w9WgXcQ');
    expect(platform.createdPlaylists.single.$3, 'https://www.youtube.com/watch?v=dQw4w9WgXcQ');
    expect(platform.createdPlaylists.single.$4, true);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await platform.updates.close();
  });

  testWidgets('promptAddToPlaylist guides user when song is not downloaded and no account', (tester) async {
    final platform = PlaylistAddFlowMockPlatform();
    final controller = MusicController(platform);
    await controller.initialize();

    const song = PlaybackQueueItem(
      url: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      title: 'Never Gonna Give You Up',
      artist: 'Rick Astley',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: bcmusicTheme(light: false),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => promptAddToPlaylist(
                context,
                controller,
                song: song,
                rawTrackId: 'youtube_dQw4w9WgXcQ',
              ),
              child: const Text('Mở Thêm Playlist'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mở Thêm Playlist'));
    await tester.pumpAndSettle();

    // Select choice 2: Thêm ngay vào playlist có sẵn
    await tester.tap(find.text('Thêm ngay vào playlist có sẵn'));
    await tester.pumpAndSettle();

    // Verify dialog explains the song is not downloaded yet
    expect(find.text('Bài chưa có trên máy'), findsOneWidget);
    expect(find.text('Tải và thêm vào playlist offline'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await platform.updates.close();
  });
}
