import 'package:flutter/services.dart';

import 'models.dart';

abstract class MusicPlatform {
  Stream<LibrarySnapshot> get events;
  Future<LibrarySnapshot> getState();
  Future<OfflineTrack> resolve(String url);
  Future<void> enqueue(String id);
  Future<void> retry(String id);
  Future<void> remove(String id);
  Future<void> play(String id, {List<String>? queueIds});
  Future<void> playSource(String url);
  Future<void> createPlaylist(String name, {String? trackId});
  Future<void> deletePlaylist(String playlistId);
  Future<void> addToPlaylist(String playlistId, String id);
  Future<void> removeFromPlaylist(String playlistId, String id);
  Future<void> togglePlay();
  Future<void> seek(int positionMs);
  Future<void> skip(int direction);
  Future<void> openWebsite();
  Future<void> updatePreferences(Map<String, Object> changes);
  Future<void> authenticate(
    String username,
    String password, {
    String? displayName,
  });
  Future<void> startGoogle();
  Future<void> signOut();
  Future<void> clearAccountError();
}

class AndroidMusicPlatform implements MusicPlatform {
  static const _methods = MethodChannel('app.bcmusic.personal/methods');
  Future<void> setRepeatOne(bool enabled) =>
      _methods.invokeMethod('setRepeatOne', {'enabled': enabled});

  Future<bool> exportCoverMp4(String url, String title) async =>
      await _methods.invokeMethod<bool>('exportCoverMp4', {
        'url': url,
        'title': title,
      }) ??
      false;

  Future<void> shareTrack(String url) =>
      _methods.invokeMethod('shareTrack', {'url': url});

  static const _events = EventChannel('app.bcmusic.personal/events');

  @override
  Stream<LibrarySnapshot> get events => _events.receiveBroadcastStream().map(
    (value) =>
        LibrarySnapshot.fromMap(Map<Object?, Object?>.from(value as Map)),
  );

  @override
  Future<LibrarySnapshot> getState() async => LibrarySnapshot.fromMap(
    (await _methods.invokeMapMethod<Object?, Object?>('getState')) ?? {},
  );

  @override
  Future<OfflineTrack> resolve(String url) async => OfflineTrack.fromMap(
    (await _methods.invokeMapMethod<Object?, Object?>('resolve', {
      'url': url,
    }))!,
  );

  @override
  Future<void> enqueue(String id) =>
      _methods.invokeMethod('enqueue', {'id': id});
  @override
  Future<void> retry(String id) => _methods.invokeMethod('retry', {'id': id});
  @override
  Future<void> remove(String id) => _methods.invokeMethod('remove', {'id': id});
  @override
  Future<void> play(String id, {List<String>? queueIds}) =>
      _methods.invokeMethod('play', {'id': id, 'queueIds': queueIds});
  @override
  Future<void> playSource(String url) =>
      _methods.invokeMethod('playSource', {'url': url});
  @override
  Future<void> createPlaylist(String name, {String? trackId}) => _methods
      .invokeMethod('createPlaylist', {'name': name, 'trackId': trackId});
  @override
  Future<void> deletePlaylist(String playlistId) =>
      _methods.invokeMethod('deletePlaylist', {'playlistId': playlistId});
  @override
  Future<void> addToPlaylist(String playlistId, String id) => _methods
      .invokeMethod('addToPlaylist', {'playlistId': playlistId, 'id': id});
  @override
  Future<void> removeFromPlaylist(String playlistId, String id) => _methods
      .invokeMethod('removeFromPlaylist', {'playlistId': playlistId, 'id': id});
  @override
  Future<void> togglePlay() => _methods.invokeMethod('togglePlay');
  @override
  Future<void> seek(int positionMs) =>
      _methods.invokeMethod('seek', {'positionMs': positionMs});
  @override
  Future<void> skip(int direction) =>
      _methods.invokeMethod('skip', {'direction': direction});
  @override
  Future<void> openWebsite() => _methods.invokeMethod('openWebsite');
  @override
  Future<void> updatePreferences(Map<String, Object> changes) =>
      _methods.invokeMethod('updatePreferences', changes);
  @override
  Future<void> authenticate(
    String username,
    String password, {
    String? displayName,
  }) => _methods.invokeMethod(displayName == null ? 'signIn' : 'register', {
    'username': username,
    'password': password,
    'displayName': displayName,
  });
  @override
  Future<void> startGoogle() => _methods.invokeMethod('startGoogle');
  @override
  Future<void> signOut() => _methods.invokeMethod('signOut');
  @override
  Future<void> clearAccountError() =>
      _methods.invokeMethod('clearAccountError');
}
