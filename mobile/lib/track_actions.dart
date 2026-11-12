import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'models.dart';
import 'track_widgets.dart';

enum TrackAction { share, playlist, remove, queue, info }

class TrackMenu extends StatelessWidget {
  const TrackMenu({
    super.key,
    required this.title,
    required this.onSelected,
    this.onDownload,
    this.inPlaylist = false,
    this.artist,
    this.artworkUrl,
  });

  final String title;
  final ValueChanged<TrackAction> onSelected;
  final VoidCallback? onDownload;
  final bool inPlaylist;
  final String? artist;
  final String? artworkUrl;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Tùy chọn $title',
    icon: const Icon(Icons.more_vert_rounded),
    onPressed: () => showTrackMenuSheet(
      context,
      title: title,
      artist: artist,
      artworkUrl: artworkUrl,
      onSelected: onSelected,
      onDownload: onDownload,
      inPlaylist: inPlaylist,
    ),
  );
}

Future<void> showTrackMenuSheet(
  BuildContext context, {
  required String title,
  String? artist,
  String? artworkUrl,
  required ValueChanged<TrackAction> onSelected,
  VoidCallback? onDownload,
  bool inPlaylist = false,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (artist != null || artworkUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  TrackArtwork(url: artworkUrl, size: 52),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        if (artist != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .6),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.share_rounded),
            title: const Text('Chia sẻ'),
            onTap: () { Navigator.pop(context); onSelected(TrackAction.share); },
          ),
          if (onDownload case final download?)
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Tải xuống'),
              onTap: () { Navigator.pop(context); download(); },
            ),
          ListTile(
            leading: const Icon(Icons.playlist_add_rounded),
            title: const Text('Thêm vào danh sách phát'),
            onTap: () { Navigator.pop(context); onSelected(TrackAction.playlist); },
          ),
          if (inPlaylist)
            ListTile(
              leading: const Icon(Icons.playlist_remove_rounded),
              title: const Text('Xóa khỏi danh sách phát'),
              onTap: () { Navigator.pop(context); onSelected(TrackAction.remove); },
            ),
          ListTile(
            leading: const Icon(Icons.queue_music_rounded),
            title: const Text('Thêm vào danh sách chờ'),
            onTap: () { Navigator.pop(context); onSelected(TrackAction.queue); },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Thông tin bài hát'),
            onTap: () { Navigator.pop(context); onSelected(TrackAction.info); },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  ),
);

Future<void> shareSong(
  BuildContext context,
  MusicController controller,
  String url,
) async {
  if (!kIsWeb && await controller.shareTrack(url)) return;
  if (!context.mounted) return;
  try {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã sao chép liên kết bài hát.')),
      );
    }
  } on PlatformException {
    if (context.mounted) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Chia sẻ'),
          content: SelectableText(url),
        ),
      );
    }
  }
}

void enqueueSong(
  BuildContext context,
  MusicController controller,
  PlaybackQueueItem song,
) {
  final added = controller.enqueueSong(song);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        added
            ? 'Đã thêm vào danh sách chờ.'
            : 'Bài đã có trong danh sách hoặc trình phát đang bận.',
      ),
    ),
  );
}

Future<void> showTrackInfo(
  BuildContext context,
  PlaybackQueueItem song, {
  int durationMs = 0,
  String? artworkPath,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder: (context) => SafeArea(
    top: false,
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thông tin bài hát',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          TrackArtwork(path: artworkPath, url: song.artworkUrl, size: 64),
          const SizedBox(height: 12),
          Text(song.title, style: Theme.of(context).textTheme.titleMedium),
          Text(song.artist),
          if (durationMs > 0) Text('Thời lượng ${formatTime(durationMs)}'),
          if (Uri.tryParse(song.url)?.host case final host?)
            Text('Nguồn $host'),
          const SizedBox(height: 8),
          SelectableText(song.url),
        ],
      ),
    ),
  ),
);
