import 'dart:convert';

import 'package:bcmusic/models.dart';
import 'package:bcmusic/playlist_backup.dart';
import 'package:flutter_test/flutter_test.dart';

const _videoA = 'dQw4w9WgXcQ';
const _videoB = 'M7lc1UVf-VE';
const _videoC = 'jNQXAC9IVRw';
const _trackA = 'youtube_$_videoA';
const _trackB = 'youtube_$_videoB';

String _url(String videoId) => 'https://www.youtube.com/watch?v=$videoId';

OfflineTrack _track(String id, String videoId, {String title = 'Bài'}) =>
    OfflineTrack(
      id: id,
      title: title,
      artist: 'Ca sĩ',
      sourceUrl: _url(videoId),
      provider: 'youtube',
      status: 'completed',
    );

void main() {
  final tracks = [
    _track(_trackA, _videoA, title: 'Một'),
    _track(_trackB, _videoB, title: 'Hai'),
  ];
  final playlists = [
    const LocalPlaylist(
      id: 'p1',
      name: 'Yêu thích',
      trackIds: [_trackA, _trackB],
    ),
    const LocalPlaylist(id: 'p2', name: 'Trống'),
  ];

  test('encode writes a versioned document with each playlist and its links', () {
    final encoded = encodePlaylistBackup(
      playlists: playlists,
      tracks: tracks,
      exportedAt: DateTime.utc(2026, 11, 15, 9),
    );
    final json = jsonDecode(encoded.text) as Map<String, dynamic>;
    expect(json['format'], playlistBackupFormat);
    expect(json['version'], playlistBackupVersion);
    expect(json['exportedAt'], '2026-11-15T09:00:00.000Z');
    expect(encoded.playlistCount, 2);
    expect(encoded.trackCount, 2);
    expect(encoded.skippedTracks, 0);

    final first = (json['playlists'] as List).first as Map<String, dynamic>;
    expect(first['name'], 'Yêu thích');
    expect(
      (first['tracks'] as List).map((row) => (row as Map)['sourceUrl']),
      [_url(_videoA), _url(_videoB)],
    );
  });

  test('encode leaves out tracks no longer in the library and repeated links', () {
    final encoded = encodePlaylistBackup(
      playlists: [
        const LocalPlaylist(
          id: 'p',
          name: 'Lộn xộn',
          trackIds: [_trackA, 'youtube_da_xoa', _trackA],
        ),
      ],
      tracks: tracks,
    );
    expect(encoded.trackCount, 1);
    expect(encoded.skippedTracks, 1);
  });

  test('decode reads back what encode wrote', () {
    final encoded = encodePlaylistBackup(playlists: playlists, tracks: tracks);
    final backup = decodePlaylistBackup(encoded.text);
    expect(backup.playlists.map((playlist) => playlist.name), [
      'Yêu thích',
      'Trống',
    ]);
    expect(
      backup.playlists.first.tracks.map((track) => track.title),
      ['Một', 'Hai'],
    );
    expect(backup.trackCount, 2);
    expect(backup.skippedEntries, 0);
  });

  test('decode rejects text that is not a BCMusic playlist backup', () {
    expect(
      () => decodePlaylistBackup('không phải JSON'),
      throwsFormatException,
    );
    expect(
      () => decodePlaylistBackup(
        '{"format":"other-app","version":1,"playlists":[]}',
      ),
      throwsFormatException,
    );
    expect(
      () => decodePlaylistBackup(
        '{"format":"bcmusic.playlists","version":2,"playlists":[]}',
      ),
      throwsFormatException,
    );
    expect(
      () => decodePlaylistBackup('{"format":"bcmusic.playlists","version":1}'),
      throwsFormatException,
    );
  });

  test('decode skips broken rows and unsupported links but keeps the rest', () {
    const text = '''
{"format":"bcmusic.playlists","version":1,"playlists":[
  {"name":"Ổn","tracks":[
    {"title":"Tốt","artist":"A","sourceUrl":"https://www.youtube.com/watch?v=dQw4w9WgXcQ"},
    {"title":"Lạ","artist":"B","sourceUrl":"https://example.com/song.mp3"},
    "không phải object",
    {"title":"Lặp","artist":"A","sourceUrl":"https://youtu.be/dQw4w9WgXcQ"}
  ]},
  {"name":"   ","tracks":[]},
  42
]}''';
    final backup = decodePlaylistBackup(text);
    expect(backup.playlists.map((playlist) => playlist.name), ['Ổn']);
    expect(backup.playlists.single.tracks.map((track) => track.title), ['Tốt']);
    expect(backup.skippedEntries, 4);
  });

  test('decode caps long names and refuses more than 100 playlists at once', () {
    final longName = 'x' * 200;
    final backup = decodePlaylistBackup(
      '{"format":"bcmusic.playlists","version":1,'
      '"playlists":[{"name":"$longName","tracks":[]}]}',
    );
    expect(backup.playlists.single.name.length, 80);

    final many = List.generate(
      maxBackupPlaylists + 1,
      (index) => '{"name":"p$index","tracks":[]}',
    ).join(',');
    expect(
      () => decodePlaylistBackup(
        '{"format":"bcmusic.playlists","version":1,"playlists":[$many]}',
      ),
      throwsFormatException,
    );
  });

  test('restore recreates playlists, reports progress and continues past failures', () async {
    final backup = PlaylistBackup(
      playlists: [
        BackupPlaylist(
          name: 'Một',
          tracks: [
            BackupTrack(title: 'a', artist: '', sourceUrl: _url(_videoA)),
            BackupTrack(title: 'b', artist: '', sourceUrl: _url(_videoB)),
          ],
        ),
        BackupPlaylist(
          name: 'Hỏng',
          tracks: [
            BackupTrack(title: 'c', artist: '', sourceUrl: _url(_videoC)),
          ],
        ),
      ],
    );
    final created = <String>[];
    final added = <String>[];
    final progress = <(int, int)>[];

    final report = await restorePlaylistBackup(
      backup,
      createPlaylist: (name) async {
        if (name == 'Hỏng') return null;
        created.add(name);
        return 'new_$name';
      },
      addTrack: (playlistId, url) async {
        if (url == _url(_videoB)) throw Exception('mất mạng');
        added.add('$playlistId ${url.split('=').last}');
      },
      onProgress: (done, total) => progress.add((done, total)),
    );

    expect(created, ['Một']);
    expect(added, ['new_Một $_videoA']);
    expect(report.playlistsCreated, 1);
    expect(report.playlistsFailed, 1);
    expect(report.tracksAdded, 1);
    expect(report.tracksFailed, 2);
    expect(progress, [(1, 3), (2, 3), (3, 3)]);
  });
}
