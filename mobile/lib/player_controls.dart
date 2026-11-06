import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'models.dart';
import 'track_widgets.dart';
import 'track_actions.dart';

class PlayerControls extends StatelessWidget {
  const PlayerControls({
    super.key,
    required this.controller,
    required this.onAddToPlaylist,
    required this.onDownload,
  });
  final MusicController controller;
  final ValueChanged<OfflineTrack> onAddToPlaylist;
  final ValueChanged<String> onDownload;

  @override
  Widget build(BuildContext context) {
    final playback = controller.playback;
    final track =
        playback.track ??
        controller.tracks
            .where((item) => item.id == playback.trackId)
            .firstOrNull;
    final fraction = playback.durationMs > 0
        ? (playback.positionMs / playback.durationMs).clamp(0.0, 1.0)
        : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Material(
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        color: context.palette.raised,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: fraction ?? 0, minHeight: 2),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        fullscreenDialog: true,
                        builder: (_) => _NowPlaying(
                          controller: controller,
                          onAddToPlaylist: onAddToPlaylist,
                          onDownload: onDownload,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                      child: Row(
                        children: [
                          TrackArtwork(
                            path: track?.artworkPath,
                            url: playback.offline ? null : track?.artworkUrl,
                            size: 40,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  track?.title ?? 'Đang phát',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  playback.error ??
                                      (playback.offline
                                          ? 'Đã tải · ${formatTime(playback.positionMs)}'
                                          : 'Trực tuyến · ${formatTime(playback.positionMs)}'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: playback.error == null
                                        ? context.palette.muted
                                        : Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                _PlayButton(
                  playing: playback.isPlaying,
                  onPressed: controller.togglePlay,
                ),
                IconButton(
                  tooltip: 'Bài tiếp',
                  onPressed: controller.canSkip(1)
                      ? () => controller.skip(1)
                      : null,
                  icon: const Icon(Icons.skip_next_rounded),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.playing, required this.onPressed});
  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton.filled(
    style: playButtonStyle(context)
        .copyWith(minimumSize: WidgetStatePropertyAll(Size.square(48))),
    tooltip: playing ? 'Tạm dừng' : 'Phát tiếp',
    onPressed: onPressed,
    icon: Icon(
      playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
      size: 24,
    ),
  );
}

class _NowPlaying extends StatefulWidget {
  const _NowPlaying({
    required this.controller,
    required this.onAddToPlaylist,
    required this.onDownload,
  });
  final MusicController controller;
  final ValueChanged<OfflineTrack> onAddToPlaylist;
  final ValueChanged<String> onDownload;
  @override
  State<_NowPlaying> createState() => _NowPlayingState();
}

class _NowPlayingState extends State<_NowPlaying> {
  double? _drag, _volume;
  int _panel = 1;
  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refreshFavorites());
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final player = controller.playback;
      final track =
          player.track ??
          controller.tracks
              .where((item) => item.id == player.trackId)
              .firstOrNull;
      final queue = controller.sourceQueueItems;
      final queueIndex = controller.sourceQueueIndex;
      final sourceItem = queueIndex != null && queueIndex < queue.length
          ? queue[queueIndex]
          : null;
      final duration = math.max(1.0, player.durationMs.toDouble());
      final position = (_drag ?? player.positionMs.toDouble()).clamp(
        0.0,
        duration,
      );
      final preferences = controller.snapshot.preferences;
      final volume = _volume ?? preferences.volume.toDouble();
      final title = track?.title ?? sourceItem?.title ?? 'Đang phát';
      final artist = track?.artist ?? sourceItem?.artist ?? '';
      final artworkUrl = player.offline
          ? track?.artworkUrl
          : track?.artworkUrl ?? sourceItem?.artworkUrl;
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Theme(
          data: bcmusicTheme(),
          child: Scaffold(
            backgroundColor: const Color(0xff151720),
            body: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x30000000),
                          Colors.transparent,
                          Color(0x98000000),
                          Color(0xe6000000),
                        ],
                        stops: [0, .38, .57, 1],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 14),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 18,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Thu nhỏ trình phát',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 30,
                                  ),
                                ),
                                const Expanded(
                                  child: Center(
                                    child: Text(
                                      'ĐANG PHÁT',
                                      style: TextStyle(
                                        fontSize: 12,
                                        letterSpacing: 2,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Tùy chọn bài hát',
                                  onPressed: () => _showActions(
                                    context,
                                    track,
                                    track?.sourceUrl ?? sourceItem?.url,
                                  ),
                                  icon: const Icon(
                                    Icons.more_vert_rounded,
                                    size: 27,
                                  ),
                                ),
                              ],
                            ),
                            Center(
                              child: TrackArtwork(
                                path: track?.artworkPath,
                                url: artworkUrl,
                                size: math.min(
                                  288,
                                  math.min(
                                    constraints.maxWidth * .66,
                                    constraints.maxHeight * .34,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 23,
                                          height: 1.2,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        artist.isEmpty
                                            ? (player.offline
                                                  ? 'Đã tải về thiết bị'
                                                  : 'BCMusic')
                                            : artist,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  tooltip: controller.isLiked(track)
                                      ? 'Bỏ thích'
                                      : 'Thích',
                                  isSelected: controller.isLiked(track),
                                  onPressed:
                                      track == null || controller.savingFavorite
                                      ? null
                                      : () async {
                                          if (!await controller.toggleLiked(
                                                track,
                                              ) &&
                                              context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Chưa cập nhật được bài yêu thích. Hãy thử lại.',
                                                    ),
                                                  ),
                                                );
                                          }
                                        },
                                  icon: const Icon(
                                    Icons.favorite_border_rounded,
                                  ),
                                  selectedIcon: const Icon(
                                    Icons.favorite_rounded,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Column(
                              children: [
                                SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(
                                      enabledThumbRadius: 6,
                                    ),
                                    overlayShape: const RoundSliderOverlayShape(
                                      overlayRadius: 16,
                                    ),
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white38,
                                    thumbColor: Colors.white,
                                  ),
                                  child: Slider(
                                    value: position,
                                    max: duration,
                                    semanticFormatterCallback: (value) =>
                                        formatTime(value.toInt()),
                                    onChanged: player.durationMs > 0
                                        ? (value) =>
                                              setState(() => _drag = value)
                                        : null,
                                    onChangeEnd: (value) {
                                      controller.seek(value.toInt());
                                      setState(() => _drag = null);
                                    },
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      formatTime(position.toInt()),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      player.offline ? 'OFFLINE' : 'ONLINE',
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 11,
                                        letterSpacing: 1.4,
                                      ),
                                    ),
                                    Text(
                                      '-${formatTime((player.durationMs - position.toInt()).clamp(0, player.durationMs))}',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: PopupMenuButton<double>(
                                    tooltip: 'Tốc độ phát',
                                    initialValue: preferences.speed,
                                    onSelected: (speed) => controller
                                        .updatePreferences({'speed': speed}),
                                    itemBuilder: (_) => [
                                      for (final speed in AppPreferences.speeds)
                                        PopupMenuItem(
                                          value: speed,
                                          child: Text(
                                            playbackSpeedLabel(speed),
                                          ),
                                        ),
                                    ],
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 3,
                                        ),
                                        child: Center(
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              playbackSpeedLabel(
                                                preferences.speed,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        tooltip: 'Bài trước',
                                        onPressed: controller.canSkip(-1)
                                            ? () => controller.skip(-1)
                                            : null,
                                        icon: const Icon(
                                          Icons.skip_previous_rounded,
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        onPressed: controller.togglePlay,
                                        tooltip: player.isPlaying
                                            ? 'Tạm dừng'
                                            : 'Phát tiếp',
                                        iconSize: 28,
                                        icon: Icon(
                                          player.isPlaying
                                              ? Icons.pause_rounded
                                              : Icons.play_arrow_rounded,
                                          size: 28,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      IconButton(
                                        tooltip: 'Bài tiếp',
                                        onPressed: controller.canSkip(1)
                                            ? () => controller.skip(1)
                                            : null,
                                        icon: const Icon(
                                          Icons.skip_next_rounded,
                                          size: 22,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    tooltip: controller.repeatOne
                                        ? 'Tắt lặp lại'
                                        : 'Lặp lại bài này',
                                    isSelected: controller.repeatOne,
                                    onPressed: controller.toggleRepeat,
                                    icon: const Icon(
                                      Icons.repeat_rounded,
                                      size: 20,
                                    ),
                                    selectedIcon: const Icon(
                                      Icons.repeat_one_rounded,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.volume_down_rounded, size: 22),
                                Expanded(
                                  child: Slider(
                                    value: volume,
                                    max: 100,

                                    semanticFormatterCallback: (value) =>
                                        'Âm lượng ${value.round()} phần trăm',
                                    onChanged: (value) =>
                                        setState(() => _volume = value),
                                    onChangeEnd: (value) async {
                                      await controller.updatePreferences({
                                        'volume': value.round(),
                                      });
                                      if (mounted) {
                                        setState(() => _volume = null);
                                      }
                                    },
                                  ),
                                ),
                                const Icon(Icons.volume_up_rounded, size: 22),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                for (final (index, label) in [
                                  'Lời bài hát',
                                  'Tiếp theo',
                                  'Thông tin',
                                ].indexed)
                                  Expanded(
                                    child: Semantics(
                                      selected: _panel == index,
                                      child: TextButton(
                                        onPressed: () =>
                                            setState(() => _panel = index),
                                        style: TextButton.styleFrom(
                                          foregroundColor: _panel == index
                                              ? Colors.white
                                              : Colors.white70,
                                          minimumSize: const Size(0, 48),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 8,
                                          ),
                                          shape: const RoundedRectangleBorder(),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              label,
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 5),
                                            Container(
                                              width: 30,
                                              height: 2,
                                              color: _panel == index
                                                  ? Colors.white
                                                  : Colors.transparent,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_panel == 0)
                              const Text('Chưa có lời bài hát cho bài này.')
                            else if (_panel == 1) ...[
                              for (final item in queue.skip(
                                (queueIndex ?? -1) + 1,
                              ))
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: TrackArtwork(
                                    url: item.artworkUrl,
                                    size: 42,
                                  ),
                                  title: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(item.artist),
                                  onTap: () => controller.playSource(
                                    item.url,
                                    queue: queue.map((entry) => entry.url),
                                    queueItems: queue,
                                  ),
                                ),
                              if (queue.isEmpty)
                                TextButton(
                                  onPressed: () => _showQueue(context),
                                  child: const Text('Mở danh sách bài'),
                                ),
                              if (queue.isNotEmpty &&
                                  queueIndex == queue.length - 1)
                                const Text('Đã đến cuối hàng đợi.'),
                            ] else ...[
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Nguồn'),
                                trailing: Text(
                                  track?.provider.toUpperCase() ?? 'YOUTUBE',
                                ),
                              ),
                              if (Uri.tryParse(
                                    track?.sourceUrl ?? sourceItem?.url ?? '',
                                  )?.queryParameters['v']
                                  case final videoId?)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Video ID'),
                                  trailing: SelectableText(videoId),
                                ),
                            ],
                            if (controller.openingSource)
                              const LinearProgressIndicator(
                                semanticsLabel: 'Đang chuẩn bị phát',
                              ),
                            if ((player.error ?? controller.error)
                                case final error?)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  error,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Future<void> _showActions(
    BuildContext context,
    OfflineTrack? track,
    String? url,
  ) async {
    final ready =
        widget.controller.tracks
            .where(
              (item) =>
                  item.isReady &&
                  (item.id == track?.id || item.sourceUrl == url),
            )
            .firstOrNull ??
        (track?.isReady == true ? track : null);
    final action = await showModalBottomSheet<_PlayerAction>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.playlist_add_rounded),
              title: const Text('Thêm vào playlist'),
              onTap: ready == null && url == null
                  ? null
                  : () => Navigator.pop(sheetContext, _PlayerAction.playlist),
            ),
            ListTile(
              leading: const Icon(Icons.download_rounded),
              title: const Text('Tải xuống'),
              subtitle: Text(
                ready == null
                    ? 'Lưu vào Thư viện BCMusic'
                    : 'Đã có trong Thư viện',
              ),
              onTap: ready != null || url == null
                  ? null
                  : () => Navigator.pop(sheetContext, _PlayerAction.download),
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Chia sẻ'),
              onTap: url == null
                  ? null
                  : () => Navigator.pop(sheetContext, _PlayerAction.share),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    switch (action) {
      case _PlayerAction.playlist:
        if (ready != null) {
          widget.onAddToPlaylist(ready);
          return;
        }
        final download = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Thêm vào playlist'),
            content: const Text(
              'Bạn cần tải bài xuống trước khi thêm vào playlist offline.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Để sau'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Tải xuống'),
              ),
            ],
          ),
        );
        if (!context.mounted || download != true || url == null) return;
        Navigator.pop(context);
        widget.onDownload(url);
      case _PlayerAction.download:
        if (url == null) return;
        Navigator.pop(context);
        widget.onDownload(url);
      case _PlayerAction.share:
        if (url != null) await shareSong(context, widget.controller, url);
    }
  }

  void _showQueue(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: .72,
        minChildSize: .48,
        maxChildSize: .94,
        expand: false,
        builder: (context, scrollController) {
          final controller = widget.controller;
          final sourceQueue = controller.sourceQueueItems;
          final offlineQueue = sourceQueue.isEmpty
              ? controller.tracks.where((item) => item.isReady).toList()
              : const <OfflineTrack>[];
          final count = sourceQueue.isNotEmpty
              ? sourceQueue.length
              : offlineQueue.length;
          return Material(
            color: context.palette.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.palette.muted.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Hàng đợi',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      Text(
                        '$count bài',
                        style: TextStyle(color: context.palette.muted),
                      ),
                      IconButton(
                        tooltip: 'Đóng hàng đợi',
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: count == 0
                      ? Center(
                          child: Text(
                            'Chưa có thông tin hàng đợi.',
                            style: TextStyle(color: context.palette.muted),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: count,
                          itemBuilder: (context, index) {
                            if (sourceQueue.isNotEmpty) {
                              final item = sourceQueue[index];
                              final selected =
                                  controller.sourceQueueIndex == index;
                              return ListTile(
                                selected: selected,
                                leading: TrackArtwork(
                                  url: item.artworkUrl,
                                  size: 48,
                                ),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  item.artist.isEmpty ? 'YouTube' : item.artist,
                                  maxLines: 1,
                                ),
                                trailing: selected
                                    ? const Icon(Icons.graphic_eq_rounded)
                                    : null,
                                onTap: () async {
                                  Navigator.pop(sheetContext);
                                  await controller.playSource(
                                    item.url,
                                    queue: sourceQueue.map(
                                      (entry) => entry.url,
                                    ),
                                    queueItems: sourceQueue,
                                  );
                                },
                              );
                            }
                            final item = offlineQueue[index];
                            final selected =
                                controller.playback.trackId == item.id;
                            return ListTile(
                              selected: selected,
                              leading: TrackArtwork(
                                path: item.artworkPath,
                                size: 48,
                              ),
                              title: Text(
                                item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(item.artist, maxLines: 1),
                              trailing: selected
                                  ? const Icon(Icons.graphic_eq_rounded)
                                  : null,
                              onTap: () async {
                                final ids = offlineQueue
                                    .map((entry) => entry.id)
                                    .toList();
                                Navigator.pop(sheetContext);
                                await controller.play(item, queueIds: ids);
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

enum _PlayerAction { playlist, download, share }
