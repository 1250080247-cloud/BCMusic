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
  });

  final String title;
  final ValueChanged<TrackAction> onSelected;
  final VoidCallback? onDownload;
  final bool inPlaylist;

  @override
  Widget build(BuildContext context) => PopupMenuButton<TrackAction>(
    tooltip: 'Tùy chọn $title',
    onSelected: onSelected,
    itemBuilder: (_) => [
      const PopupMenuItem(value: TrackAction.share, child: Text('Chia sẻ')),
      if (onDownload case final download?)
        PopupMenuItem(onTap: download, child: const Text('Tải xuống')),
      const PopupMenuItem(
        value: TrackAction.playlist,
        child: Text('Thêm vào danh sách phát'),
      ),
      if (inPlaylist)
        const PopupMenuItem(
          value: TrackAction.remove,
          child: Text('Xóa khỏi danh sách phát'),
        ),
      const PopupMenuItem(
        value: TrackAction.queue,
        child: Text('Thêm vào danh sách chờ'),
      ),
      const PopupMenuItem(
        value: TrackAction.info,
        child: Text('Thông tin bài hát'),
      ),
    ],
  );
}

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
