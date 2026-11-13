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
import 'track_actions.dart';
import 'track_widgets.dart';

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
    final queue = controller.sourceQueueItems;
    final queueIdx = controller.sourceQueueIndex;
    final sourceItem =
        queueIdx != null && queueIdx < queue.length ? queue[queueIdx] : null;
    final fraction = playback.durationMs > 0
        ? (playback.positionMs / playback.durationMs).clamp(0.02, 1.0)
        : 0.05;

    return LiquidGlassCard(
      borderRadius: 17,
      blur: 28,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xc9353043),
          Color(0xe6252333),
          Color(0xdc2b2639),
        ],
      ),
      borderColor: const Color(0x36c2b4dd),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Thanh tiến trình 3 màu (.mobile-progress trong index.css)
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fraction,
              child: Container(
                height: 2.2,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xff8bc5d5),
                      Color(0xffc3a2f2),
                      Color(0xffe0b6d2),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
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
                    child: Row(
                      children: [
                        TrackArtwork(
                          path: track?.artworkPath,
                          url: playback.offline
                              ? null
                              : (track?.artworkUrl ?? sourceItem?.artworkUrl),
                          size: 42,
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                track?.title ??
                                    sourceItem?.title ??
                                    'Đang phát',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                playback.error ??
                                    '${playback.offline ? "Đã tải" : "Trực tuyến"} · ${formatTime(playback.positionMs)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: playback.error == null
                                      ? const Color(0xffa396b2)
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
                IconButton(
                  tooltip: playback.isPlaying ? 'Tạm dừng' : 'Phát nhạc',
                  onPressed: controller.togglePlay,
                  icon: Icon(
                    playback.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 26,
                    color: const Color(0xfff7edf9),
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
                    color: Color(0xffb9a8cb),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
  // 0: Đang phát, 1: Danh sách chờ, 2: Lời bài hát (chuẩn Trio Tabs trong App.tsx)
  int _panel = 0;
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

  void _syncLyrics(
    String? trackId,
    String title,
    String artist,
    int durationMs,
  ) {
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
          sigmaX: 70,
          sigmaY: 70,
          tileMode: TileMode.mirror,
        ),
        child: Transform.scale(
          scale: 1.25,
          child: Opacity(opacity: 0.65, child: image),
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
      final currentTrackId =
          track?.id ??
          (sourceItem != null ? 'source_${sourceItem.url.hashCode}' : null);
      _syncLyrics(currentTrackId, title, artist, player.durationMs);

      const tabTitles = ['Đang phát', 'Tiếp theo', 'Lời bài hát'];

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        child: Theme(
          data: bcmusicTheme(),
          child: Scaffold(
            backgroundColor: const Color(0xff14111e),
            body: Stack(
              children: [
                Positioned.fill(
                  child: ClipRect(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 600),
                      child: KeyedSubtree(
                        key: ValueKey(
                          track?.artworkPath ?? artworkUrl ?? 'empty',
                        ),
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
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x990d0f1a),
                          Color(0xe80d0f1a),
                          Color(0xf5101019),
                        ],
                      ),
                    ),
                  ),
                ),
                SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 32,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // .full-player-header trong App.tsx
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Thu nhỏ trình phát',
                                  onPressed: () => Navigator.pop(context),
                                  icon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    size: 28,
                                    color: Color(0xffe0d4ee),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      const Text(
                                        'ÂM NHẠC CHO RIÊNG BẠN',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          letterSpacing: 1.8,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xffbbb0cc),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        tabTitles[_panel],
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
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
                                    Icons.more_horiz_rounded,
                                    size: 24,
                                    color: Color(0xffe0d4ee),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 18),

                            // .player-view-tabs (Trio Quick Switcher)
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0x0fffffff),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: const Color(0x18ffffff),
                                ),
                              ),
                              child: Row(
                                children: [
                                  for (final (idx, label) in tabTitles.indexed)
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () =>
                                            setState(() => _panel = idx),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 220,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              30,
                                            ),
                                            color: _panel == idx
                                                ? const Color(0x22ffffff)
                                                : Colors.transparent,
                                          ),
                                          child: Text(
                                            label,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: _panel == idx
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: _panel == idx
                                                  ? const Color(0xfff5edf9)
                                                  : const Color(0xffaba1bb),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 22),

                            // 3 Chế độ hiển thị của Trio Player
                            if (_panel == 0)
                              _buildNowPlayingMainView(
                                context,
                                constraints,
                                controller,
                                player,
                                track,
                                title,
                                artist,
                                artworkUrl,
                                position,
                                duration,
                                volume,
                                preferences,
                              )
                            else if (_panel == 1)
                              _buildNextQueuePanel(
                                context,
                                controller,
                                player,
                                track,
                                title,
                                artist,
                                artworkUrl,
                              )
                            else
                              _buildLyricsPanel(
                                context,
                                constraints,
                                controller,
                                player,
                                track,
                                title,
                                artist,
                                artworkUrl,
                              ),

                            if (controller.openingSource)
                              const Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: LinearProgressIndicator(
                                  semanticsLabel: 'Đang chuẩn bị phát',
                                ),
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

  Widget _buildNowPlayingMainView(
    BuildContext context,
    BoxConstraints constraints,
    MusicController controller,
    PlaybackState player,
    OfflineTrack? track,
    String title,
    String artist,
    String? artworkUrl,
    double position,
    double duration,
    double volume,
    AppPreferences preferences,
  ) {
    final coverSize = math.min(
      310.0,
      math.min(constraints.maxWidth * 0.82, constraints.maxHeight * 0.38),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0x38ffffff)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40a796e7),
                  blurRadius: 55,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(21),
              child: TrackArtwork(
                path: track?.artworkPath,
                url: artworkUrl,
                size: coverSize,
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),

        // .full-song-meta
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    artist.isEmpty
                        ? (player.offline ? 'Đã tải về thiết bị' : 'BCMusic')
                        : artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xffb0a0be),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: controller.isLiked(track) ? 'Bỏ thích' : 'Yêu thích',
              isSelected: controller.isLiked(track),
              onPressed: track == null || controller.savingFavorite
                  ? null
                  : () async {
                      if (!await controller.toggleLiked(track) &&
                          context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
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
                color: Color(0xffb0a0be),
              ),
              selectedIcon: const Icon(
                Icons.favorite_rounded,
                color: Color(0xffc2abf3),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // .timeline.large
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5.5),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: const Color(0xffd4b7ed),
            inactiveTrackColor: const Color(0x26ffffff),
            thumbColor: const Color(0xffddd2ef),
          ),
          child: Slider(
            value: position,
            max: duration,
            semanticFormatterCallback: (value) => formatTime(value.toInt()),
            onChanged: player.durationMs > 0
                ? (value) => setState(() => _drag = value)
                : null,
            onChangeEnd: (value) {
              controller.seek(value.toInt());
              setState(() => _drag = null);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                formatTime(position.toInt()),
                style: const TextStyle(color: Color(0xff9e8fb0), fontSize: 12),
              ),
              Text(
                player.offline ? 'OFFLINE READY' : 'HIGH QUALITY',
                style: const TextStyle(
                  color: Color(0xff8e819f),
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '-${formatTime((player.durationMs - position.toInt()).clamp(0, player.durationMs))}',
                style: const TextStyle(color: Color(0xff9e8fb0), fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // .full-controls (Previous, -10s, Glass Play 69px, +10s, Next)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: 'Bài trước',
              onPressed: controller.canSkip(-1)
                  ? () => controller.skip(-1)
                  : null,
              icon: const Icon(Icons.skip_previous_rounded, size: 30),
            ),
            IconButton(
              tooltip: 'Lùi 10 giây',
              onPressed: player.durationMs > 0
                  ? () => controller.seek(
                      math.max(0, player.positionMs - 10000),
                    )
                  : null,
              icon: const Icon(
                Icons.replay_10_rounded,
                size: 28,
                color: Color(0xffb9a9c8),
              ),
            ),
            Tooltip(
              message: player.isPlaying ? 'Tạm dừng' : 'Phát tiếp',
              child: GestureDetector(
                onTap: controller.togglePlay,
                child: Container(
                  width: 69,
                  height: 69,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0x55ffffff), Color(0x38d5b7fb)],
                    ),
                    border: Border.all(color: const Color(0x66ffffff)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    player.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Tiến 10 giây',
              onPressed: player.durationMs > 0
                  ? () => controller.seek(
                      math.min(player.durationMs, player.positionMs + 10000),
                    )
                  : null,
              icon: const Icon(
                Icons.forward_10_rounded,
                size: 28,
                color: Color(0xffb9a9c8),
              ),
            ),
            IconButton(
              tooltip: 'Bài tiếp',
              onPressed: controller.canSkip(1)
                  ? () => controller.skip(1)
                  : null,
              icon: const Icon(Icons.skip_next_rounded, size: 30),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // .secondary-controls (Shuffle, Repeat, Lyrics, Queue, Sleep Timer)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: controller.shuffle ? 'Tắt trộn bài' : 'Bật trộn bài',
              onPressed: controller.toggleShuffle,
              icon: Icon(
                Icons.shuffle_rounded,
                size: 21,
                color: controller.shuffle
                    ? const Color(0xffeee0ff)
                    : const Color(0xffa596b5),
              ),
            ),
            IconButton(
              tooltip: switch (controller.repeatMode) {
                'one' => 'Lặp lại: 1 bài',
                'all' => 'Lặp lại: Tất cả',
                _ => 'Lặp lại: Tắt',
              },
              onPressed: controller.cycleRepeatMode,
              icon: Icon(
                controller.repeatMode == 'one'
                    ? Icons.repeat_one_rounded
                    : Icons.repeat_rounded,
                size: 21,
                color: controller.repeatMode != 'off'
                    ? const Color(0xffeee0ff)
                    : const Color(0xffa596b5),
              ),
            ),
            IconButton(
              tooltip: 'Lời bài hát',
              onPressed: () => setState(() => _panel = 2),
              icon: const Icon(
                Icons.lyrics_outlined,
                size: 21,
                color: Color(0xffa596b5),
              ),
            ),
            IconButton(
              tooltip: 'Danh sách chờ',
              onPressed: () => setState(() => _panel = 1),
              icon: const Icon(
                Icons.queue_music_rounded,
                size: 22,
                color: Color(0xffa596b5),
              ),
            ),
            IconButton(
              tooltip: 'Hẹn giờ ngủ',
              onPressed: () => _showSleepTimer(context, controller),
              icon: Icon(
                controller.sleepTimerActive
                    ? Icons.timer_rounded
                    : Icons.timer_outlined,
                size: 21,
                color: controller.sleepTimerActive
                    ? const Color(0xffeee0ff)
                    : const Color(0xffa596b5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Thanh tốc độ phát & âm lượng
        Row(
          children: [
            PopupMenuButton<double>(
              tooltip: 'Tốc độ phát',
              initialValue: preferences.speed,
              onSelected: (speed) =>
                  controller.updatePreferences({'speed': speed}),
              itemBuilder: (_) => [
                for (final speed in AppPreferences.speeds)
                  PopupMenuItem(
                    value: speed,
                    child: Text(playbackSpeedLabel(speed)),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: const Color(0x1affffff),
                  border: Border.all(color: const Color(0x1fffffff)),
                ),
                child: Text(
                  playbackSpeedLabel(preferences.speed),
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.volume_down_rounded,
              size: 20,
              color: Color(0xffa596b5),
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 3,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 5,
                  ),
                  activeTrackColor: const Color(0xffb7a8d4),
                  inactiveTrackColor: const Color(0x22ffffff),
                  thumbColor: const Color(0xffddd2ef),
                ),
                child: Slider(
                  value: volume,
                  max: 100,
                  semanticFormatterCallback: (value) =>
                      'Âm lượng ${value.round()} phần trăm',
                  onChanged: (value) => setState(() => _volume = value),
                  onChangeEnd: (value) async {
                    await controller.updatePreferences({
                      'volume': value.round(),
                    });
                    if (mounted) setState(() => _volume = null);
                  },
                ),
              ),
            ),
            const Icon(
              Icons.volume_up_rounded,
              size: 20,
              color: Color(0xffa596b5),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headphones_rounded, size: 14, color: Color(0xff8e7da0)),
            SizedBox(width: 6),
            Text(
              'Đang phát trên thiết bị này',
              style: TextStyle(fontSize: 11, color: Color(0xff8e7da0)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNextQueuePanel(
    BuildContext context,
    MusicController controller,
    PlaybackState player,
    OfflineTrack? track,
    String title,
    String artist,
    String? artworkUrl,
  ) {
    final allItems = controller.currentQueueItems;
    final currentIdx = controller.currentQueueIndex ?? -1;
    final upcomingItems = (currentIdx >= 0 && currentIdx < allItems.length)
        ? allItems.skip(currentIdx + 1).toList()
        : allItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // .current-queue-track.glass trong App.tsx
        LiquidGlassCard(
          borderRadius: 16,
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              TrackArtwork(
                path: track?.artworkPath,
                url: artworkUrl,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ĐANG PHÁT',
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w700,
                        color: Color(0xffb29bc9),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      artist.isEmpty ? 'BCMusic' : artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xff9e8fb0),
                      ),
                    ),
                  ],
                ),
              ),
              EqualizerBars(active: player.isPlaying),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Text(
              'Tiếp theo · ${upcomingItems.length}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showQueue(context),
              icon: const Icon(Icons.playlist_play_rounded, size: 17),
              label: const Text('Xem tất cả', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (upcomingItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const Icon(
                  Icons.queue_music_rounded,
                  size: 44,
                  color: Color(0xffa68abd),
                ),
                const SizedBox(height: 12),
                Text(
                  allItems.isNotEmpty
                      ? 'Đã đến cuối hàng đợi.'
                      : 'Khoảng lặng cho riêng bạn',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xffc5b6d3),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  controller.repeatMode == 'all' && allItems.isNotEmpty
                      ? 'Hàng đợi sẽ tự động lặp lại từ đầu.'
                      : 'Thêm những bài bạn yêu vào danh sách chờ.',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xff84788f),
                  ),
                ),
              ],
            ),
          )
        else
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
              return Padding(
                key: ValueKey('queue_${item.url}_$index'),
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: const Color(0x0affffff),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0x14ffffff)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(8, 2, 4, 2),
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReorderableDragStartListener(
                        index: index,
                        child: const Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Icon(
                            Icons.drag_indicator_rounded,
                            size: 19,
                            color: Color(0xff8a7699),
                          ),
                        ),
                      ),
                      TrackArtwork(url: item.artworkUrl, size: 42),
                    ],
                  ),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    item.artist.isEmpty ? 'BCMusic' : item.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xff9e8fb0),
                    ),
                  ),
                  trailing: IconButton(
                    tooltip: 'Xóa khỏi hàng đợi',
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: Color(0xff9e8fb0),
                    ),
                    onPressed: () =>
                        controller.removeQueueItem(actualQueueIndex),
                  ),
                  onTap: () => controller.skipToQueueIndex(actualQueueIndex),
                ),
              ),
            );
            },
          ),
        const SizedBox(height: 12),
        const Text(
          'Kéo biểu tượng bên trái để sắp xếp thứ tự phát',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xff8a7699)),
        ),
      ],
    );
  }

  Widget _buildLyricsPanel(
    BuildContext context,
    BoxConstraints constraints,
    MusicController controller,
    PlaybackState player,
    OfflineTrack? track,
    String title,
    String artist,
    String? artworkUrl,
  ) {
    final panelHeight = math.max(
      260.0,
      math.min(440.0, constraints.maxHeight * 0.56),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // .lyrics-track header từ App.tsx
        Container(
          padding: const EdgeInsets.only(bottom: 16),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0x16ffffff))),
          ),
          child: Row(
            children: [
              TrackArtwork(
                path: track?.artworkPath,
                url: artworkUrl,
                size: 45,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      artist.isEmpty ? 'BCMusic' : artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xffa08eb3),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: controller.togglePlay,
                icon: Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                ),
              ),
            ],
          ),
        ),
        if (_loadingLyrics)
          const SizedBox(
            height: 200,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 12),
                  Text('Đang đồng bộ lời bài hát...'),
                ],
              ),
            ),
          )
        else if (_lyrics == null ||
            (!_lyrics!.hasLyrics && !_lyrics!.isInstrumental))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const Text(
                  'Chưa có lời bài hát cho bài này.',
                  style: TextStyle(color: Color(0xffa08eb3), fontSize: 14),
                ),
                const SizedBox(height: 10),
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
          )
        else if (_lyrics!.isInstrumental)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 42),
            child: Column(
              children: [
                Icon(
                  Icons.music_note_rounded,
                  size: 42,
                  color: Color(0xffc2abf3),
                ),
                SizedBox(height: 10),
                Text(
                  'Bản nhạc không lời (Instrumental)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          )
        else if (_lyrics!.isSynced)
          Builder(
            builder: (context) {
              final lyrics = _lyrics!;
              final activeIdx = activeLyricIndex(
                lyrics.lines,
                player.positionMs,
              );
              if (activeIdx != _lastActiveLyric) {
                _lastActiveLyric = activeIdx;
                if (activeIdx >= 0 &&
                    !_userScrollingLyrics &&
                    _lyricsScroll.hasClients) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_lyricsScroll.hasClients && !_userScrollingLyrics) {
                      final targetOffset = math.max(
                        0.0,
                        (activeIdx * 56.0) - 110.0,
                      );
                      _lyricsScroll.animateTo(
                        targetOffset,
                        duration: const Duration(milliseconds: 320),
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
                    _userScrollResumeTimer = Timer(
                      const Duration(seconds: 4),
                      () {
                        if (mounted) {
                          setState(() => _userScrollingLyrics = false);
                        }
                      },
                    );
                  }
                  return false;
                },
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: panelHeight),
                  child: ListView.builder(
                    controller: _lyricsScroll,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    itemCount: lyrics.lines.length,
                    itemBuilder: (context, index) {
                      final line = lyrics.lines[index];
                      final isCurrent = index == activeIdx;
                      return InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => controller.seek(line.timeMs),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 6,
                          ),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: TextStyle(
                              fontFamily: 'BeVietnamPro',
                              fontSize: isCurrent ? 22 : 18,
                              fontWeight: isCurrent
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: isCurrent
                                  ? const Color(0xfff4f5fa)
                                  : const Color(0x55bba2d1),
                              height: 1.4,
                              shadows: isCurrent
                                  ? const [
                                      Shadow(
                                        color: Color(0x45e4c3ff),
                                        blurRadius: 20,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Text(line.text.isEmpty ? '♪' : line.text),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
          )
        else
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: panelHeight),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: SelectableText(
                _lyrics!.plainLyrics,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.6,
                  color: Color(0xddffffff),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            EqualizerBars(active: player.isPlaying, size: 16),
            const SizedBox(width: 10),
            const Text(
              'Chạm vào lời để tua đến đoạn nhạc',
              style: TextStyle(fontSize: 11.5, color: Color(0xff9f87b3)),
            ),
          ],
        ),
      ],
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
          final active = controller.sleepTimerActive;
          final remaining = controller.sleepTimerRemaining;
          final atEnd = controller.sleepAtEndOfTrack;
          String statusText = 'Chọn thời gian, để giai điệu ru bạn vào giấc ngủ.';
          if (active) {
            if (atEnd) {
              statusText = 'Nhạc sẽ dừng sau khi hết bài đang phát.';
            } else if (remaining != null) {
              final min = remaining.inMinutes;
              final sec = remaining.inSeconds % 60;
              statusText =
                  'Nhạc sẽ dừng sau: ${min > 0 ? '$min phút ' : ''}$sec giây';
            }
          }
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ngủ ngon cùng âm nhạc',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 13,
                      color: active
                          ? const Color(0xffc2abf3)
                          : context.palette.muted,
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final minutes in [5, 15, 30, 45, 60])
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule_rounded),
                      title: Text('$minutes phút'),
                      trailing: !atEnd &&
                              controller.sleepTimerMinutes == minutes &&
                              active
                          ? const Icon(
                              Icons.check_rounded,
                              color: Color(0xffc2abf3),
                            )
                          : null,
                      onTap: () {
                        controller.setSleepTimer(minutes);
                        Navigator.pop(sheetContext);
                      },
                    ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.skip_next_rounded),
                    title: const Text('Khi hết bài hiện tại'),
                    trailing: atEnd && active
                        ? const Icon(
                            Icons.check_rounded,
                            color: Color(0xffc2abf3),
                          )
                        : null,
                    onTap: () {
                      controller.setSleepTimer(null, atEndOfTrack: true);
                      Navigator.pop(sheetContext);
                    },
                  ),
                  if (active)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.close_rounded),
                      title: const Text('Tắt hẹn giờ'),
                      onTap: () {
                        controller.cancelSleepTimer();
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Hàng đợi ($count bài)',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
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
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: count,
                    itemBuilder: (context, index) {
                      if (sourceQueue.isNotEmpty) {
                        final item = sourceQueue[index];
                        final selected = controller.sourceQueueIndex == index;
                        return ListTile(
                          selected: selected,
                          leading: TrackArtwork(url: item.artworkUrl, size: 46),
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
                              ? const EqualizerBars(active: true)
                              : null,
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            await controller.playSource(
                              item.url,
                              queue: sourceQueue.map((entry) => entry.url),
                              queueItems: sourceQueue,
                            );
                          },
                        );
                      }
                      final item = offlineQueue[index];
                      final selected = controller.playback.trackId == item.id;
                      return ListTile(
                        selected: selected,
                        leading: TrackArtwork(path: item.artworkPath, size: 46),
                        title: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(item.artist, maxLines: 1),
                        trailing: selected
                            ? const EqualizerBars(active: true)
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