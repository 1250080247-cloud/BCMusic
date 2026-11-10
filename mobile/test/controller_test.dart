import 'dart:async';

import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/models.dart';
import 'package:bcmusic/platform_bridge.dart';
import 'package:flutter_test/flutter_test.dart';

const sample = OfflineTrack(
  id: 'youtube_M7lc1UVf-VE',
  title: 'Bài thử',
  artist: 'Nghệ sĩ',
  sourceUrl: 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
  provider: 'youtube',
  status: 'preview',
);

class FakeMusicPlatform implements MusicPlatform {
  final updates = StreamController<LibrarySnapshot>.broadcast(sync: true);
  final pending = <String, Completer<OfflineTrack>>{};
  final enqueued = <String>[];
  final playedSources = <String>[];
  final skips = <int>[];
  LibrarySnapshot state = const LibrarySnapshot();
  @override
  Stream<LibrarySnapshot> get events => updates.stream;
  @override
  Future<LibrarySnapshot> getState() async => state;
  @override
  Future<OfflineTrack> resolve(String url) =>
      (pending[url] = Completer()).future;
  @override
  Future<void> enqueue(String id) async {
    enqueued.add(id);
  }

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
  Future<void> authenticate(
    String username,
    String password, {
    String? displayName,
  }) async {}
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
  test('queued song advances after the current source ends', () async {
    final platform = FakeMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();
    const first = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
    expect(
      controller.enqueueSong(
        const PlaybackQueueItem(
          url: 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
          title: 'Bài tiếp theo',
          artist: 'BCMusic',
        ),
      ),
      isTrue,
    );
    expect(platform.playedSources, isEmpty);
    await controller.playSource(first);
    expect(controller.canSkip(1), isTrue);
    platform.updates.add(
      const LibrarySnapshot(
        playback: PlaybackState(trackId: 'first', ended: true, offline: false),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(platform.playedSources, [first, sample.sourceUrl]);
    controller.dispose();
    await platform.updates.close();
  });

  test('download action resolves and enqueues the selected track', () async {
    final platform = FakeMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();
    final operation = controller.downloadSource(sample.sourceUrl);
    platform.pending[sample.sourceUrl]!.complete(sample);
    await operation;
    expect(platform.enqueued, [sample.id]);
    expect(controller.preview, isNull);
    controller.dispose();
    await platform.updates.close();
  });

  test(
    'online playback skips within its list, then uses native offline controls',
    () async {
      const first = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
      final platform = FakeMusicPlatform();
      final controller = MusicController(platform);
      await controller.initialize();
      await controller.playSource(first, queue: [first, sample.sourceUrl]);
      expect(controller.canSkip(-1), isFalse);
      expect(controller.canSkip(1), isTrue);
      await controller.skip(1);
      expect(controller.canSkip(1), isFalse);
      expect(controller.canSkip(-1), isTrue);
      await controller.skip(-1);
      expect(platform.playedSources, [first, sample.sourceUrl, first]);

      await controller.play(sample);
      platform.updates.add(
        const LibrarySnapshot(playback: PlaybackState(hasNext: true)),
      );
      await controller.skip(1);
      expect(platform.skips, [1]);
      controller.dispose();
      await platform.updates.close();
    },
  );

  test('account avatar uses the BCMusic profile endpoint', () {
    final profile = AccountProfile.fromMap({'id': '0123456789abcdef01234567'});
    expect(
      profile.avatarUri.toString(),
      'https://bc-music-gilt.vercel.app/api/user/avatar?userId=0123456789abcdef01234567',
    );
    expect(
      AccountProfile.fromMap({'id': 'https://elsewhere.test/'}).avatarUri,
      isNull,
    );
  });

  test('invalid link stops before the native resolver', () async {
    final platform = FakeMusicPlatform();
    final controller = MusicController(platform);
    await controller.inspect('https://evil.test/audio');
    expect(platform.pending, isEmpty);
    expect(controller.error, isNotNull);
    controller.dispose();
    await platform.updates.close();
  });

  test('preview requires explicit download action', () async {
    final platform = FakeMusicPlatform();
    final controller = MusicController(platform);
    final inspection = controller.inspect(sample.sourceUrl);
    platform.pending[sample.sourceUrl]!.complete(sample);
    await inspection;
    expect(controller.preview?.id, sample.id);
    expect(platform.enqueued, isEmpty);
    await controller.downloadPreview();
    expect(platform.enqueued, [sample.id]);
    expect(controller.preview, isNull);
    controller.dispose();
    await platform.updates.close();
  });

  test('late result cannot overwrite newer preview', () async {
    final platform = FakeMusicPlatform();
    final controller = MusicController(platform);
    final first = controller.inspect(sample.sourceUrl);
    final second = controller.inspect('https://soundcloud.com/artist/track');
    const newer = OfflineTrack(
      id: 'soundcloud_123',
      title: 'Bài mới',
      artist: '',
      sourceUrl: 'https://soundcloud.com/artist/track',
      provider: 'soundcloud',
      status: 'preview',
    );
    platform.pending[newer.sourceUrl]!.complete(newer);
    await second;
    platform.pending[sample.sourceUrl]!.complete(sample);
    await first;
    expect(controller.preview?.id, newer.id);
    expect(controller.resolving, isFalse);
    controller.dispose();
    await platform.updates.close();
  });

  test(
    'opening app restores completed offline library without resolving URLs',
    () async {
      final platform = FakeMusicPlatform();
      platform.state = LibrarySnapshot(
        tracks: [
          OfflineTrack.fromMap({...sample.toMap(), 'status': 'completed'}),
        ],
      );
      final controller = MusicController(platform);
      await controller.initialize();
      expect(controller.tracks.single.isReady, isTrue);
      expect(platform.pending, isEmpty);
      controller.dispose();
      await platform.updates.close();
    },
  );
}
