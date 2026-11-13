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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xff3a2b55), Color(0xff252136)],
        ),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: const Color(0xffd5c8fc),
        size: size * .44,
      ),
    );
    final uri = Uri.tryParse(url ?? '');
    final hasArtworkUrl =
        uri != null &&
        uri.scheme == 'https' &&
        uri.userInfo.isEmpty &&
        (!uri.hasPort || uri.port == 443) &&
        (uri.host == 'i.ytimg.com' || uri.host.endsWith('.sndcdn.com'));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size > 80 ? 18 : 10),
        border: Border.all(color: const Color(0x22ffffff)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size > 80 ? 17 : 9),
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
  Widget build(BuildContext context) => LiquidGlassCard(
    borderRadius: 18,
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrackArtwork(url: track.artworkUrl, size: 58),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.provider == 'youtube' ? 'YOUTUBE' : 'SOUNDCLOUD',
                    style: const TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xffc2abf3),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    track.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (track.artist.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.palette.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng thông tin bài',
              onPressed: busy ? null : onClose,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Thời lượng ${formatTime(track.durationMs)}',
          style: TextStyle(fontSize: 11.5, color: context.palette.muted),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: playButtonStyle(context),
          onPressed: busy ? null : onDownload,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded, size: 18),
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
  Widget build(BuildContext context) => LiquidGlassCard(
    borderRadius: 18,
    padding: const EdgeInsets.all(16),
    gradient: const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      colors: [Color(0x409c5633), Color(0xaa1a1c29)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TrackArtwork(url: playlist.artworkUrl, size: 58),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SOUNDCLOUD PLAYLIST',
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xffdca27d),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    playlist.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  if (playlist.uploader.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      playlist.uploader,
                      style: TextStyle(
                        color: context.palette.muted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Đóng thông tin playlist',
              onPressed: busy ? null : onClose,
              icon: const Icon(Icons.close_rounded, size: 20),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Danh sách gồm ${playlist.tracks.length} bài hát',
          style: TextStyle(fontSize: 11.5, color: context.palette.muted),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: playButtonStyle(context),
          onPressed: busy ? null : onDownload,
          icon: busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(
            busy ? 'Đang thêm vào hàng tải…' : 'Tải vào Playlist offline',
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
    padding: const EdgeInsets.only(bottom: 6),
    child: Material(
      color: selected ? const Color(0x24a38cc5) : const Color(0x88191d28),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? const Color(0x40c2a6de) : const Color(0x12ffffff),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: track.isReady ? onPlay : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      TrackArtwork(
                        path: track.artworkPath,
                        url: track.artworkUrl,
                        size: 46,
                      ),
                      if (selected)
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Center(
                            child: EqualizerBars(active: true, size: 16),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? const Color(0xffc9b6f0)
                                : context.palette.text,
                          ),
                        ),
                        if (track.artist.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: context.palette.muted,
                            ),
                          ),
                        ],
                        const SizedBox(height: 5),
                        // .download-label trong App.tsx
                        Row(
                          children: [
                            Icon(
                              track.isReady
                                  ? Icons.check_rounded
                                  : (track.provider == 'youtube'
                                        ? Icons.smart_display_rounded
                                        : Icons.cloud_outlined),
                              size: 12,
                              color: track.status == 'failed'
                                  ? Theme.of(context).colorScheme.error
                                  : const Color(0xffb8a1cb),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _status,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: track.status == 'failed'
                                      ? Theme.of(context).colorScheme.error
                                      : const Color(0xffb8a1cb),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else if (track.isReady)
                    IconButton(
                      tooltip: 'Phát ${track.title}',
                      onPressed: onPlay,
                      icon: Icon(
                        selected
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_arrow_rounded,
                        color: selected
                            ? const Color(0xffc9b6f0)
                            : context.palette.text,
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
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: Color(0xff8e849e),
                    ),
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
              if (track.status == 'downloading') ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: track.progress,
                    minHeight: 3,
                    backgroundColor: const Color(0x18ffffff),
                    color: const Color(0xffc2abf3),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}