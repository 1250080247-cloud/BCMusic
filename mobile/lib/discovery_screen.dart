import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'discovery.dart';
import 'models.dart';

typedef DiscoverySelection = void Function(
  DiscoverySong song,
  List<DiscoverySong> queue,
);

class DiscoveryScreen extends StatelessWidget {
  const DiscoveryScreen({
    super.key,
    required this.controller,
    required this.onSong,
    required this.onPlay,
    required this.onLibrary,
    required this.onMotion,
    this.playing = false,
    this.online = true,
    this.motion = true,
  });
  final DiscoveryController controller;
  final DiscoverySelection onSong, onPlay;
  final VoidCallback onLibrary;
  final ValueChanged<bool> onMotion;
  final bool playing, online, motion;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => controller.selectGenre(controller.genreIndex),
    child: CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          sliver: SliverList.list(
            children: [
              ListeningHero(
                playing: playing,
                motion: motion,
                onMotion: onMotion,
                onPlay: controller.sections.first.songs.isEmpty
                    ? null
                    : () => onPlay(
                        controller.sections.first.songs.first,
                        controller.sections.first.songs,
                      ),
              ),
              const SizedBox(height: 20),
              if (!online) ...[
                TextButton.icon(
                  onPressed: onLibrary,
                  icon: const Icon(Icons.offline_pin_rounded),
                  label: const Text('Đang offline · Mở các bài đã tải'),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: musicGenres.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) => ChoiceChip(
                    showCheckmark: false,
                    label: Text(musicGenres[index].label),
                    labelStyle: TextStyle(
                      color: controller.genreIndex == index
                          ? context.palette.onAction
                          : context.palette.muted,
                    ),
                    selected: controller.genreIndex == index,
                    onSelected: (_) => controller.selectGenre(index),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              for (var index = 0; index < 3; index++) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                [
                                  'Top Thịnh Hành',
                                  'Xem nhiều nhất',
                                  'Mới nhất',
                                ][index],
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: context.palette.border,
                                  ),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  musicGenres[controller.genreIndex].label,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.palette.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            [
                              'Những bản nhạc nổi bật dành cho bạn',
                              'Những giai điệu được nghe nhiều',
                              'Khám phá những bản nhạc mới',
                            ][index],
                            style: TextStyle(
                              fontSize: 12,
                              color: context.palette.muted,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (index == 0)
                  FeedCarousel(
                    section: controller.sections[index],
                    onSong: onSong,
                    onPlay: onPlay,
                    onRetry: () =>
                        controller.selectGenre(controller.genreIndex),
                  )
                else
                  FeedRows(
                    key: ValueKey((controller.genreIndex, index)),
                    section: controller.sections[index],
                    ranked: index == 1,
                    onSong: onSong,
                    onPlay: onPlay,
                    onRetry: () =>
                        controller.selectGenre(controller.genreIndex),
                  ),
                const SizedBox(height: 28),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class ListeningHero extends StatefulWidget {
  const ListeningHero({
    super.key,
    required this.playing,
    required this.motion,
    required this.onMotion,
    this.onPlay,
  });
  final bool playing, motion;
  final VoidCallback? onPlay;
  final ValueChanged<bool> onMotion;
  @override
  State<ListeningHero> createState() => _ListeningHeroState();
}

class _ListeningHeroState extends State<ListeningHero>
    with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ListeningHero oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    if (widget.playing &&
        widget.motion &&
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled) {
      if (!_spin.isAnimating) _spin.repeat();
    } else {
      _spin.stop();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [context.palette.raised, context.palette.surface],
      ),
      border: Border.all(color: context.palette.border),
      borderRadius: BorderRadius.circular(24),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 400;
        final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ÂM NHẠC CHO RIÊNG BẠN',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.5,
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Bật nhạc.\nChạm cảm xúc.',
              style: TextStyle(
                fontSize: 28,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Âm nhạc bên bạn, online và offline.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: playButtonStyle(context),
              onPressed: widget.onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Phát ngay'),
            ),
          ],
        );
        final disc = Semantics(
          label: 'Đĩa than BCMusic',
          child: RotationTransition(
            turns: _spin,
            child: CustomPaint(
              painter: _VinylPainter(),
              child: SizedBox.square(
                dimension: compact ? 110 : 172,
                child: Center(
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.jpg',
                      width: compact ? 42 : 64,
                      height: compact ? 42 : 64,
                      fit: BoxFit.cover,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        if (largeText) return copy;
        return Stack(
          children: [
            Positioned(
              right: -24,
              bottom: 8,
              child: ExcludeSemantics(child: Opacity(opacity: .3, child: disc)),
            ),
            Padding(padding: const EdgeInsets.only(right: 24), child: copy),
          ],
        );
      },
    ),
  );
}

class _VinylPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero), radius = size.shortestSide / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const RadialGradient(
          colors: [Color(0xff080b12), Color(0xff334053), Color(0xff080b12)],
        ).createShader(Offset.zero & size),
    );
    final ring = Paint()
      ..color = Colors.white.withValues(alpha: .13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .6;
    for (double r = radius - 3; r > radius * .32; r -= 3) {
      canvas.drawCircle(center, r, ring);
    }
    canvas.drawCircle(center, 2, Paint()..color = Colors.white70);
  }

  @override
  bool shouldRepaint(_VinylPainter oldDelegate) => false;
}

class FeedCarousel extends StatelessWidget {
  const FeedCarousel({
    super.key,
    required this.section,
    required this.onSong,
    required this.onPlay,
    required this.onRetry,
    this.ranked = false,
  });
  final FeedSection section;
  final DiscoverySelection onSong, onPlay;
  final VoidCallback onRetry;
  final bool ranked;
  @override
  Widget build(BuildContext context) {
    if (section.loading) {
      return const SizedBox(
        height: 170,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (section.error != null) {
      return DataMessage(message: section.error!, onRetry: onRetry);
    }
    if (section.songs.isEmpty) {
      return const DataMessage(
        message: 'Chưa có bài phù hợp trong thể loại này.',
      );
    }
    final height = 164 + 22 + MediaQuery.textScalerOf(context).scale(53);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: section.songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 16),
        itemBuilder: (context, index) => SizedBox(
          width: 164,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  InkWell(
                    onTap: () => onSong(section.songs[index], section.songs),
                    borderRadius: BorderRadius.circular(14),
                    child: SongImage(song: section.songs[index], size: 164),
                  ),
                  if (ranked)
                    Positioned(
                      top: 9,
                      left: 9,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black87,
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          '${index + 1}'.padLeft(2, '0'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: IconButton.filled(
                      style: playButtonStyle(context),
                      tooltip: 'Phát ${section.songs[index].title}',
                      onPressed: () =>
                          onPlay(section.songs[index], section.songs),
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                section.songs[index].title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                section.songs[index].artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: context.palette.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeedRows extends StatelessWidget {
  const FeedRows({
    super.key,
    required this.section,
    required this.onSong,
    required this.onPlay,
    required this.onRetry,
    this.ranked = false,
  });
  final FeedSection section;
  final DiscoverySelection onSong, onPlay;
  final VoidCallback onRetry;
  final bool ranked;
  @override
  Widget build(BuildContext context) {
    if (section.loading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (section.error != null) {
      return DataMessage(message: section.error!, onRetry: onRetry);
    }
    if (section.songs.isEmpty) {
      return const DataMessage(
        message: 'Chưa có bài phù hợp trong thể loại này.',
      );
    }
    final songs = section.songs.take(10).toList(growable: false);
    final scale = MediaQuery.textScalerOf(context);
    final rowHeight =
        24.0 +
        math.max(48.0, scale.scale(14) * 2.4 + scale.scale(12) * 1.2 + 4);
    return SizedBox(
      height: rowHeight * math.min(5, songs.length),
      child: ListView.builder(
        primary: false,
        padding: EdgeInsets.zero,
        physics: songs.length <= 5
            ? const NeverScrollableScrollPhysics()
            : null,
        itemCount: songs.length,
        itemExtent: rowHeight,
        itemBuilder: (context, index) {
          final song = songs[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onSong(song, songs),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      if (ranked)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${index + 1}'.padLeft(2, '0'),
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: context.palette.muted,
                            ),
                          ),
                        ),
                      SongImage(song: song, size: 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                height: 1.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.2,
                                color: context.palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Phát ${song.title}',
                        onPressed: () => onPlay(song, songs),
                        icon: const Icon(Icons.play_arrow_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class SongImage extends StatelessWidget {
  const SongImage({super.key, required this.song, this.size = 60});
  final DiscoverySong song;
  final double size;
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Image.network(
      song.thumbnail,
      width: size,
      height: size,
      fit: BoxFit.cover,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => Container(
        width: size,
        height: size,
        color: context.palette.raised,
        child: Icon(Icons.music_note_rounded, color: context.palette.action),
      ),
    ),
  );
}

class DataMessage extends StatelessWidget {
  const DataMessage({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      border: Border.all(color: context.palette.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          style: TextStyle(color: context.palette.muted, height: 1.5),
        ),
        if (onRetry != null)
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Thử lại'),
          ),
      ],
    ),
  );
}

class SearchScreen extends StatelessWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    required this.onSong,
    required this.onPlay,
  });
  final DiscoveryController controller;
  final DiscoverySelection onSong, onPlay;
  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
        sliver: SliverList.list(
          children: [
            const Text(
              'Tìm kiếm',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tìm giai điệu của riêng bạn.',
              style: TextStyle(color: context.palette.muted),
            ),
            const SizedBox(height: 22),
            TextField(
              textInputAction: TextInputAction.search,
              maxLength: 200,
              onSubmitted: controller.search,
              decoration: const InputDecoration(
                counterText: '',
                labelText: 'Bài hát hoặc nghệ sĩ',
                hintText: 'Tìm bài hát, nghệ sĩ…',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 22),
            if (controller.searching)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (controller.searchError != null)
              DataMessage(
                message: controller.searchError!,
                onRetry: () => controller.search(controller.query),
              )
            else if (controller.searchResults.isEmpty)
              DataMessage(
                message: controller.query.isEmpty
                    ? 'Nhập từ khóa rồi nhấn tìm kiếm trên bàn phím.'
                    : 'Chưa có kết quả phù hợp. Thử một từ khóa khác.',
              )
            else ...[
              Text(
                'Kết quả cho “${controller.query}”',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 14),
              for (final song in controller.searchResults)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      leading: SongImage(song: song, size: 52),
                      title: Text(
                        song.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${song.artist} · ${formatTime(song.durationMs)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.palette.muted,
                        ),
                      ),
                      onTap: () => onSong(song, controller.searchResults),
                      trailing: IconButton(
                        tooltip: 'Phát ${song.title}',
                        onPressed: () => onPlay(song, controller.searchResults),
                        icon: Icon(
                          Icons.play_arrow_rounded,
                          color: context.palette.text,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    ],
  );
}
