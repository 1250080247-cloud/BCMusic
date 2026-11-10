import 'dart:async';

import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/app_theme.dart';
import 'package:bcmusic/models.dart';
import 'package:bcmusic/playlist_screen.dart';
import 'package:bcmusic/platform_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class AccountPlaylistTestPlatform implements MusicPlatform {
  final updates = StreamController<LibrarySnapshot>.broadcast(sync: true);
  final playedSources = <String>[];
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
  Future<void> setRepeatMode(String mode) async {}
  @override
  Future<void> setShuffle(bool enabled) async {}
  @override
  Future<void> removeQueueItem(int index) async {}
  @override
  Future<void> reorderQueue(int oldIndex, int newIndex) async {}
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
  testWidgets('AccountPlaylistDetail renders header, Play All and Shuffle buttons', (tester) async {
    final platform = AccountPlaylistTestPlatform();
    final controller = MusicController(platform);

    final testSongs = {
      'song1': const PlaybackQueueItem(
        url: 'https://www.youtube.com/watch?v=11111111111',
        title: 'Bài hát số 1',
        artist: 'Ca sĩ A',
      ),
      'song2': const PlaybackQueueItem(
        url: 'https://www.youtube.com/watch?v=22222222222',
        title: 'Bài hát số 2',
        artist: 'Ca sĩ B',
      ),
    };
    final playlist = AccountPlaylist('p1', 'Nhạc Yêu Thích Online', testSongs);

    await tester.pumpWidget(
      MaterialApp(
        theme: bcmusicTheme(light: false),
        home: AccountPlaylistDetail(
          controller: controller,
          playlist: playlist,
          onReturn: () {},
        ),
      ),
    );

    // Verify header details
    expect(find.text('Nhạc Yêu Thích Online'), findsWidgets);
    expect(find.text('2 bài'), findsOneWidget);
    expect(find.text('Phát tất cả'), findsOneWidget);
    expect(find.text('Trộn bài'), findsOneWidget);
    expect(find.text('Bài hát số 1'), findsOneWidget);
    expect(find.text('Bài hát số 2'), findsOneWidget);

    // Tap 'Phát tất cả'
    await tester.tap(find.text('Phát tất cả'));
    await tester.pump();
    expect(platform.playedSources, contains('https://www.youtube.com/watch?v=11111111111'));

    // Tap 'Trộn bài'
    await tester.tap(find.text('Trộn bài'));
    await tester.pump();
    expect(platform.playedSources.length, 2);

    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    await platform.updates.close();
  });
}
