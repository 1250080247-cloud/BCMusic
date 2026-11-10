import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'lyrics.dart';
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
  LyricsRepository get _lyricsRepo => widget.controller.lyricsRepository;
  LyricsData? _lyrics;
  bool _loadingLyrics = false;
  String? _loadedLyricsTrackId;
  final ScrollController _lyricsScroll = ScrollController();
  int _lastActiveLyric = -1;
  bool _userScrollingLyrics = false;
  Timer? _userScrollResumeTimer;

  @override
  void initState() {
    super.initState();
    unawaited(widget.controller.refreshFavorites());
  }

  @override
  void dispose() {
    _lyricsScroll.dispose();
    _userScrollResumeTimer?.cancel();
    super.dispose();
  }

  void _syncLyrics(String? trackId, String title, String artist, int durationMs) {
    if (trackId == null || trackId.isEmpty) {
      if (_loadedLyricsTrackId != null) {
        setState(() {
          _loadedLyricsTrackId = null;
          _lyrics = null;
          _loadingLyrics = false;
        });
      }
      return;
    }
    if (_loadedLyricsTrackId == trackId) return;
    _loadedLyricsTrackId = trackId;
    _loadingLyrics = true;
    _lyrics = null;
    _lastActiveLyric = -1;
    _lyricsRepo
        .getLyrics(
          trackId: trackId,
          rawTitle: title,
          rawArtist: artist,
          durationMs: durationMs,
        )
        .then((data) {
          if (mounted && _loadedLyricsTrackId == trackId) {
            setState(() {
              _lyrics = data;
              _loadingLyrics = false;
            });
          }
        })
        .catchError((_) {
          if (mounted && _loadedLyricsTrackId == trackId) {
            setState(() {
              _lyrics = LyricsData.empty;
              _loadingLyrics = false;
            });
          }
        });
  }

  Widget _buildPlayerBackground(String? path, String? url) {
    Widget? image;
    if (!kIsWeb && path != null && path.isNotEmpty) {
      image = Image.file(
        File(path),
        fit: BoxFit.cover,
        alignment: Alignment.center,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      final hasArtworkUrl =
          uri != null &&
          uri.scheme == 'https' &&
          uri.userInfo.isEmpty &&
          (!uri.hasPort || uri.port == 443) &&
          (uri.host == 'i.ytimg.com' || uri.host.endsWith('.sndcdn.com'));
      if (hasArtworkUrl) {
        image = Image.network(
          uri.toString(),
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        );
      }
    }

    if (image == null) {
      return const SizedBox.expand();
    }

    return SizedBox.expand(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: 85,
          sigmaY: 85,
          tileMode: TileMode.mirror,
        ),
        child: Transform.scale(
          scale: 1.25,
          child: Opacity(
            opacity: 0.65,
            child: image,
          ),
        ),
      ),
    );
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
      final currentTrackId = track?.id ??
          (sourceItem != null ? 'source_${sourceItem.url.hashCode}' : null);
      _syncLyrics(currentTrackId, title, artist, player.durationMs);
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Theme(
          data: bcmusicTheme(),
          child: Scaffold(
            backgroundColor: const Color(0xff0a0b10),
            body: Stack(
              children: [
                Positioned.fill(
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: KeyedSubtree(
                        key: ValueKey(track?.artworkPath ?? artworkUrl ?? 'empty'),
                        child: _buildPlayerBackground(
                          track?.artworkPath,
                          artworkUrl,
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x6606080f),
                          Color(0x2e070910),
                          Color(0x8c06080f),
                        ],
                      ),
                    ),
                  ),
                ),
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0xb30a0b10),
                          Color(0x400a0b10),
                          Color(0xb30a0b10),
                          Color(0xf50a0b10),
                        ],
                        stops: [0.0, 0.32, 0.62, 1.0],
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
                                  tooltip: controller.sleepTimerActive
                                      ? (controller.sleepAtEndOfTrack
                                          ? 'Hẹn giờ tắt: khi hết bài'
                                          : 'Hẹn giờ tắt: còn ${controller.sleepTimerRemaining?.inMinutes ?? 0} phút')
                                      : 'Hẹn giờ tắt nhạc',
                                  onPressed: () => _showSleepTimer(context, controller),
                                  icon: Icon(
                                    controller.sleepTimerActive
                                        ? Icons.timer_rounded
                                        : Icons.timer_outlined,
                                    size: 24,
                                    color: controller.sleepTimerActive
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                IconButton(
                                  tooltip: controller.shuffle
                                      ? 'Tắt trộn bài'
                                      : 'Bật trộn bài',
                                  isSelected: controller.shuffle,
                                  onPressed: controller.toggleShuffle,
                                  icon: Icon(
                                    Icons.shuffle_rounded,
                                    size: 22,
                                    color: controller.shuffle
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Bài trước',
                                  onPressed: controller.canSkip(-1)
                                      ? () => controller.skip(-1)
                                      : null,
                                  icon: const Icon(
                                    Icons.skip_previous_rounded,
                                    size: 24,
                                  ),
                                ),
                                IconButton.filled(
                                  onPressed: controller.togglePlay,
                                  tooltip: player.isPlaying
                                      ? 'Tạm dừng'
                                      : 'Phát tiếp',
                                  iconSize: 32,
                                  style: IconButton.styleFrom(
                                    minimumSize: const Size.square(54),
                                  ),
                                  icon: Icon(
                                    player.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    size: 32,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Bài tiếp',
                                  onPressed: controller.canSkip(1)
                                      ? () => controller.skip(1)
                                      : null,
                                  icon: const Icon(
                                    Icons.skip_next_rounded,
                                    size: 24,
                                  ),
                                ),
                                IconButton(
                                  tooltip: switch (controller.repeatMode) {
                                    'one' => 'Lặp lại: 1 bài',
                                    'all' => 'Lặp lại: Tất cả',
                                    _ => 'Lặp lại: Tắt',
                                  },
                                  isSelected: controller.repeatMode != 'off',
                                  onPressed: controller.cycleRepeatMode,
                                  icon: Icon(
                                    controller.repeatMode == 'one'
                                        ? Icons.repeat_one_rounded
                                        : Icons.repeat_rounded,
                                    size: 22,
                                    color: controller.repeatMode != 'off'
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                PopupMenuButton<double>(
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
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(6),
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.35),
                                    ),
                                    child: Text(
                                      playbackSpeedLabel(preferences.speed),
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                              _buildLyricsPanel(
                                context,
                                constraints,
                                controller,
                                player,
                              )
                            else if (_panel == 1)
                              _buildNextQueuePanel(
                                context,
                                controller,
                                player,
                              )
                            else ...[
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

  Widget _buildNextQueuePanel(
    BuildContext context,
    MusicController controller,
    PlaybackState player,
  ) {
    final allItems = controller.currentQueueItems;
    final currentIdx = controller.currentQueueIndex ?? -1;
    final upcomingItems = (currentIdx >= 0 && currentIdx < allItems.length)
        ? allItems.skip(currentIdx + 1).toList()
        : allItems;

    if (upcomingItems.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.queue_music_rounded,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              allItems.isNotEmpty
                  ? 'Đã đến cuối hàng đợi.'
                  : 'Chưa có bài hát trong hàng đợi.',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (controller.repeatMode == 'all' && allItems.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Hàng đợi sẽ tự động lặp lại từ đầu.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => _showQueue(context),
              icon: const Icon(Icons.playlist_play_rounded, size: 18),
              label: const Text('Mở danh sách bài'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(
                'Tiếp theo (${upcomingItems.length} bài)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showQueue(context),
                icon: const Icon(Icons.playlist_play_rounded, size: 16),
                label: const Text('Xem tất cả', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: upcomingItems.length,
          // ignore: deprecated_member_use
          onReorder: (oldIdx, newIdx) {
            controller.reorderUpcomingQueue(oldIdx, newIdx);
          },
          itemBuilder: (context, index) {
            final item = upcomingItems[index];
            final actualQueueIndex =
                (currentIdx >= 0 ? currentIdx + 1 : 0) + index;
            return ListTile(
              key: ValueKey('queue_${item.url}_$index'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 2,
                vertical: 2,
              ),
              leading: TrackArtwork(
                url: item.artworkUrl,
                size: 42,
              ),
              title: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                item.artist.isEmpty ? 'BCMusic' : item.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Xóa khỏi hàng đợi',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () =>
                        controller.removeQueueItem(actualQueueIndex),
                  ),
                  ReorderableDragStartListener(
                    index: index,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(
                        Icons.drag_handle_rounded,
                        size: 20,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant
                            .withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () => controller.skipToQueueIndex(actualQueueIndex),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLyricsPanel(
    BuildContext context,
    BoxConstraints constraints,
    MusicController controller,
    PlaybackState player,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final panelHeight = math.max(
      200.0,
      math.min(360.0, constraints.maxHeight * 0.45),
    );

    if (_loadingLyrics) {
      return SizedBox(
        height: 180,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Đang tìm lời bài hát...',
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lyrics = _lyrics;
    if (lyrics == null || (!lyrics.hasLyrics && !lyrics.isInstrumental)) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chưa có lời bài hát cho bài này.',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  _loadedLyricsTrackId = null;
                  setState(() {});
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Thử tìm lại'),
              ),
            ],
          ),
        ),
      );
    }

    if (lyrics.isInstrumental) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.music_note_rounded,
                size: 42,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(
                'Bản nhạc không lời (Instrumental)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (lyrics.isSynced) {
      final activeIdx = activeLyricIndex(lyrics.lines, player.positionMs);
      if (activeIdx != _lastActiveLyric) {
        _lastActiveLyric = activeIdx;
        if (activeIdx >= 0 && !_userScrollingLyrics && _lyricsScroll.hasClients) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_lyricsScroll.hasClients && !_userScrollingLyrics) {
              final targetOffset = math.max(0.0, (activeIdx * 52.0) - 100.0);
              _lyricsScroll.animateTo(
                targetOffset,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              );
            }
          });
        }
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification &&
              notification.dragDetails != null) {
            _userScrollingLyrics = true;
            _userScrollResumeTimer?.cancel();
          } else if (notification is ScrollEndNotification) {
            _userScrollResumeTimer?.cancel();
            _userScrollResumeTimer = Timer(const Duration(seconds: 4), () {
              if (mounted) setState(() => _userScrollingLyrics = false);
            });
          }
          return false;
        },
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: panelHeight),
          child: ListView.builder(
            controller: _lyricsScroll,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: lyrics.lines.length,
            itemBuilder: (context, index) {
              final line = lyrics.lines[index];
              final isCurrent = index == activeIdx;
              return InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => controller.seek(line.timeMs),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  child: Text(
                    line.text.isEmpty ? '♪' : line.text,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isCurrent ? 18 : 15,
                      fontWeight:
                          isCurrent ? FontWeight.w800 : FontWeight.w500,
                      color: isCurrent
                          ? colorScheme.primary
                          : colorScheme.onSurface.withValues(alpha: 0.45),
                      height: 1.3,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: panelHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: SelectableText(
          lyrics.plainLyrics,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: colorScheme.onSurface.withValues(alpha: 0.85),
          ),
        ),
      ),
    );
  }

  void _showSleepTimer(BuildContext context, MusicController controller) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) => ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final theme = Theme.of(context);
          final colorScheme = theme.colorScheme;
          final active = controller.sleepTimerActive;
          final remaining = controller.sleepTimerRemaining;
          final atEnd = controller.sleepAtEndOfTrack;
          String statusText = 'Hẹn giờ tắt nhạc tự động';
          if (active) {
            if (atEnd) {
              statusText = 'Nhạc sẽ dừng sau khi hết bài đang phát';
            } else if (remaining != null) {
              final min = remaining.inMinutes;
              final sec = remaining.inSeconds % 60;
              statusText =
                  'Nhạc sẽ dừng sau: ${min > 0 ? '$min phút ' : ''}$sec giây';
            }
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        active ? Icons.timer_rounded : Icons.timer_outlined,
                        color: active
                            ? colorScheme.primary
                            : colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hẹn giờ tắt nhạc',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 13,
                                color: active
                                    ? colorScheme.primary
                                    : colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (active)
                        TextButton(
                          onPressed: () {
                            controller.cancelSleepTimer();
                          },
                          child: const Text('Tắt hẹn giờ'),
                        ),
                    ],
                  ),
                  const Divider(height: 24),
                  for (final minutes in [15, 30, 45, 60])
                    ListTile(
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text('$minutes phút'),
                      selected: !atEnd &&
                          controller.sleepTimerMinutes == minutes &&
                          active,
                      onTap: () {
                        controller.setSleepTimer(minutes);
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ListTile(
                    leading: const Icon(Icons.skip_next_rounded),
                    title: const Text('Khi hết bài hiện tại'),
                    selected: atEnd && active,
                    onTap: () {
                      controller.setSleepTimer(null, atEndOfTrack: true);
                      Navigator.pop(sheetContext);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

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
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Hẹn giờ tắt nhạc'),
              subtitle: widget.controller.sleepTimerActive
                  ? Text(widget.controller.sleepAtEndOfTrack
                      ? 'Đang hẹn: khi hết bài'
                      : 'Đang hẹn: còn ${widget.controller.sleepTimerRemaining?.inMinutes ?? 0} phút')
                  : null,
              onTap: () => Navigator.pop(sheetContext, _PlayerAction.timer),
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
      case _PlayerAction.timer:
        _showSleepTimer(context, widget.controller);
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

enum _PlayerAction { playlist, download, share, timer }
