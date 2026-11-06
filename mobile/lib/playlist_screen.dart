import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'discovery_screen.dart';
import 'models.dart';
import 'platform_bridge.dart';
import 'track_widgets.dart';
import 'track_actions.dart';

Future<void> createLocalPlaylist(
  BuildContext context,
  MusicController controller, {
  OfflineTrack? initialTrack,
}) async {
  final name = await showDialog<String>(
    context: context,
    builder: (_) => const _PlaylistNameDialog(),
  );
  if (name != null) {
    await controller.createPlaylist(name, initialTrack: initialTrack);
  }
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog();

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  String _name = '';

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Tạo playlist'),
    content: TextField(
      autofocus: true,
      maxLength: 80,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(labelText: 'Tên playlist'),
      onChanged: (name) => setState(() => _name = name.trim()),
      onSubmitted: (_) {
        if (_name.isNotEmpty) Navigator.pop(context, _name);
      },
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Hủy'),
      ),
      FilledButton(
        onPressed: _name.isEmpty ? null : () => Navigator.pop(context, _name),
        child: const Text('Tạo'),
      ),
    ],
  );
}

Future<void> pickLocalPlaylist(
  BuildContext context,
  MusicController controller,
  OfflineTrack track,
) async {
  final playlists = controller.snapshot.playlists;
  if (playlists.isEmpty) {
    await createLocalPlaylist(context, controller, initialTrack: track);
    return;
  }
  final id = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Thêm vào danh sách phát'),
      children: [
        for (final playlist in playlists)
          ListTile(
            enabled: !playlist.trackIds.contains(track.id),
            title: Text(playlist.name),
            subtitle: playlist.trackIds.contains(track.id)
                ? const Text('Đã thêm')
                : null,
            onTap: playlist.trackIds.contains(track.id)
                ? null
                : () => Navigator.pop(context, playlist.id),
          ),
      ],
    ),
  );
  if (id != null && context.mounted) await controller.addToPlaylist(id, track);
}

Future<void> pickWebPlaylist(
  BuildContext context,
  AndroidMusicPlatform platform,
  String songId,
  PlaybackQueueItem song,
) async {
  try {
    final collections = await loadAccountCollections(platform);
    final playlists = AccountPlaylist.readAll(collections['playlists']);
    if (!context.mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Thêm vào playlist tài khoản'),
        children: [
          for (final playlist in playlists)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, playlist.id),
              child: Text(playlist.name),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Text('Tạo playlist mới'),
          ),
        ],
      ),
    );
    if (!context.mounted || selected == null) return;
    final name = selected.isEmpty
        ? await showDialog<String>(
            context: context,
            builder: (_) => const _PlaylistNameDialog(),
          )
        : null;
    if (!context.mounted || (selected.isEmpty && name == null)) return;
    await platform.saveWebPlaylistSong(
      {
        'id': songId,
        'title': song.title,
        'artist': song.artist,
        'sourceUrl': song.url,
        'thumbnail': ?song.artworkUrl,
      },
      playlistId: selected.isEmpty ? null : selected,
      playlistName: name,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bài hát đã có trong playlist.')),
      );
    }
  } on PlatformException catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Chưa mở được playlist.')),
      );
    }
  }
}

Future<Map<String, dynamic>> loadAccountCollections(
  AndroidMusicPlatform? platform,
) async {
  final raw = await platform?.getProfileCollections();
  return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
}

class AccountPlaylist {
  const AccountPlaylist(this.id, this.name, this.songs);
  final String id, name;
  final Map<String, PlaybackQueueItem> songs;

  static List<AccountPlaylist> readAll(Object? data) => data is List
      ? [
          for (final row in data.whereType<Map>())
            if (row['id'] case final String id when id.isNotEmpty)
              AccountPlaylist(id, row['name']?.toString() ?? 'Playlist', {
                if (row['songs'] case final List songs)
                  for (final song in songs.whereType<Map>())
                    if (song['id'] case final String songId)
                      songId: ?readAccountSong(song),
              }),
        ]
      : [];
}

PlaybackQueueItem? readAccountSong(Map row) {
  final id = row['id'];
  final source = row['sourceUrl'];
  final url = source is String && source.isNotEmpty
      ? source
      : id is String && RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(id)
      ? 'https://www.youtube.com/watch?v=$id'
      : null;
  if (url == null) return null;
  try {
    return PlaybackQueueItem(
      url: SourceLink.parse(url).url,
      title: row['title'] is String ? row['title'] as String : 'Bài hát',
      artist: row['artist'] is String ? row['artist'] as String : '',
      artworkUrl: row['thumbnail'] is String
          ? row['thumbnail'] as String
          : null,
    );
  } on FormatException {
    return null;
  }
}

Widget accountSongTile(
  MusicController controller,
  PlaybackQueueItem song,
  List<PlaybackQueueItem> queue, {
  Widget? trailing,
}) => ListTile(
  contentPadding: EdgeInsets.zero,
  leading: TrackArtwork(url: song.artworkUrl, size: 44),
  title: Text(song.title, maxLines: 2, overflow: TextOverflow.ellipsis),
  subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
  trailing: trailing,
  onTap: () => controller.playSource(
    song.url,
    queue: queue.map((item) => item.url),
    queueItems: queue,
  ),
);

class AccountPlaylistTile extends StatelessWidget {
  const AccountPlaylistTile({
    super.key,
    required this.controller,
    required this.playlist,
    required this.onReturn,
    this.cardWidth,
  });

  final MusicController controller;
  final AccountPlaylist playlist;
  final VoidCallback onReturn;
  final double? cardWidth;

  @override
  Widget build(BuildContext context) {
    if (cardWidth case final width?) {
      return _PlaylistCard(
        name: playlist.name,
        count: playlist.songs.length,
        width: width,
        artwork: PlaylistArtwork(
          urls: playlist.songs.values.map((song) => song.artworkUrl).toList(),
          size: width - 24,
        ),
        onTap: () => _open(context),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.queue_music_rounded),
      title: Text(playlist.name),
      subtitle: Text('${playlist.songs.length} bài'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _open(context),
    );
  }

  Future<void> _open(BuildContext context) async {
    final platform = controller.platform;
    if (platform is! AndroidMusicPlatform) return;
    final entries = Map.of(playlist.songs);
    final pending = <String>{};
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (context, update) {
            final queue = entries.values.toList();
            return Scaffold(
              appBar: AppBar(title: Text(playlist.name)),
              body: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (queue.isEmpty) const Text('Chưa có bài có thể phát.'),
                  for (final MapEntry(key: songId, value: song)
                      in entries.entries)
                    accountSongTile(
                      controller,
                      song,
                      queue,
                      trailing: TrackMenu(
                        title: song.title,
                        inPlaylist: true,
                        onSelected: (action) async {
                          switch (action) {
                            case TrackAction.share:
                              await shareSong(context, controller, song.url);
                            case TrackAction.playlist:
                              await pickWebPlaylist(
                                context,
                                platform,
                                songId,
                                song,
                              );
                            case TrackAction.queue:
                              enqueueSong(context, controller, song);
                            case TrackAction.info:
                              await showTrackInfo(context, song);
                            case TrackAction.remove:
                              if (!pending.add(songId)) return;
                              try {
                                await platform.removeWebPlaylistSong(
                                  playlist.id,
                                  songId,
                                );
                                if (context.mounted) {
                                  update(() => entries.remove(songId));
                                }
                              } on PlatformException catch (error) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        error.message ??
                                            'Chưa xóa được bài hát.',
                                      ),
                                    ),
                                  );
                                }
                              } finally {
                                pending.remove(songId);
                              }
                          }
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
    if (context.mounted) onReturn();
  }
}

class PlaylistScreen extends StatefulWidget {
  const PlaylistScreen({
    super.key,
    required this.controller,
    required this.active,
  });
  final MusicController controller;
  final bool active;

  @override
  State<PlaylistScreen> createState() => _PlaylistScreenState();
}

class _PlaylistScreenState extends State<PlaylistScreen> {
  Future<Map<String, dynamic>>? _collections;
  String? _accountKey;

  @override
  void initState() {
    super.initState();
    _updateAccount();
  }

  @override
  void didUpdateWidget(covariant PlaylistScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateAccount(reopened: widget.active && !oldWidget.active);
  }

  void _updateAccount({bool reopened = false}) {
    final account = widget.controller.snapshot.account;
    final key = account?.id ?? account?.username;
    final changed = key != _accountKey;
    if (changed) {
      _accountKey = key;
      _collections = null;
    }
    if (widget.active && key != null && (_collections == null || reopened)) {
      _loadAccount();
    }
  }

  void _loadAccount() {
    final platform = widget.controller.platform;
    _collections = loadAccountCollections(
      platform is AndroidMusicPlatform ? platform : null,
    );
  }

  void _refreshAccount() {
    if (_accountKey != null) setState(_loadAccount);
  }

  Widget _accountPlaylists() => FutureBuilder(
    future: _collections,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const LinearProgressIndicator(
          semanticsLabel: 'Đang tải playlist tài khoản',
        );
      }
      if (snapshot.hasError) {
        return DataMessage(
          message: 'Chưa tải được playlist tài khoản.',
          onRetry: _refreshAccount,
        );
      }
      final playlists = AccountPlaylist.readAll(snapshot.data?['playlists']);
      if (playlists.isEmpty) {
        return const Text('Chưa có playlist trong tài khoản.');
      }
      return _playlistGrid(
        playlists.length,
        (index, width) => AccountPlaylistTile(
          controller: widget.controller,
          playlist: playlists[index],
          onReturn: _refreshAccount,
          cardWidth: width,
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final playlists = controller.snapshot.playlists;
    final error = controller.snapshot.playlistError;
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          sliver: SliverList.list(
            children: [
              const Text(
                'Playlist',
                style: TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              if (_collections != null) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Playlist tài khoản',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Làm mới playlist tài khoản',
                      onPressed: _refreshAccount,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
                _accountPlaylists(),
                const SizedBox(height: 20),
              ],
              Text(
                'Playlist offline',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Gom những bài đã tải vào danh sách riêng trên thiết bị này.',
                style: TextStyle(color: context.palette.muted, height: 1.5),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: error != null || controller.loading
                    ? null
                    : () => createLocalPlaylist(context, controller),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Tạo playlist offline'),
              ),
              const SizedBox(height: 22),
              if (error != null)
                DataMessage(message: error)
              else if (controller.loading)
                const Center(child: CircularProgressIndicator())
              else if (playlists.isEmpty)
                const DataMessage(
                  message:
                      'Chưa có playlist nào. Tạo một danh sách để bắt đầu.',
                ),
              _playlistGrid(playlists.length, (index, width) {
                final playlist = playlists[index];
                return _PlaylistCard(
                  name: playlist.name,
                  count: playlist.trackIds.length,
                  width: width,
                  artwork: PlaylistArtwork(
                    tracks: controller.tracks
                        .where((track) => playlist.trackIds.contains(track.id))
                        .toList(),
                    size: width - 24,
                  ),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetail(
                        controller: controller,
                        playlistId: playlist.id,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

Widget _playlistGrid(
  int count,
  Widget Function(int index, double width) item,
) => LayoutBuilder(
  builder: (context, constraints) {
    final columns = constraints.maxWidth > 650 ? 3 : 2;
    final width = (constraints.maxWidth - 12 * (columns - 1)) / columns;
    return Wrap(
      spacing: 12,
      runSpacing: 16,
      children: [
        for (var index = 0; index < count; index++) item(index, width),
      ],
    );
  },
);

class _PlaylistCard extends StatelessWidget {
  const _PlaylistCard({
    required this.name,
    required this.count,
    required this.width,
    required this.artwork,
    required this.onTap,
  });
  final String name;
  final int count;
  final double width;
  final Widget artwork;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              artwork,
              const SizedBox(height: 12),
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '$count bài',
                style: TextStyle(color: context.palette.muted),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PlaylistDetail extends StatelessWidget {
  const PlaylistDetail({
    super.key,
    required this.controller,
    required this.playlistId,
  });
  final MusicController controller;
  final String playlistId;

  Future<void> _delete(BuildContext context, LocalPlaylist playlist) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa playlist?'),
        content: Text(
          'Xóa danh sách “${playlist.name}”. Các bài đã tải vẫn có trong thư viện.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa playlist'),
          ),
        ],
      ),
    );
    if (approved == true && context.mounted) {
      await controller.deletePlaylist(playlist.id);
      if (context.mounted &&
          !controller.snapshot.playlists.any(
            (item) => item.id == playlist.id,
          )) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _add(BuildContext context, List<OfflineTrack> tracks) async {
    final track = await showDialog<OfflineTrack>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Chọn bài đã tải'),
        children: [
          for (final item in tracks)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: ListTile(
                leading: TrackArtwork(path: item.artworkPath, size: 40),
                title: Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
        ],
      ),
    );
    if (track != null) await controller.addToPlaylist(playlistId, track);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final playlist = controller.snapshot.playlists
          .where((item) => item.id == playlistId)
          .firstOrNull;
      final library = {
        for (final track in controller.tracks.where((track) => track.isReady))
          track.id: track,
      };
      final tracks = (playlist?.trackIds ?? [])
          .map((id) => library[id])
          .whereType<OfflineTrack>()
          .toList();
      final available = library.values
          .where((item) => !(playlist?.trackIds.contains(item.id) ?? false))
          .toList();
      final queue = tracks.map((track) => track.id).toList();
      return Scaffold(
        appBar: AppBar(
          title: Text(playlist?.name ?? 'Playlist'),
          actions: [
            if (playlist != null)
              IconButton(
                tooltip: 'Xóa playlist',
                onPressed: () => _delete(context, playlist),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (controller.error case final error?) DataMessage(message: error),
            if (playlist == null)
              const DataMessage(message: 'Playlist không còn tồn tại.')
            else ...[
              Center(child: PlaylistArtwork(tracks: tracks, size: 180)),
              const SizedBox(height: 20),
              Text(
                playlist.name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                '${tracks.length} bài · ${formatTime(tracks.fold<int>(0, (total, track) => total + track.durationMs))}',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.palette.muted),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    style: playButtonStyle(context),
                    onPressed: tracks.isEmpty
                        ? null
                        : () => controller.play(tracks.first, queueIds: queue),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Phát playlist'),
                  ),
                  OutlinedButton.icon(
                    onPressed: available.isEmpty
                        ? null
                        : () => _add(context, available),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Thêm bài'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (tracks.isEmpty)
                DataMessage(
                  message: available.isEmpty
                      ? 'Hãy tải bài về thư viện trước.'
                      : 'Chọn bài đã tải để thêm vào playlist.',
                ),
              for (final track in tracks)
                ListTile(
                  leading: TrackArtwork(path: track.artworkPath, size: 46),
                  title: Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: controller.playback.trackId == track.id,
                  onTap: () => controller.play(track, queueIds: queue),
                  trailing: TrackMenu(
                    title: track.title,
                    inPlaylist: true,
                    onSelected: (action) {
                      final item = PlaybackQueueItem(
                        url: track.sourceUrl,
                        title: track.title,
                        artist: track.artist,
                        artworkUrl: track.artworkUrl,
                      );
                      switch (action) {
                        case TrackAction.share:
                          shareSong(context, controller, item.url);
                        case TrackAction.playlist:
                          pickLocalPlaylist(context, controller, track);
                        case TrackAction.remove:
                          controller.removeFromPlaylist(playlistId, track);
                        case TrackAction.queue:
                          enqueueSong(context, controller, item);
                        case TrackAction.info:
                          showTrackInfo(
                            context,
                            item,
                            durationMs: track.durationMs,
                            artworkPath: track.artworkPath,
                          );
                      }
                    },
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class PlaylistArtwork extends StatelessWidget {
  const PlaylistArtwork({
    super.key,
    this.tracks = const [],
    this.urls = const [],
    required this.size,
  });
  final List<OfflineTrack> tracks;
  final List<String?> urls;
  final double size;
  @override
  Widget build(BuildContext context) {
    final covers = [
      for (final track in tracks.take(4)) (track.artworkPath, track.artworkUrl),
      for (final url in urls.take(4)) (null, url),
    ];
    if (covers.isEmpty) return TrackArtwork(size: size);
    if (covers.length < 4) {
      final (path, url) = covers.first;
      return TrackArtwork(path: path, url: url, size: size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: size,
        child: Wrap(
          children: [
            for (final (path, url) in covers.take(4))
              TrackArtwork(path: path, url: url, size: size / 2),
          ],
        ),
      ),
    );
  }
}
