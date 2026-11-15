import 'dart:convert';

import 'models.dart';

const playlistBackupFormat = 'bcmusic.playlists';
const playlistBackupVersion = 1;
const maxBackupPlaylists = 100;
const maxBackupTracksPerPlaylist = 500;

class BackupTrack {
  const BackupTrack({
    required this.title,
    required this.artist,
    required this.sourceUrl,
  });
  final String title, artist, sourceUrl;
}

class BackupPlaylist {
  const BackupPlaylist({required this.name, required this.tracks});
  final String name;
  final List<BackupTrack> tracks;
}

class PlaylistBackup {
  const PlaylistBackup({required this.playlists, this.skippedEntries = 0});
  final List<BackupPlaylist> playlists;

  /// Entries dropped while reading: broken rows, unsupported links, extra tracks.
  final int skippedEntries;

  int get trackCount =>
      playlists.fold(0, (total, playlist) => total + playlist.tracks.length);
}

class EncodedBackup {
  const EncodedBackup({
    required this.text,
    required this.playlistCount,
    required this.trackCount,
    required this.skippedTracks,
  });
  final String text;
  final int playlistCount, trackCount, skippedTracks;
}

/// Writes local playlists as a portable JSON document. A track id that is no
/// longer in [tracks], or has no source link, cannot be restored, so it is left
/// out and counted in [EncodedBackup.skippedTracks].
EncodedBackup encodePlaylistBackup({
  required List<LocalPlaylist> playlists,
  required List<OfflineTrack> tracks,
  DateTime? exportedAt,
}) {
  final byId = {for (final track in tracks) track.id: track};
  var skipped = 0;
  var trackCount = 0;
  final rows = <Map<String, Object?>>[];
  for (final playlist in playlists) {
    final entries = <Map<String, Object?>>[];
    final seen = <String>{};
    for (final id in playlist.trackIds) {
      final track = byId[id];
      if (track == null || track.sourceUrl.isEmpty) {
        skipped++;
        continue;
      }
      if (!seen.add(track.sourceUrl)) continue;
      entries.add({
        'title': track.title,
        'artist': track.artist,
        'sourceUrl': track.sourceUrl,
      });
    }
    trackCount += entries.length;
    rows.add({'name': playlist.name, 'tracks': entries});
  }
  final text = const JsonEncoder.withIndent('  ').convert({
    'format': playlistBackupFormat,
    'version': playlistBackupVersion,
    'exportedAt': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
    'playlists': rows,
  });
  return EncodedBackup(
    text: text,
    playlistCount: rows.length,
    trackCount: trackCount,
    skippedTracks: skipped,
  );
}

/// Reads a document written by [encodePlaylistBackup]. Throws a
/// [FormatException] whose message can be shown to the user when the document
/// is not a BCMusic playlist backup. Broken entries inside a valid backup are
/// skipped and counted in [PlaylistBackup.skippedEntries].
PlaylistBackup decodePlaylistBackup(String input) {
  final Object? decoded;
  try {
    decoded = jsonDecode(input);
  } on FormatException {
    throw const FormatException('Nội dung không phải là bản sao lưu hợp lệ.');
  }
  if (decoded is! Map<String, dynamic> ||
      decoded['format'] != playlistBackupFormat) {
    throw const FormatException(
      'Đây không phải bản sao lưu playlist của BCMusic.',
    );
  }
  final version = decoded['version'];
  if (version is! int || version < 1) {
    throw const FormatException('Bản sao lưu thiếu số phiên bản.');
  }
  if (version > playlistBackupVersion) {
    throw const FormatException(
      'Bản sao lưu này được tạo bởi phiên bản BCMusic mới hơn.',
    );
  }
  final rows = decoded['playlists'];
  if (rows is! List) {
    throw const FormatException('Bản sao lưu không có danh sách playlist.');
  }
  if (rows.length > maxBackupPlaylists) {
    throw const FormatException(
      'Mỗi lần chỉ khôi phục tối đa $maxBackupPlaylists playlist.',
    );
  }

  var skipped = 0;
  final playlists = <BackupPlaylist>[];
  for (final row in rows) {
    if (row is! Map<String, dynamic>) {
      skipped++;
      continue;
    }
    final name = _cleanText(row['name'], 80);
    final rawTracks = row['tracks'];
    if (name.isEmpty || rawTracks is! List) {
      skipped++;
      continue;
    }
    final tracks = <BackupTrack>[];
    final seen = <String>{};
    for (final raw in rawTracks) {
      final url = raw is Map<String, dynamic>
          ? _canonicalUrl(raw['sourceUrl'])
          : null;
      if (raw is! Map<String, dynamic> || url == null) {
        skipped++;
        continue;
      }
      if (!seen.add(url)) continue;
      if (tracks.length >= maxBackupTracksPerPlaylist) {
        skipped++;
        continue;
      }
      tracks.add(
        BackupTrack(
          title: _cleanText(raw['title'], 200),
          artist: _cleanText(raw['artist'], 200),
          sourceUrl: url,
        ),
      );
    }
    playlists.add(BackupPlaylist(name: name, tracks: tracks));
  }
  return PlaylistBackup(playlists: playlists, skippedEntries: skipped);
}

class RestoreReport {
  const RestoreReport({
    this.playlistsCreated = 0,
    this.playlistsFailed = 0,
    this.tracksAdded = 0,
    this.tracksFailed = 0,
  });
  final int playlistsCreated, playlistsFailed, tracksAdded, tracksFailed;
}

/// Recreates the playlists in [backup] through the app's own actions. When a
/// playlist cannot be created, its tracks count as failed. When one track fails,
/// the restore counts it and carries on with the next one.
Future<RestoreReport> restorePlaylistBackup(
  PlaylistBackup backup, {
  required Future<String?> Function(String name) createPlaylist,
  required Future<void> Function(String playlistId, String sourceUrl) addTrack,
  void Function(int done, int total)? onProgress,
}) async {
  final total = backup.trackCount;
  var done = 0, created = 0, failedPlaylists = 0, added = 0, failed = 0;
  for (final playlist in backup.playlists) {
    String? playlistId;
    try {
      playlistId = await createPlaylist(playlist.name);
    } on Exception {
      playlistId = null;
    }
    if (playlistId == null) {
      failedPlaylists++;
      failed += playlist.tracks.length;
      done += playlist.tracks.length;
      onProgress?.call(done, total);
      continue;
    }
    created++;
    for (final track in playlist.tracks) {
      try {
        await addTrack(playlistId, track.sourceUrl);
        added++;
      } on Exception {
        failed++;
      }
      done++;
      onProgress?.call(done, total);
    }
  }
  return RestoreReport(
    playlistsCreated: created,
    playlistsFailed: failedPlaylists,
    tracksAdded: added,
    tracksFailed: failed,
  );
}

String _cleanText(Object? value, int maxLength) {
  final text = value is String ? value.trim() : '';
  return text.length <= maxLength ? text : text.substring(0, maxLength);
}

String? _canonicalUrl(Object? value) {
  if (value is! String || value.isEmpty) return null;
  try {
    return SourceLink.parse(value).url;
  } on Exception {
    return null;
  }
}
