import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'discovery_screen.dart';
import 'models.dart';
import 'platform_bridge.dart';
import 'track_actions.dart';
import 'track_widgets.dart';

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
    backgroundColor: const Color(0xff1b1d2b),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: const BorderSide(color: Color(0x2ed1c2e3)),
    ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: const Color(0x1abda1e4),
            border: Border.all(color: const Color(0x28c6ade3)),
          ),
          child: const Icon(
            Icons.queue_music_rounded,
            color: Color(0xffc1a6dc),
          ),
        ),
        const Text(
          'Một playlist. Một cảm xúc.',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          'Lưu lại những giai điệu dành riêng cho bạn.',
          style: TextStyle(fontSize: 12.5, color: context.palette.muted),
        ),
      ],
    ),
    content: TextField(
      autofocus: true,
      maxLength: 80,
      textInputAction: TextInputAction.done,
      decoration: const InputDecoration(
        labelText: 'Tên playlist',
        hintText: 'Ví dụ: Những ngày rất chill',
      ),
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
        style: playButtonStyle(context),
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
      backgroundColor: const Color(0xff1b1d2b),
      title: const Text('Thêm vào danh sách phát'),
      children: [
        for (final playlist in playlists)
          ListTile(
            enabled: !playlist.trackIds.contains(track.id),
            leading: const Icon(
              Icons.queue_music_rounded,
              color: Color(0xffc2abf3),
            ),
            title: Text(playlist.name),
            subtitle: playlist.trackIds.contains(track.id)
                ? const Text('Đã thêm')
                : Text('${playlist.trackIds.length} bài hát'),
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
        backgroundColor: const Color(0xff1b1d2b),
        title: const Text('Thêm vào playlist tài khoản'),
        children: [
          for (final playlist in playlists)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, playlist.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(playlist.name),
              ),
            ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, ''),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Text(
                '+ Tạo playlist mới',
                style: TextStyle(
                  color: Color(0xffc2abf3),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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

enum AddToPlaylistChoice { downloadOffline, existingPlaylist }

Future<void> promptAddToPlaylist(
  BuildContext context,
  MusicController controller, {
  required PlaybackQueueItem song,
  String? songId,
  String? rawTrackId,
}) async {
  final ready = controller.tracks
      .where(
        (track) =>
            track.isReady &&
            (track.sourceUrl == song.url ||
                (rawTrackId != null && track.id == rawTrackId)),
      )
      .firstOrNull;

  final effectiveTrackId =
      ready?.id ??
      rawTrackId ??
      (songId != null && RegExp(r'^(youtube|soundcloud)_').hasMatch(songId)
          ? songId
          : (songId != null && songId.length == 11
                ? 'youtube_$songId'
                : deriveTrackId(song.url)));

  final choice = await showModalBottomSheet<AddToPlaylistChoice>(
    context: context,
    useSafeArea: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                TrackArtwork(url: song.artworkUrl, size: 52),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.palette.muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x38baa2d0), Color(0x0affffff)],
                ),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0x1abda1e4),
                ),
                child: const Icon(
                  Icons.download_for_offline_rounded,
                  color: Color(0xffc2abf3),
                ),
              ),
              title: const Text(
                'Tải và thêm vào playlist offline',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Tải về thiết bị và tự động gắn vào playlist offline.',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () =>
                  Navigator.pop(context, AddToPlaylistChoice.downloadOffline),
            ),
            const SizedBox(height: 6),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: const Color(0x1abda1e4),
                ),
                child: const Icon(
                  Icons.playlist_add_rounded,
                  color: Color(0xffc2abf3),
                ),
              ),
              title: const Text(
                'Thêm ngay vào playlist có sẵn',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              subtitle: const Text(
                'Thêm vào playlist tài khoản web hoặc playlist offline.',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () =>
                  Navigator.pop(context, AddToPlaylistChoice.existingPlaylist),
            ),
          ],
        ),
      ),
    ),
  );

  if (!context.mounted || choice == null) return;

  if (choice == AddToPlaylistChoice.downloadOffline) {
    await _handleDownloadAndAddToPlaylist(
      context,
      controller,
      song,
      effectiveTrackId,
    );
  } else {
    await _handleAddToExistingPlaylist(
      context,
      controller,
      song,
      songId,
      ready,
      effectiveTrackId,
    );
  }
}

Future<void> _handleDownloadAndAddToPlaylist(
  BuildContext context,
  MusicController controller,
  PlaybackQueueItem song,
  String trackId,
) async {
  final playlists = controller.snapshot.playlists;
  final selected = await showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      backgroundColor: const Color(0xff1b1d2b),
      title: const Text('Chọn playlist offline'),
      children: [
        for (final playlist in playlists)
          ListTile(
            enabled: !playlist.trackIds.contains(trackId),
            title: Text(playlist.name),
            subtitle: playlist.trackIds.contains(trackId)
                ? const Text('Đã có trong playlist')
                : Text('${playlist.trackIds.length} bài'),
            onTap: playlist.trackIds.contains(trackId)
                ? null
                : () => Navigator.pop(context, playlist.id),
          ),
        ListTile(
          leading: const Icon(Icons.add_rounded, color: Color(0xffc2abf3)),
          title: const Text('Tạo playlist mới'),
          onTap: () => Navigator.pop(context, '__new__'),
        ),
      ],
    ),
  );

  if (!context.mounted || selected == null) return;

  if (selected == '__new__') {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _PlaylistNameDialog(),
    );
    if (!context.mounted || name == null || name.isEmpty) return;
    try {
      await controller.createPlaylist(
        name,
        trackId: trackId,
        url: song.url,
        enqueueIfMissing: true,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã tạo “$name” và bắt đầu tải bài hát.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chưa tạo được playlist: $e')),
        );
      }
    }
  } else {
    try {
      await controller.enqueueAndAddToPlaylist(
        selected,
        trackId,
        url: song.url,
      );
      final playlist = playlists.where((p) => p.id == selected).firstOrNull;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đang tải và sẽ tự động thêm vào “${playlist?.name ?? 'playlist'}”.',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Chưa thêm được bài vào playlist: $e')),
        );
      }
    }
  }
}

Future<void> _handleAddToExistingPlaylist(
  BuildContext context,
  MusicController controller,
  PlaybackQueueItem song,
  String? songId,
  OfflineTrack? readyTrack,
  String trackId,
) async {
  final platform = controller.platform;
  final account = controller.snapshot.account;

  if (account != null && platform is AndroidMusicPlatform) {
    final id =
        songId ??
        (trackId.startsWith('youtube_')
            ? trackId.replaceFirst('youtube_', '')
            : trackId);
    await pickWebPlaylist(context, platform, id, song);
    return;
  }

  if (readyTrack != null) {
    await pickLocalPlaylist(context, controller, readyTrack);
    return;
  }

  final proceed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xff1b1d2b),
      title: const Text('Bài chưa có trên máy'),
      content: const Text(
        'Bài hát này chưa được tải về máy nên chưa thể thêm trực tiếp vào playlist offline.\n\n'
        'Bạn có thể chọn "Tải và thêm vào playlist offline" hoặc đăng nhập tài khoản để lưu vào playlist online.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Đóng'),
        ),
        FilledButton(
          style: playButtonStyle(context),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Tải và thêm vào playlist offline'),
        ),
      ],
    ),
  );

  if (proceed == true && context.mounted) {
    await _handleDownloadAndAddToPlaylist(context, controller, song, trackId);
  }
}

Future<Map<String, dynamic>> loadAccountCollections(
  AndroidMusicPlatform? platform,
) async {
  final raw = await platform?.getProfileCollections();
  return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
}

Widget accountSongTile(
  MusicController controller,
  PlaybackQueueItem song,
  List<PlaybackQueueItem> queue, {
  Widget? trailing,
}) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Material(
    color: const Color(0x88191d28),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: Color(0x12ffffff)),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      leading: TrackArtwork(url: song.artworkUrl, size: 46),
      title: Text(
        song.title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11.5, color: Color(0xff8e849e)),
      ),
      trailing: trailing,
      onTap: () => controller.playSource(
        song.url,
        queue: queue.map((item) => item.url),
        queueItems: queue,
      ),
    ),
  ),
);

class AccountPlaylistDetail extends StatefulWidget {
  const AccountPlaylistDetail({
    super.key,
    required this.controller,
    required this.playlist,
    required this.onReturn,
  });

  final MusicController controller;
  final AccountPlaylist playlist;
  final VoidCallback onReturn;

  @override
  State<AccountPlaylistDetail> createState() => _AccountPlaylistDetailState();
}

class _AccountPlaylistDetailState extends State<AccountPlaylistDetail> {
  late Map<String, PlaybackQueueItem> _entries;
  final _pending = <String>{};

  @override
  void initState() {
    super.initState();
    _entries = Map.of(widget.playlist.songs);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final platform = controller.platform;
    final queue = _entries.values.toList();
    final urls = _entries.values.map((s) => s.artworkUrl).toList();

    return Scaffold(
      appBar: AppBar(title: Text(widget.playlist.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
        children: [
          // .playlist-detail trong App.tsx
          Container(
            padding: const EdgeInsets.only(bottom: 24),
            margin: const EdgeInsets.only(bottom: 20),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x14ffffff))),
            ),
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(19),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x389e7db0),
                        blurRadius: 45,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: PlaylistArtwork(urls: urls, size: 180),
                ),
                const SizedBox(height: 20),
                const Text(
                  'YOUR PERSONAL PLAYLIST',
                  style: TextStyle(
                    fontSize: 9,
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff8f84a9),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.playlist.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_entries.length} bài',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xffb6a5c4),
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      style: playButtonStyle(context),
                      onPressed: _entries.isEmpty
                          ? null
                          : () => controller.playAccountPlaylist(
                              AccountPlaylist(
                                widget.playlist.id,
                                widget.playlist.name,
                                _entries,
                              ),
                              shuffle: false,
                            ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Phát tất cả'),
                    ),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: const StadiumBorder(),
                        side: const BorderSide(color: Color(0x38c2b4dd)),
                      ),
                      onPressed: _entries.isEmpty
                          ? null
                          : () => controller.playAccountPlaylist(
                              AccountPlaylist(
                                widget.playlist.id,
                                widget.playlist.name,
                                _entries,
                              ),
                              shuffle: true,
                            ),
                      icon: const Icon(Icons.shuffle_rounded, size: 18),
                      label: const Text('Trộn bài'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_entries.isEmpty)
            const DataMessage(message: 'Chưa có bài nào trong playlist này.'),
          for (final MapEntry(key: songId, value: song) in _entries.entries)
            accountSongTile(
              controller,
              song,
              queue,
              trailing: TrackMenu(
                title: song.title,
                artist: song.artist,
                artworkUrl: song.artworkUrl,
                inPlaylist: true,
                onSelected: (action) async {
                  if (platform is! AndroidMusicPlatform) return;
                  switch (action) {
                    case TrackAction.share:
                      await shareSong(context, controller, song.url);
                    case TrackAction.playlist:
                      await promptAddToPlaylist(
                        context,
                        controller,
                        song: song,
                        songId: songId,
                      );
                    case TrackAction.queue:
                      enqueueSong(context, controller, song);
                    case TrackAction.info:
                      await showTrackInfo(context, song);
                    case TrackAction.remove:
                      if (!_pending.add(songId)) return;
                      try {
                        await platform.removeWebPlaylistSong(
                          widget.playlist.id,
                          songId,
                        );
                        if (context.mounted) {
                          setState(() => _entries.remove(songId));
                        }
                      } on PlatformException catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                error.message ?? 'Chưa xóa được bài hát.',
                              ),
                            ),
                          );
                        }
                      } finally {
                        _pending.remove(songId);
                      }
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

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
        offline: false,
        width: width,
        artwork: PlaylistArtwork(
          urls: playlist.songs.values.map((song) => song.artworkUrl).toList(),
          size: width - 22,
        ),
        onTap: () => _open(context),
        onPlay: playlist.songs.isEmpty
            ? null
            : () => controller.playAccountPlaylist(playlist),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(
        Icons.queue_music_rounded,
        color: Color(0xffc2abf3),
      ),
      title: Text(playlist.name),
      subtitle: Text('${playlist.songs.length} bài'),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => _open(context),
    );
  }

  Future<void> _open(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => AccountPlaylistDetail(
          controller: controller,
          playlist: playlist,
          onReturn: onReturn,
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

  Future<void> _createWebPlaylist() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _PlaylistNameDialog(),
    );
    if (name == null || !mounted) return;
    final platform = widget.controller.platform;
    if (platform is! AndroidMusicPlatform) return;
    try {
      await platform.saveWebPlaylistSong(const {}, playlistName: name);
      if (mounted) _refreshAccount();
    } on PlatformException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message ?? 'Chưa tạo được playlist.')),
        );
      }
    }
  }

  Widget _accountPlaylists() => FutureBuilder(
    future: _collections,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: LinearProgressIndicator(
            semanticsLabel: 'Đang tải playlist tài khoản',
          ),
        );
      }
      if (snapshot.hasError) {
        return DataMessage(
          message: 'Chưa tải được playlist tài khoản.',
          onRetry: _refreshAccount,
        );
      }
      final playlists = AccountPlaylist.readAll(snapshot.data?['playlists']);
      return _playlistGrid(
        playlists.length + 1,
        (index, width) {
          if (index == playlists.length) {
            return _PlaylistCreateCard(
              width: width,
              onTap: _createWebPlaylist,
            );
          }
          return AccountPlaylistTile(
            controller: widget.controller,
            playlist: playlists[index],
            onReturn: _refreshAccount,
            cardWidth: width,
          );
        },
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
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 130),
          sliver: SliverList.list(
            children: [
              const Text(
                'COLLECT YOUR FAVORITE FEELINGS',
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 1.8,
                  color: Color(0xff8f84a9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Playlist của bạn',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Mỗi playlist, một câu chuyện. Viết nên câu chuyện của bạn.',
                style: TextStyle(color: context.palette.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 22),

              // 1. Playlist tài khoản (.playlist-section)
              if (_collections != null) ...[
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Playlist tài khoản',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Làm mới playlist tài khoản',
                      onPressed: _refreshAccount,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _accountPlaylists(),
                const SizedBox(height: 28),
              ],

              // 2. Playlist offline (.playlist-section)
              Row(
                children: const [
                  Expanded(
                    child: Text(
                      'Playlist offline',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (error != null)
                DataMessage(message: error)
              else if (controller.loading)
                const Center(child: CircularProgressIndicator())
              else
                _playlistGrid(playlists.length + 1, (index, width) {
                  if (index == playlists.length) {
                    return _PlaylistCreateCard(
                      width: width,
                      onTap: () => createLocalPlaylist(context, controller),
                    );
                  }
                  final playlist = playlists[index];
                  final readyTracks = controller.tracks
                      .where(
                        (track) =>
                            playlist.trackIds.contains(track.id) &&
                            track.isReady,
                      )
                      .toList();
                  return _PlaylistCard(
                    name: playlist.name,
                    count: playlist.trackIds.length,
                    offline: true,
                    width: width,
                    artwork: PlaylistArtwork(
                      tracks: controller.tracks
                          .where(
                            (track) => playlist.trackIds.contains(track.id),
                          )
                          .toList(),
                      size: width - 22,
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
                    onPlay: readyTracks.isEmpty
                        ? null
                        : () => controller.play(
                            readyTracks.first,
                            queueIds: readyTracks.map((t) => t.id).toList(),
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
      runSpacing: 14,
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
    this.offline = true,
    this.onPlay,
  });
  final String name;
  final int count;
  final double width;
  final Widget artwork;
  final VoidCallback onTap;
  final bool offline;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: LiquidGlassCard(
      borderRadius: 16,
      padding: const EdgeInsets.all(11),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              artwork,
              if (onPlay != null && count > 0)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: GestureDetector(
                    onTap: onPlay,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0x45ffffff),
                        border: Border.all(color: const Color(0x66ffffff)),
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            '$count bài hát · ${offline ? "Trên thiết bị" : "Tài khoản"}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, color: Color(0xff8c839a)),
          ),
        ],
      ),
    ),
  );
}

/// Thẻ tạo Playlist mới (.playlist-create trong App.tsx)
class _PlaylistCreateCard extends StatelessWidget {
  const _PlaylistCreateCard({required this.width, required this.onTap});
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: width + 48,
    child: Material(
      color: const Color(0x06a591c3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0x36ba9be2)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0x18a591c3),
                    border: Border.all(color: const Color(0x2ec1a5e2)),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    size: 24,
                    color: Color(0xffac96c5),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Tạo một cảm xúc mới',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xffb9aacb),
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Playlist của bạn bắt đầu từ đây',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: Color(0xff6d637b)),
                ),
              ],
            ),
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
        backgroundColor: const Color(0xff1b1d2b),
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
        backgroundColor: const Color(0xff1b1d2b),
        title: const Text('Chọn bài đã tải'),
        children: [
          for (final item in tracks)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, item),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: TrackArtwork(path: item.artworkPath, size: 42),
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
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
          children: [
            if (controller.error case final error?) DataMessage(message: error),
            if (playlist == null)
              const DataMessage(message: 'Playlist không còn tồn tại.')
            else ...[
              Container(
                padding: const EdgeInsets.only(bottom: 24),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0x14ffffff))),
                ),
                child: Column(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(19),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x389e7db0),
                            blurRadius: 45,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: PlaylistArtwork(tracks: tracks, size: 180),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'OFFLINE PLAYLIST',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.8,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff8f84a9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      playlist.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${tracks.length} bài hát · ${formatTime(tracks.fold<int>(0, (total, track) => total + track.durationMs))}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xffb6a5c4),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: playButtonStyle(context),
                            onPressed: tracks.isEmpty
                                ? null
                                : () => controller.play(
                                    tracks.first,
                                    queueIds: queue,
                                  ),
                            icon: const Icon(Icons.play_arrow_rounded, size: 18),
                            label: const Text('Phát'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: const BorderSide(color: Color(0x38c2b4dd)),
                            ),
                            onPressed: tracks.isEmpty
                                ? null
                                : () {
                                    final shuffled = List<OfflineTrack>.from(
                                      tracks,
                                    )..shuffle();
                                    controller.play(
                                      shuffled.first,
                                      queueIds: shuffled
                                          .map((t) => t.id)
                                          .toList(),
                                    );
                                  },
                            icon: const Icon(Icons.shuffle_rounded, size: 17),
                            label: const Text('Trộn bài'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              shape: const StadiumBorder(),
                              side: const BorderSide(color: Color(0x38c2b4dd)),
                            ),
                            onPressed: available.isEmpty
                                ? null
                                : () => _add(context, available),
                            icon: const Icon(Icons.add_rounded, size: 17),
                            label: const Text('Thêm bài'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (tracks.isEmpty)
                DataMessage(
                  message: available.isEmpty
                      ? 'Hãy tải bài về thư viện trước.'
                      : 'Chọn bài đã tải để thêm vào playlist.',
                ),
              for (final track in tracks)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: controller.playback.trackId == track.id
                        ? const Color(0x24a38cc5)
                        : const Color(0x88191d28),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(
                        color: controller.playback.trackId == track.id
                            ? const Color(0x40c2a6de)
                            : const Color(0x12ffffff),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      leading: TrackArtwork(path: track.artworkPath, size: 46),
                      title: Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        track.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xff8e849e),
                        ),
                      ),
                      selected: controller.playback.trackId == track.id,
                      onTap: () => controller.play(track, queueIds: queue),
                      trailing: TrackMenu(
                        title: track.title,
                        artist: track.artist,
                        artworkUrl: track.artworkUrl,
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
                              promptAddToPlaylist(
                                context,
                                controller,
                                song: item,
                                rawTrackId: track.id,
                              );
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
      borderRadius: BorderRadius.circular(14),
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