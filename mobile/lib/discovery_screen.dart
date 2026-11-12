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
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
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
                    onTrackAction: onTrackAction,
                    onDownload: onDownload,
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
              onPressed: onPlay,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Phát ngay'),
            ),
          ],
        );
        if (largeText) return copy;
        return Stack(
          children: [
            Positioned(
              right: 0,
              bottom: 12,
              child: ExcludeSemantics(
                child: StreamBuilder<List<double>>(
                  stream:
                      motion &&
                          TickerMode.valuesOf(context).enabled &&
                          !MediaQuery.disableAnimationsOf(context)
                      ? spectrum
                      : null,
                  builder: (context, snapshot) {
                    final bands =
                        snapshot.connectionState == ConnectionState.active &&
                            snapshot.data?.length == 3
                        ? snapshot.data!
                        : const [0.0, 0.0, 0.0];
                    return SizedBox(
                      height: 78,
                      width: compact ? 86 : 128,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          for (final (index, band) in const [
                            2,
                            1,
                            0,
                            0,
                            1,
                            2,
                            1,
                          ].indexed)
                            TweenAnimationBuilder<double>(
                              tween: Tween(
                                end:
                                    7 +
                                    (bands[band] * (index.isEven ? 60 : 70)),
                              ),
                              duration:
                                  motion &&
                                      !MediaQuery.disableAnimationsOf(context)
                                  ? const Duration(milliseconds: 110)
                                  : Duration.zero,
                              builder: (context, height, _) => Container(
                                height: height,
                                width: 5,
                                decoration: BoxDecoration(
                                  color: context.palette.action.withValues(
                                    alpha: .32 + band * .09,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(padding: const EdgeInsets.only(right: 24), child: copy),
          ],
        );
      },
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
              color: context.palette.surface,
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => onPlay(song, songs),
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
        // History remains available when suggestions cannot load.
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
    return CustomScrollView(
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
                controller: _input,
                textInputAction: TextInputAction.search,
                maxLength: 200,
                onChanged: _type,
                onSubmitted: _submit,
                decoration: InputDecoration(
                  counterText: '',
                  labelText: 'Bài hát',
                  hintText: 'Tìm bài hát…',
                  prefixIcon: const Icon(Icons.search_rounded),
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
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  for (final term in history)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.history_rounded),
                      title: Text(
                        term,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => _submit(term),
                    ),
                  const SizedBox(height: 12),
                ],
                if (suggestions.isNotEmpty) ...[
                  const Text(
                    'Gợi ý tìm kiếm',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (query.isEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final term in suggestions)
                          ActionChip(
                            label: Text(term),
                            onPressed: () => _submit(term),
                          ),
                      ],
                    )
                  else
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
                if (history.isEmpty && suggestions.isEmpty)
                  const DataMessage(
                    message: 'Nhấn tìm kiếm trên bàn phím để xem kết quả.',
                  ),
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
