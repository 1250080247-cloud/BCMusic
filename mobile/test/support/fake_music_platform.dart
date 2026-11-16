import 'dart:async';

import 'package:bcmusic/models.dart';
import 'package:bcmusic/platform_bridge.dart';

/// A MusicPlatform for widget tests. It records the calls the screens under
/// test make, and every other call is a no-op.
class FakeMusicPlatform implements MusicPlatform {
  final updates = StreamController<LibrarySnapshot>.broadcast(sync: true);
  LibrarySnapshot state = const LibrarySnapshot();
  final removed = <String>[];
  final retried = <String>[];

  @override
  Stream<LibrarySnapshot> get events => updates.stream;
  @override
  Future<LibrarySnapshot> getState() async => state;
  @override
  Future<OfflineTrack> resolve(String url) => throw UnimplementedError();
  @override
  Future<PlaylistPreview> resolvePlaylist(String url) =>
      throw UnimplementedError();
  @override
  Future<LocalPlaylist> importSoundCloudPlaylist({
    required String name,
    required String sourceUrl,
    required List<OfflineTrack> tracks,
  }) => throw UnimplementedError();
  @override
  Future<void> enqueue(String id) async {}
  @override
  Future<void> retry(String id) async {
    retried.add(id);
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
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
  Future<void> deletePlaylist(String playlistId, {bool removeDownloads = false}) async {}
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
