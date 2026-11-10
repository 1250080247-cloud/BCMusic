import 'dart:io';

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models.dart';

class TrackArtwork extends StatelessWidget {
  const TrackArtwork({super.key, this.path, this.url, this.size = 56});
  final String? path, url;
  final double size;
  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: context.palette.selection,
      child: Icon(
        Icons.music_note_rounded,
        color: Theme.of(context).colorScheme.primary,
        size: size * .45,
      ),
    );
    final uri = Uri.tryParse(url ?? '');
    final hasArtworkUrl =
        uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        (!uri.hasPort || uri.port == 443) &&
        (uri.host == 'i.ytimg.com' || uri.host.endsWith('.sndcdn.com'));
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: path == null
          ? (hasArtworkUrl
                ? Image.network(
                    uri.toString(),
                    width: size,
                    height: size,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => placeholder,
                  )
                : placeholder)
          : Image.file(
              File(path!),
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
    );
  }
}

class PreviewCard extends StatelessWidget {
  const PreviewCard({
    super.key,
    required this.track,
    required this.busy,
    required this.onDownload,
    required this.onClose,
  });
  final OfflineTrack track;
  final bool busy;
  final VoidCallback onDownload, onClose;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrackArtwork(url: track.artworkUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.provider == 'youtube' ? 'YOUTUBE' : 'SOUNDCLOUD',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    track.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (track.artist.isNotEmpty)
                    Text(
                      track.artist,
                      style: TextStyle(color: context.palette.muted),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng thông tin bài',
              onPressed: busy ? null : onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Thời lượng ${formatTime(track.durationMs)}',
          style: TextStyle(fontSize: 12, color: context.palette.muted),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : onDownload,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded),
          label: Text(busy ? 'Đang thêm vào hàng tải…' : 'Tải để nghe offline'),
        ),
      ],
    ),
  );
}

class PlaylistPreviewCard extends StatelessWidget {
  const PlaylistPreviewCard({
    super.key,
    required this.playlist,
    required this.busy,
    required this.onDownload,
    required this.onClose,
  });

  final PlaylistPreview playlist;
  final bool busy;
  final VoidCallback onDownload, onClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: context.palette.surface,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrackArtwork(url: playlist.artworkUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SOUNDCLOUD PLAYLIST',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    playlist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (playlist.uploader.isNotEmpty)
                    Text(
                      playlist.uploader,
                      style: TextStyle(color: context.palette.muted),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng thông tin playlist',
              onPressed: busy ? null : onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Danh sách gồm ${playlist.tracks.length} bài hát',
          style: TextStyle(fontSize: 12, color: context.palette.muted),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : onDownload,
          icon: busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded),
          label: Text(
            busy
                ? 'Đang thêm vào hàng tải…'
                : 'Tải vào Playlist offline',
          ),
        ),
      ],
    ),
  );
}

class TrackTile extends StatelessWidget {
  const TrackTile({
    super.key,
    required this.track,
    required this.busy,
    required this.selected,
    required this.onPlay,
    required this.onRetry,
    required this.onRemove,
    this.onAddToPlaylist,
  });
  final OfflineTrack track;
  final bool busy, selected;
  final VoidCallback onPlay, onRetry, onRemove;
  final VoidCallback? onAddToPlaylist;
  String get _status => switch (track.status) {
    'completed' => '${formatTime(track.durationMs)} · Đã tải',
    'downloading' =>
      track.progress == null
          ? 'Đang tải…'
          : 'Đang tải ${(track.progress! * 100).toInt()}%',
    'queued' => 'Đang chờ mạng / lượt tải',
    'restarting' => 'Đang chuẩn bị tải lại…',
    'stopped' => 'Đã tạm dừng',
    'removing' => 'Đang xóa…',
    _ => track.error ?? 'Tải chưa hoàn tất. Có thể thử lại.',
  };
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Material(
      color: selected ? context.palette.selection : context.palette.surface,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 2, 14),
        child: Column(
          children: [
            Row(
              children: [
                TrackArtwork(path: track.artworkPath),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      if (track.artist.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          track.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.palette.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (track.isReady)
                  IconButton(
                    tooltip: 'Phát ${track.title}',
                    onPressed: onPlay,
                    icon: Icon(
                      selected
                          ? Icons.graphic_eq_rounded
                          : Icons.play_arrow_rounded,
                      color: context.palette.text,
                    ),
                  )
                else if (!track.isActive && track.status != 'removing')
                  IconButton(
                    tooltip: 'Thử tải lại ${track.title}',
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Tùy chọn ${track.title}',
                  enabled: !busy,
                  onSelected: (action) {
                    if (action == 'playlist') {
                      onAddToPlaylist?.call();
                    } else {
                      onRemove();
                    }
                  },
                  itemBuilder: (_) => [
                    if (onAddToPlaylist != null)
                      const PopupMenuItem(
                        value: 'playlist',
                        child: Text('Thêm vào playlist'),
                      ),
                    PopupMenuItem(
                      value: 'remove',
                      child: Text(
                        track.isReady ? 'Xóa bản tải' : 'Hủy / xóa bản tải',
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  track.provider == 'youtube'
                      ? Icons.smart_display_rounded
                      : Icons.cloud_rounded,
                  size: 13,
                  color: context.palette.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _status,
                    style: TextStyle(
                      fontSize: 12,
                      color: track.status == 'failed'
                          ? Theme.of(context).colorScheme.error
                          : context.palette.muted,
                    ),
                  ),
                ),
              ],
            ),
            if (track.status == 'downloading') ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: track.progress, minHeight: 3),
            ],
          ],
        ),
      ),
    ),
  );
}
