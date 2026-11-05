import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'discovery_screen.dart';
import 'models.dart';
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

class PlaylistScreen extends StatelessWidget {
  const PlaylistScreen({super.key, required this.controller});
  final MusicController controller;

  @override
  Widget build(BuildContext context) {
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
                label: const Text('Tạo playlist'),
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth > 650 ? 3 : 2;
                  final width =
                      (constraints.maxWidth - 12 * (columns - 1)) / columns;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 16,
                    children: [
                      for (final playlist in playlists)
                        SizedBox(
                          width: width,
                          child: Material(
                            color: context.palette.surface,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _PlaylistDetail(
                                    controller: controller,
                                    playlistId: playlist.id,
                                  ),
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    PlaylistArtwork(
                                      tracks: controller.tracks
                                          .where(
                                            (track) => playlist.trackIds
                                                .contains(track.id),
                                          )
                                          .toList(),
                                      size: width - 24,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      playlist.name,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${playlist.trackIds.length} bài',
                                      style: TextStyle(
                                        color: context.palette.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaylistDetail extends StatelessWidget {
  const _PlaylistDetail({required this.controller, required this.playlistId});
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
                  trailing: IconButton(
                    tooltip: 'Gỡ ${track.title} khỏi playlist',
                    onPressed: () =>
                        controller.removeFromPlaylist(playlistId, track),
                    icon: const Icon(Icons.remove_circle_outline_rounded),
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
  const PlaylistArtwork({super.key, required this.tracks, required this.size});
  final List<OfflineTrack> tracks;
  final double size;
  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return TrackArtwork(size: size);
    if (tracks.length < 4) {
      return TrackArtwork(path: tracks.first.artworkPath, size: size);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox.square(
        dimension: size,
        child: Wrap(
          children: [
            for (final track in tracks.take(4))
              TrackArtwork(path: track.artworkPath, size: size / 2),
          ],
        ),
      ),
    );
  }
}
