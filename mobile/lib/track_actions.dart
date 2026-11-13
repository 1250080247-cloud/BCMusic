import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'models.dart';
import 'track_widgets.dart';

enum TrackAction { share, playlist, queue, info, remove }

class TrackMenu extends StatelessWidget {
  const TrackMenu({
    super.key,
    required this.title,
    this.artist = '',
    this.artworkUrl,
    required this.onSelected,
    this.onDownload,
    this.inPlaylist = false,
  });

  final String title, artist;
  final String? artworkUrl;
  final ValueChanged<TrackAction> onSelected;
  final VoidCallback? onDownload;
  final bool inPlaylist;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Tùy chọn $title',
    icon: const Icon(Icons.more_horiz_rounded, color: Color(0xff8e849e)),
    onPressed: () => _showSheet(context),
  );

  Future<void> _showSheet(BuildContext context) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TrackArtwork(url: artworkUrl, size: 54),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (artist.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xffa093af),
                            ),
                          ),
                        ],
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
              _SheetActionTile(
                icon: Icons.ios_share_rounded,
                label: 'Chia sẻ',
                onTap: () => Navigator.pop(sheetContext, 'share'),
              ),
              if (onDownload != null)
                _SheetActionTile(
                  icon: Icons.download_rounded,
                  label: 'Tải xuống',
                  onTap: () => Navigator.pop(sheetContext, 'download'),
                ),
              _SheetActionTile(
                icon: Icons.playlist_add_rounded,
                label: 'Thêm vào playlist',
                onTap: () => Navigator.pop(sheetContext, 'playlist'),
              ),
              _SheetActionTile(
                icon: Icons.queue_music_rounded,
                label: 'Thêm vào danh sách chờ',
                onTap: () => Navigator.pop(sheetContext, 'queue'),
              ),
              _SheetActionTile(
                icon: Icons.info_outline_rounded,
                label: 'Thông tin bài hát',
                onTap: () => Navigator.pop(sheetContext, 'info'),
              ),
              if (inPlaylist)
                _SheetActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Xóa khỏi playlist',
                  onTap: () => Navigator.pop(sheetContext, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );

    if (result == null) return;
    switch (result) {
      case 'download':
        onDownload?.call();
      case 'share':
        onSelected(TrackAction.share);
      case 'playlist':
        onSelected(TrackAction.playlist);
      case 'queue':
        onSelected(TrackAction.queue);
      case 'info':
        onSelected(TrackAction.info);
      case 'remove':
        onSelected(TrackAction.remove);
    }
  }
}

class _SheetActionTile extends StatelessWidget {
  const _SheetActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xffa999bb)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Color(0xffc9bfd4),
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Color(0xff786b88),
          ),
        ],
      ),
    ),
  );
}

Future<void> shareSong(
  BuildContext context,
  MusicController controller,
  String url,
) async {
  final ok = await controller.shareTrack(url);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Chưa thể chia sẻ lúc này. Hãy thử lại.')),
    );
  }
}

void enqueueSong(
  BuildContext context,
  MusicController controller,
  PlaybackQueueItem item,
) {
  final added = controller.enqueueSong(item);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        added
            ? 'Đã thêm “${item.title}” vào danh sách chờ.'
            : 'Bài hát đã có trong danh sách chờ.',
      ),
    ),
  );
}

Future<void> showTrackInfo(
  BuildContext context,
  PlaybackQueueItem item, {
  int durationMs = 0,
  String? artworkPath,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TrackArtwork(path: artworkPath, url: item.artworkUrl, size: 58),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.artist.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.artist,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xffa093af),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (durationMs > 0)
            _InfoRow(label: 'Thời lượng', value: formatTime(durationMs)),
          _InfoRow(
            label: 'Nguồn âm thanh',
            value: item.url.contains('soundcloud') ? 'SoundCloud' : 'YouTube',
          ),
          _InfoRow(
            label: 'Trạng thái',
            value: artworkPath != null ? 'Tệp trên thiết bị' : 'Trực tuyến',
          ),
        ],
      ),
    ),
  ),
);

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xff8c7d9a)),
        ),
        const SizedBox(width: 16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xffcbb8da),
            ),
          ),
        ),
      ],
    ),
  );
}