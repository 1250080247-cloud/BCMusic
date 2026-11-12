import 'package:flutter/services.dart';

import 'models.dart';

abstract class MusicPlatform {
  Stream<LibrarySnapshot> get events;
  Future<LibrarySnapshot> getState();
  Future<OfflineTrack> resolve(String url);
  Future<PlaylistPreview> resolvePlaylist(String url);
  Future<LocalPlaylist> importSoundCloudPlaylist({
    required String name,
    required String sourceUrl,
    required List<OfflineTrack> tracks,
  });
  Future<void> enqueue(String id);
  Future<void> retry(String id);
  Future<void> remove(String id);
  Future<void> play(String id, {List<String>? queueIds});
  Future<void> playSource(String url, {bool autoTransition = false});
  Future<void> createPlaylist(
    String name, {
    String? trackId,
    String? url,
    bool enqueueIfMissing = false,
  });
  Future<void> deletePlaylist(String playlistId);
  Future<void> addToPlaylist(String playlistId, String id);
  Future<void> enqueueAndAddToPlaylist(
    String playlistId,
    String id, {
    String? url,
  });
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
  Future<void> saveLyrics(String trackId, String data);
  Future<String?> getLyrics(String trackId);
  Future<void> pause();
  Future<void> setSleepTimer(int? minutes, {bool atEndOfTrack = false});
  Future<void> cancelSleepTimer();
  Future<void> setRepeatMode(String mode);
  Future<void> setShuffle(bool enabled);
  Future<void> removeQueueItem(int index);
  Future<void> reorderQueue(int oldIndex, int newIndex);
}

class AndroidMusicPlatform implements MusicPlatform {
  static const _methods = MethodChannel('app.bcmusic.personal/methods');
  static const _spectrum = EventChannel('app.bcmusic.personal/spectrum');
  late final Stream<List<double>> spectrum = _spectrum
      .receiveBroadcastStream()
      .map((event) => (event as List).cast<double>());
  Future<void> recordSearch(String query) =>
      _methods.invokeMethod('recordSearch', {'query': query});
  Future<void> setRepeatOne(bool enabled) =>
      _methods.invokeMethod('setRepeatOne', {'enabled': enabled});
  @override
  Future<void> setRepeatMode(String mode) =>
      _methods.invokeMethod('setRepeatMode', {'mode': mode});
  @override
  Future<void> setShuffle(bool enabled) =>
      _methods.invokeMethod('setShuffle', {'enabled': enabled});
  @override
  Future<void> removeQueueItem(int index) =>
      _methods.invokeMethod('removeQueueItem', {'index': index});
  @override
  Future<void> reorderQueue(int oldIndex, int newIndex) =>
      _methods.invokeMethod('reorderQueue', {
        'oldIndex': oldIndex,
        'newIndex': newIndex,
      });

  Future<bool> exportCoverMp4(String url, String title) async =>
      await _methods.invokeMethod<bool>('exportCoverMp4', {
        'url': url,
        'title': title,
      }) ??
      false;

  Future<String?> getProfileCollections() =>
      _methods.invokeMethod<String>('getProfileCollections');
  Future<List<String>> getFavoriteIds() async =>
      await _methods.invokeListMethod<String>('getFavoriteIds') ?? [];
  Future<void> setFavorite(
    String accountId,
    Map<String, String> song,
    bool liked,
  ) => _methods.invokeMethod('setFavorite', {
    'accountId': accountId,
    'song': song,
    'liked': liked,
  });
  Future<void> saveWebPlaylistSong(
    Map<String, String> song, {
    String? playlistId,
    String? playlistName,
  }) => _methods.invokeMethod('saveWebPlaylistSong', {
    'song': song,
    'playlistId': playlistId,
    'playlistName': playlistName,
  });
  Future<void> removeWebPlaylistSong(String playlistId, String songId) =>
      _methods.invokeMethod('removeWebPlaylistSong', {
        'playlistId': playlistId,
        'songId': songId,
      });
  Future<String?> pickProfileImage() =>
      _methods.invokeMethod<String>('pickProfileImage');
  Future<void> updateProfile(String displayName, {String? image}) =>
      _methods.invokeMethod('updateProfile', {
        'displayName': displayName,
        'image': image,
      });

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
  Future<PlaylistPreview> resolvePlaylist(String url) async =>
      PlaylistPreview.fromMap(
        (await _methods.invokeMapMethod<Object?, Object?>('resolvePlaylist', {
          'url': url,
        }))!,
      );

  @override
  Future<LocalPlaylist> importSoundCloudPlaylist({
    required String name,
    required String sourceUrl,
    required List<OfflineTrack> tracks,
  }) async => LocalPlaylist.fromMap(
    (await _methods.invokeMapMethod<Object?, Object?>(
      'importSoundCloudPlaylist',
      {
        'name': name,
        'sourceUrl': sourceUrl,
        'tracks': tracks.map((t) => t.toMap()).toList(),
      },
    ))!,
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
  Future<void> playSource(String url, {bool autoTransition = false}) =>
      _methods.invokeMethod('playSource', {
        'url': url,
        'autoTransition': autoTransition,
      });
  @override
  Future<void> createPlaylist(
    String name, {
    String? trackId,
    String? url,
    bool enqueueIfMissing = false,
  }) => _methods.invokeMethod('createPlaylist', {
    'name': name,
    'trackId': trackId,
    'url': url,
    'enqueueIfMissing': enqueueIfMissing,
  });
  @override
  Future<void> deletePlaylist(String playlistId) =>
      _methods.invokeMethod('deletePlaylist', {'playlistId': playlistId});
  @override
  Future<void> addToPlaylist(String playlistId, String id) => _methods
      .invokeMethod('addToPlaylist', {'playlistId': playlistId, 'id': id});
  @override
  Future<void> enqueueAndAddToPlaylist(
    String playlistId,
    String id, {
    String? url,
  }) => _methods.invokeMethod('enqueueAndAddToPlaylist', {
    'playlistId': playlistId,
    'id': id,
    'url': url,
  });
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
  Future<void> openUrl(String url) =>
      _methods.invokeMethod('openUrl', {'url': url});
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
  @override
  Future<void> saveLyrics(String trackId, String data) =>
      _methods.invokeMethod('saveLyrics', {'trackId': trackId, 'data': data});
  @override
  Future<String?> getLyrics(String trackId) =>
      _methods.invokeMethod<String>('getLyrics', {'trackId': trackId});
  @override
  Future<void> pause() => _methods.invokeMethod('pause');
  @override
  Future<void> setSleepTimer(int? minutes, {bool atEndOfTrack = false}) =>
      _methods.invokeMethod('setSleepTimer', {
        'minutes': minutes,
        'atEndOfTrack': atEndOfTrack,
      });
  @override
  Future<void> cancelSleepTimer() => _methods.invokeMethod('cancelSleepTimer');
}
