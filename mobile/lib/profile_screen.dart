import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'models.dart';
import 'platform_bridge.dart';
import 'playlist_screen.dart';
import 'track_actions.dart';
import 'track_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});
  final MusicController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _name = TextEditingController();
  final _imageUrl = TextEditingController();
  String? _pickedImage, _error;
  bool _editing = false, _saving = false, _picking = false;
  late Future<Map<String, dynamic>> _collections;

  AndroidMusicPlatform? get _platform => switch (widget.controller.platform) {
    final AndroidMusicPlatform platform => platform,
    _ => null,
  };

  @override
  void initState() {
    super.initState();
    _collections = _loadCollections();
  }

  @override
  void dispose() {
    _name.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _loadCollections() async {
    final raw = await _platform?.getProfileCollections();
    return raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
  }

  void _edit(AccountProfile account) {
    _name.text = account.name;
    _imageUrl.clear();
    setState(() {
      _editing = true;
      _pickedImage = null;
      _error = null;
    });
  }

  Future<void> _chooseImage() async {
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final data = await _platform?.pickProfileImage();
      if (mounted && data != null) {
        _imageUrl.clear();
        setState(() => _pickedImage = data);
      }
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Chưa đọc được ảnh.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final input = _imageUrl.text.trim();
    final uri = Uri.tryParse(input);
    if (name.isEmpty || name.length > 50) {
      setState(() => _error = 'Tên hiển thị phải từ 1 đến 50 ký tự.');
      return;
    }
    if (input.isNotEmpty &&
        (uri == null ||
            uri.scheme != 'https' ||
            uri.host.isEmpty ||
            uri.userInfo.isNotEmpty)) {
      setState(() => _error = 'Nhập URL ảnh HTTPS hợp lệ.');
      return;
    }
    final platform = _platform;
    if (platform == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await platform.updateProfile(
        name,
        image: input.isNotEmpty ? input : _pickedImage,
      );
      if (mounted) setState(() => _editing = false);
    } on PlatformException catch (e) {
      if (mounted) setState(() => _error = e.message ?? 'Chưa lưu được hồ sơ.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<PlaybackQueueItem> _songs(Object? data) {
    if (data is! List) return [];
    return [for (final row in data.whereType<Map>()) ?_song(row)];
  }

  PlaybackQueueItem? _song(Map row) {
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

  Widget _songRow(
    PlaybackQueueItem song,
    List<PlaybackQueueItem> queue, {
    Widget? trailing,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: TrackArtwork(url: song.artworkUrl, size: 44),
    title: Text(song.title, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(song.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
    trailing: trailing,
    onTap: () => widget.controller.playSource(
      song.url,
      queue: queue.map((item) => item.url),
      queueItems: queue,
    ),
  );

  Future<void> _openWebPlaylist(Map playlist) async {
    final platform = _platform;
    final id = playlist['id'];
    if (platform == null || id is! String) return;
    final raw = playlist['songs'];
    final entries = <String, PlaybackQueueItem>{
      if (raw is List)
        for (final row in raw.whereType<Map>())
          if (row['id'] case final String songId) songId: ?_song(row),
    };
    final pending = <String>{};
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => StatefulBuilder(
          builder: (context, update) => Scaffold(
            appBar: AppBar(
              title: Text(playlist['name']?.toString() ?? 'Playlist'),
            ),
            body: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (entries.isEmpty) const Text('Chưa có bài có thể phát.'),
                for (final MapEntry(key: songId, value: song)
                    in entries.entries)
                  _songRow(
                    song,
                    entries.values.toList(),
                    trailing: TrackMenu(
                      title: song.title,
                      inPlaylist: true,
                      onSelected: (action) async {
                        final controller = widget.controller;
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
                              await platform.removeWebPlaylistSong(id, songId);
                              if (context.mounted) {
                                update(() => entries.remove(songId));
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
                              pending.remove(songId);
                            }
                        }
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (mounted) setState(() => _collections = _loadCollections());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final account = widget.controller.snapshot.account;
      final local = widget.controller.snapshot.playlists;
      return Scaffold(
        appBar: AppBar(title: const Text('Hồ sơ')),
        body: account == null
            ? const Center(child: Text('Bạn chưa đăng nhập.'))
            : SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: _editing && _pickedImage != null
                                  ? ClipOval(
                                      child: Image.memory(
                                        base64Decode(
                                          _pickedImage!.split(',').last,
                                        ),
                                        width: 88,
                                        height: 88,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : AccountAvatar(account: account, size: 88),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              account.name,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            if (account.username.isNotEmpty)
                              Text(
                                '@${account.username}',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: context.palette.muted),
                              ),
                            const SizedBox(height: 16),
                            if (_editing) ...[
                              if (!kIsWeb)
                                OutlinedButton.icon(
                                  onPressed: _saving || _picking
                                      ? null
                                      : _chooseImage,
                                  icon: const Icon(Icons.photo_outlined),
                                  label: const Text('Chọn ảnh đại diện'),
                                ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _name,
                                maxLength: 50,
                                enabled: !_saving,
                                decoration: const InputDecoration(
                                  labelText: 'Tên hiển thị',
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _imageUrl,
                                enabled: !_saving,
                                keyboardType: TextInputType.url,
                                decoration: const InputDecoration(
                                  labelText: 'URL ảnh đại diện (HTTPS)',
                                ),
                              ),
                              if (_error != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    _error!,
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                children: [
                                  FilledButton(
                                    onPressed: _saving || _picking
                                        ? null
                                        : _save,
                                    child: Text(_saving ? 'Đang lưu…' : 'Lưu'),
                                  ),
                                  TextButton(
                                    onPressed: _saving || _picking
                                        ? null
                                        : () =>
                                              setState(() => _editing = false),
                                    child: const Text('Hủy'),
                                  ),
                                ],
                              ),
                            ] else
                              OutlinedButton.icon(
                                onPressed: _platform == null
                                    ? null
                                    : () => _edit(account),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Chỉnh sửa hồ sơ'),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _collections,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return const LinearProgressIndicator(
                            semanticsLabel: 'Đang tải hồ sơ',
                          );
                        }
                        if (snapshot.hasError) {
                          final error = snapshot.error;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                error is PlatformException
                                    ? error.message ?? 'Chưa tải được hồ sơ.'
                                    : 'Chưa tải được hồ sơ.',
                              ),
                              TextButton(
                                onPressed: () => setState(
                                  () => _collections = _loadCollections(),
                                ),
                                child: const Text('Thử lại'),
                              ),
                            ],
                          );
                        }
                        final favorites = _songs(snapshot.data?['favorites']);
                        final lists = snapshot.data?['playlists'];
                        final playlists = lists is List
                            ? lists.whereType<Map>().toList()
                            : <Map>[];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Bài nhạc đã tim (${favorites.length})',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (favorites.isEmpty)
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Chưa có bài hát yêu thích.'),
                              ),
                            for (final song in favorites)
                              _songRow(song, favorites),
                            const SizedBox(height: 20),
                            Text(
                              'Playlist của bạn (${playlists.length})',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            if (playlists.isEmpty)
                              const ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text('Chưa có playlist trên web.'),
                              ),
                            for (final playlist in playlists)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.queue_music_rounded),
                                title: Text(
                                  playlist['name']?.toString() ?? 'Playlist',
                                ),
                                trailing: const Icon(
                                  Icons.chevron_right_rounded,
                                ),
                                onTap: () => _openWebPlaylist(playlist),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Playlist offline (${local.length})',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (local.isEmpty)
                      const ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Chưa có playlist trên thiết bị.'),
                      ),
                    for (final playlist in local)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.download_done_rounded),
                        title: Text(playlist.name),
                        subtitle: Text('${playlist.trackIds.length} bài'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.push<void>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaylistDetail(
                              controller: widget.controller,
                              playlistId: playlist.id,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Đóng'),
                    ),
                  ],
                ),
              ),
      );
    },
  );
}

class AccountAvatar extends StatelessWidget {
  const AccountAvatar({super.key, required this.account, this.size = 32});

  final AccountProfile account;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = account.name.trim();
    final fallback = CircleAvatar(
      radius: size / 2,
      backgroundColor: context.palette.raised,
      foregroundColor: context.palette.text,
      child: name.isEmpty
          ? const Icon(Icons.person_outline_rounded, size: 18)
          : Text(
              name.characters.first.toUpperCase(),
              maxLines: 1,
              style: TextStyle(fontSize: size * .42),
            ),
    );
    final uri = account.avatarUri;
    if (uri == null) return fallback;
    return ClipOval(
      child: Image.network(
        uri.toString(),
        width: size,
        height: size,
        cacheWidth: (size * 3).round(),
        fit: BoxFit.cover,
        excludeFromSemantics: true,
        frameBuilder: (_, child, frame, synchronous) =>
            frame != null || synchronous ? child : fallback,
        errorBuilder: (_, _, _) => fallback,
      ),
    );
  }
}
