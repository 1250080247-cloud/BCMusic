import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'discovery.dart';
import 'models.dart';
import 'track_actions.dart';

typedef DiscoveryTrackAction = void Function(
  TrackAction action,
  DiscoverySong song,
);

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
    required this.onTrackAction,
    required this.onDownload,
    required this.onLibrary,
    this.spectrum,
    this.online = true,
    this.motion = true,
  });
  final DiscoveryController controller;
  final DiscoveryTrackAction onTrackAction;
  final ValueChanged<String> onDownload;
  final DiscoverySelection onSong, onPlay;
  final VoidCallback onLibrary;
  final Stream<List<double>>? spectrum;
  final bool online, motion;

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () => controller.selectGenre(controller.genreIndex),
    child: CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 130),
          sliver: SliverList.list(
            children: [
              ListeningHero(
                motion: motion,
                spectrum: spectrum,
                onPlay: controller.sections.first.songs.isEmpty
                    ? null
                    : () => onPlay(
                        controller.sections.first.songs.first,
                        controller.sections.first.songs,
                      ),
              ),
              const SizedBox(height: 18),
              if (!online) ...[
                TextButton.icon(
                  onPressed: onLibrary,
                  icon: const Icon(Icons.offline_pin_rounded),
                  label: const Text('Đang offline · Mở các bài đã tải'),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: musicGenres.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final selected = controller.genreIndex == index;
                    return ChoiceChip(
                      showCheckmark: false,
                      label: Text(
                        index == 0
                            ? '✦ ${musicGenres[index].label}'
                            : musicGenres[index].label,
                      ),
                      labelStyle: TextStyle(
                        color: selected
                            ? const Color(0xffddd3f1)
                            : const Color(0xff959aac),
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      selected: selected,
                      onSelected: (_) => controller.selectGenre(index),
                    );
                  },
                ),
              ),
              const SizedBox(height: 22),
              for (var index = 0; index < 3; index++) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        'ĐANG ĐƯỢC YÊU THÍCH',
                        'GIAI ĐIỆU NỔI BẬT',
                        'MỚI PHÁT HÀNH',
                      ][index],
                      style: const TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 1.6,
                        fontWeight: FontWeight.w600,
                        color: Color(0xff7a758e),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        Flexible(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  [
                                    'Top thịnh hành',
                                    'Xem nhiều nhất',
                                    'Mới nhất',
                                  ][index],
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 7),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xffc4acee),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(color: context.palette.border),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            musicGenres[controller.genreIndex].label,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: context.palette.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (index == 0)
                  FeedCarousel(
                    section: controller.sections[index],
                    ranked: true,
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
                    onTrackAction: onTrackAction,
                    onDownload: onDownload,
                    onPlay: onPlay,
                    onRetry: () =>
                        controller.selectGenre(controller.genreIndex),
                  ),
                const SizedBox(height: 26),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class ListeningHero extends StatelessWidget {
  const ListeningHero({
    super.key,
    required this.motion,
    this.onPlay,
    this.spectrum,
  });
  final bool motion;
  final VoidCallback? onPlay;
  final Stream<List<double>>? spectrum;

  @override
  Widget build(BuildContext context) => LiquidGlassCard(
    borderRadius: 20,
    padding: EdgeInsets.zero,
    gradient: const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color(0xe627243c),
        Color(0xbf262235),
        Color(0xb3323543),
      ],
    ),
    borderColor: const Color(0x36c4b4dd),
    child: Stack(
      children: [
        // Đĩa than Vinyl nghệ thuật góc phải (.vinyl trong App.tsx)
        Positioned(
          right: -55,
          top: 14,
          child: IgnorePointer(
            child: Container(
              width: 175,
              height: 175,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const SweepGradient(
                  colors: [
                    Color(0xff15141c),
                    Color(0xff33303b),
                    Color(0xff191720),
                    Color(0xff45434b),
                    Color(0xff15141c),
                  ],
                ),
                border: Border.all(color: const Color(0x55747079)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x66090711),
                    blurRadius: 24,
                    offset: Offset(-8, 12),
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 62,
                  height: 62,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xffd9c8ed), Color(0xff9784b4)],
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'BC',
                      style: TextStyle(
                        color: Color(0xff43334d),
                        fontWeight: FontWeight.w800,
                        fontSize: 18,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Thẻ nổi .hero-floating kèm sóng nhạc trực tiếp
        Positioned(
          right: 12,
          bottom: 18,
          child: IgnorePointer(
            child: Transform.rotate(
              angle: -0.08,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  color: const Color(0x24f0e4ff),
                  border: Border.all(color: const Color(0x30eee5ff)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        color: const Color(0x30d6c3f5),
                      ),
                      child: const Icon(
                        Icons.music_note_rounded,
                        size: 14,
                        color: Color(0xffe0d2ee),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your mood. Your music.',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          'Không giới hạn cảm xúc',
                          style: TextStyle(
                            fontSize: 8,
                            color: Color(0xffb5aabd),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    StreamBuilder<List<double>>(
                      stream: motion ? spectrum : null,
                      builder: (context, snapshot) {
                        final active =
                            snapshot.hasData &&
                            snapshot.data!.any((v) => v > 0.05);
                        return EqualizerBars(active: active, size: 15);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 90, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xffd0b9fd),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      'ÂM NHẠC CHO RIÊNG BẠN',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w600,
                        color: Color(0xffc9b6e8),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontFamily: 'BeVietnamPro',
                    fontSize: 28,
                    height: 1.18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                    color: Color(0xfff4f5fa),
                  ),
                  children: [
                    TextSpan(text: 'Bật nhạc.\nChạm '),
                    TextSpan(
                      text: 'cảm xúc.',
                      style: TextStyle(color: Color(0xffc9b7ef)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Giai điệu bạn yêu, cảm xúc bạn cần.\nĐể âm nhạc kể câu chuyện của bạn.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: Color(0xffa29ab5),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: playButtonStyle(context),
                onPressed: onPlay,
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Phát ngay  →'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
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
    final height = 164 + 24 + MediaQuery.textScalerOf(context).scale(52);
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: section.songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) {
          final song = section.songs[index];
          return SizedBox(
            width: 164,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    InkWell(
                      onTap: () => onSong(song, section.songs),
                      borderRadius: BorderRadius.circular(14),
                      child: SongImage(song: song, size: 164),
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
                            color: const Color(0x880c1017),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0x38ffffff)),
                          ),
                          child: Text(
                            '${index + 1}'.padLeft(2, '0'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: () => onPlay(song, section.songs),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0x45ffffff),
                            border: Border.all(color: const Color(0x66ffffff)),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 20,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  song.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: context.palette.muted),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class FeedRows extends StatelessWidget {
  const FeedRows({
    super.key,
    required this.section,
    this.onTrackAction,
    this.onDownload,
    required this.onPlay,
    required this.onRetry,
    this.ranked = false,
  });
  final FeedSection section;
  final DiscoverySelection onPlay;
  final DiscoveryTrackAction? onTrackAction;
  final ValueChanged<String>? onDownload;
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
    final download = onDownload;
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
              color: const Color(0x88171b26),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Color(0x12ffffff)),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onPlay(song, songs),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      if (ranked)
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${index + 1}'.padLeft(2, '0'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.palette.muted,
                            ),
                          ),
                        ),
                      SongImage(song: song, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13.5,
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
                                fontSize: 11.5,
                                color: context.palette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onTrackAction case final handle?)
                        TrackMenu(
                          title: song.title,
                          onSelected: (action) => handle(action, song),
                          onDownload: download == null
                              ? null
                              : () => download(song.sourceUrl),
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
    borderRadius: BorderRadius.circular(12),
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

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.controller,
    required this.onSong,
    required this.onPlay,
    required this.onTrackAction,
    required this.history,
    required this.onRecordSearch,
  });
  final DiscoveryController controller;
  final DiscoveryTrackAction onTrackAction;
  final DiscoverySelection onSong, onPlay;
  final List<String> history;
  final ValueChanged<String> onRecordSearch;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _input = TextEditingController();
  Timer? _debounce;
  int _request = 0;
  List<String> _suggestions = const [];
  DiscoveryController get controller => widget.controller;

  void _type(String value) {
    final request = ++_request;
    _debounce?.cancel();
    setState(() => _suggestions = const []);
    final query = value.trim();
    final repository = controller.repository;
    if (query.length < 2 ||
        query.length > 120 ||
        repository is! SearchSuggestions) {
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 320), () async {
      try {
        final suggestions = await (repository as SearchSuggestions).suggestions(
          query,
        );
        if (mounted && request == _request) {
          setState(() => _suggestions = suggestions);
        }
      } on Exception {
        // Giữ nguyên lịch sử khi mạng chậm
      }
    });
  }

  void _submit(String value) {
    final query = value.trim();
    _request++;
    _debounce?.cancel();
    _input.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    setState(() => _suggestions = const []);
    if (query.isNotEmpty) widget.onRecordSearch(query);
    FocusScope.of(context).unfocus();
    controller.search(query);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _input.text.trim();
    final normalized = query.toLowerCase();
    final showSuggestions = query.isEmpty || query != controller.query;
    final history = widget.history
        .where((term) => term.toLowerCase().contains(normalized))
        .take(6);
    final matchingTitles = {
      for (final section in controller.sections)
        for (final song in section.songs)
          if (song.title.toLowerCase().contains(normalized)) song.title,
    };
    final suggestions = query.isEmpty
        ? musicGenres.take(5).map((genre) => genre.label)
        : (_suggestions.isEmpty ? matchingTitles : _suggestions)
              .where(
                (term) => !history.any(
                  (previous) => previous.toLowerCase() == term.toLowerCase(),
                ),
              )
              .take(6);

    const moods = [
      (
        'Chill một chút',
        'Lofi',
        'SLOW DOWN. TUNE IN.',
        [Color(0xff3a2b55), Color(0xff252136)],
        Icons.headphones_rounded,
      ),
      (
        'Năng lượng mới',
        'TikTok Remix',
        'TURN IT ALL THE WAY UP.',
        [Color(0xff58362d), Color(0xff2d2224)],
        Icons.music_note_rounded,
      ),
      (
        'Nhẹ nhàng thôi',
        'Acoustic',
        'JUST YOU & THE MUSIC.',
        [Color(0xff2c4b41), Color(0xff1c2a29)],
        Icons.cloud_outlined,
      ),
      (
        'Nhạc Việt yêu thích',
        'Rap Việt',
        'HOMEGROWN SOUNDS.',
        [Color(0xff513144), Color(0xff2d202d)],
        Icons.favorite_border_rounded,
      ),
    ];

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 130),
          sliver: SliverList.list(
            children: [
              const Text(
                'FIND YOUR NEXT FAVORITE',
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 1.8,
                  color: Color(0xff8f84a9),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Tìm kiếm',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Tìm giai điệu của riêng bạn.',
                style: TextStyle(color: context.palette.muted, fontSize: 12.5),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _input,
                textInputAction: TextInputAction.search,
                maxLength: 200,
                onChanged: _type,
                onSubmitted: _submit,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Tìm bài hát, nghệ sĩ, thể loại…',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Color(0xffab9bc3),
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa từ khóa',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => _submit(''),
                        ),
                ),
              ),
              const SizedBox(height: 22),
              if (showSuggestions) ...[
                if (history.isNotEmpty) ...[
                  const Text(
                    'Lịch sử tìm kiếm',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final term in history)
                        ActionChip(
                          avatar: const Icon(Icons.schedule_rounded, size: 15),
                          label: Text(term),
                          onPressed: () => _submit(term),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                ],
                if (query.isEmpty) ...[
                  const Text(
                    'Khám phá theo cảm xúc',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.15,
                    children: [
                      for (final mood in moods)
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _submit(mood.$2),
                          child: Ink(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: mood.$4,
                              ),
                              border: Border.all(
                                color: const Color(0x24ffffff),
                              ),
                            ),
                            child: Stack(
                              children: [
                                Positioned(
                                  right: -6,
                                  bottom: -6,
                                  child: Icon(
                                    mood.$5,
                                    size: 62,
                                    color: Colors.white.withValues(alpha: 0.14),
                                  ),
                                ),
                                Positioned.fill(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.topLeft,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          mood.$3,
                                          style: const TextStyle(
                                            fontSize: 8,
                                            letterSpacing: 1.1,
                                            color: Colors.white60,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          mood.$1,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            height: 1.25,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              mood.$2,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: Colors.white70,
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            const Icon(
                                              Icons.arrow_forward_rounded,
                                              size: 14,
                                              color: Colors.white70,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ] else if (suggestions.isNotEmpty) ...[
                  const Text(
                    'Gợi ý tìm kiếm',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (final term in suggestions)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.search_rounded),
                      title: Text(
                        term,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _submit(term),
                    ),
                ],
              ] else if (controller.searching)
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
                      : 'Chưa tìm thấy giai điệu này. Thử một từ khóa khác.',
                )
              else ...[
                Text(
                  'Kết quả cho “${controller.query}”',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                for (final song in controller.searchResults)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: const Color(0x88191d28),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: Color(0x12ffffff)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        leading: SongImage(song: song, size: 48),
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
                        onTap: () =>
                            widget.onSong(song, controller.searchResults),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Phát ${song.title}',
                              onPressed: () =>
                                  widget.onPlay(song, controller.searchResults),
                              icon: Icon(
                                Icons.play_arrow_rounded,
                                color: context.palette.text,
                              ),
                            ),
                            TrackMenu(
                              title: song.title,
                              artist: song.artist,
                              artworkUrl: song.thumbnail,
                              onSelected: (action) =>
                                  widget.onTrackAction(action, song),
                            ),
                          ],
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
}