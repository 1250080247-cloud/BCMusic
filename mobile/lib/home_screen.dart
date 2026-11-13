import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'models.dart';
import 'track_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    this.soundCloud = false,
    required this.onAddToPlaylist,
    this.onPlaylist,
  });
  final MusicController controller;
  final bool soundCloud;
  final ValueChanged<OfflineTrack> onAddToPlaylist;
  final VoidCallback? onPlaylist;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

enum _LibraryFilter { all, downloaded, listened, pending }

class _HomeScreenState extends State<HomeScreen> {
  _LibraryFilter _filter = _LibraryFilter.all;
  String _search = '';
  MusicController get controller => widget.controller;

  Future<void> _addTrack() async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LinkInputSheet(soundCloud: widget.soundCloud),
    );
    if (text != null && mounted) {
      await controller.inspect(text, soundCloudOnly: widget.soundCloud);
    }
  }

  Future<void> _remove(OfflineTrack track) async {
    final remove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(track.isReady ? 'Xóa bản tải?' : 'Hủy bản tải?'),
        content: Text(
          '“${track.title}” sẽ được gỡ khỏi thư viện trên điện thoại này.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Giữ lại'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (remove == true) await controller.remove(track);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final tracks = controller.tracks
          .where(
            (track) => !widget.soundCloud || track.provider == 'soundcloud',
          )
          .toList();
      final completed = tracks.where((track) => track.isReady).length;
      final totalMb =
          tracks.fold<int>(0, (total, track) => total + track.bytes) /
          (1024 * 1024);
      final showingHistory = _filter == _LibraryFilter.listened;
      final visible =
          (showingHistory ? controller.snapshot.listeningHistory : tracks)
              .where(
                (track) => '${track.title} ${track.artist}'
                    .toLowerCase()
                    .contains(_search),
              )
              .where(
                (track) => switch (_filter) {
                  _LibraryFilter.downloaded => track.isReady,
                  _LibraryFilter.pending => !track.isReady,
                  _ => true,
                },
              )
              .toList();

      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
            sliver: SliverList.list(
              children: [
                Text(
                  widget.soundCloud
                      ? 'DISCOVER WITHOUT LIMITS'
                      : 'YOUR MUSIC, EVERYWHERE',
                  style: const TextStyle(
                    fontSize: 9.5,
                    letterSpacing: 1.8,
                    color: Color(0xff8f84a9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.soundCloud ? 'SoundCloud' : 'Thư viện offline',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 28,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                        ),
                      ),
                    ),
                    if (widget.soundCloud) ...[
                      const SizedBox(width: 10),
                      const Icon(
                        Icons.cloud_outlined,
                        size: 28,
                        color: Color(0xffdca27d),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.soundCloud
                      ? 'Kết nối với một thế giới âm nhạc độc lập.'
                      : 'Những giai điệu luôn đồng hành cùng bạn.',
                  style: TextStyle(color: context.palette.muted, fontSize: 12.5),
                ),
                const SizedBox(height: 18),

                // .storage-card.glass / .soundcloud-card từ App.tsx
                LiquidGlassCard(
                  borderRadius: 18,
                  padding: const EdgeInsets.all(18),
                  gradient: LinearGradient(
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                    colors: widget.soundCloud
                        ? const [Color(0x459c5633), Color(0x991a1c29)]
                        : const [Color(0x4567508c), Color(0x991a1c29)],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              size: 12,
                              color: widget.soundCloud
                                  ? const Color(0xffdca27d)
                                  : const Color(0xffb3a0cd),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              widget.soundCloud
                                  ? 'SOUNDCLOUD'
                                  : 'OFFLINE READY',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 0.8,
                                fontWeight: FontWeight.w700,
                                color: widget.soundCloud
                                    ? const Color(0xffdca27d)
                                    : const Color(0xffb3a0cd),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: widget.soundCloud
                                  ? const Color(0x26bb7b4b)
                                  : const Color(0x24b7a1de),
                              border: Border.all(
                                color: const Color(0x28c7b1ed),
                              ),
                            ),
                            child: Icon(
                              widget.soundCloud
                                  ? Icons.cloud_rounded
                                  : Icons.download_done_rounded,
                              color: widget.soundCloud
                                  ? const Color(0xffdca27d)
                                  : const Color(0xffc2addb),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(right: 72),
                                  child: Text(
                                    '$completed bài trong bộ sưu tập offline',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '${totalMb.toStringAsFixed(1)} MB đã sử dụng · Nghe cả khi mất mạng',
                                  style: const TextStyle(
                                    color: Color(0xff8d849e),
                                    fontSize: 11.5,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: tracks.isEmpty
                                        ? 0.08
                                        : (completed / tracks.length).clamp(
                                            0.1,
                                            1.0,
                                          ),
                                    minHeight: 3,
                                    backgroundColor: const Color(0x18ffffff),
                                    color: const Color(0xffc4b3dc),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: playButtonStyle(context),
                  onPressed: _addTrack,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    widget.soundCloud
                        ? 'Nhập link SoundCloud'
                        : 'Thêm bài',
                  ),
                ),
                const SizedBox(height: 18),
                if (controller.resolving) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 10),
                  const Text('Đang lấy thông tin bài…'),
                  const SizedBox(height: 16),
                ],
                if (controller.preview case final track?
                    when !widget.soundCloud ||
                        track.provider == 'soundcloud') ...[
                  PreviewCard(
                    track: track,
                    busy: controller.downloading,
                    onDownload: controller.downloadPreview,
                    onClose: controller.dismissPreview,
                  ),
                  const SizedBox(height: 18),
                ],
                if (controller.playlistPreview case final playlist?
                    when !widget.soundCloud ||
                        playlist.provider == 'soundcloud') ...[
                  PlaylistPreviewCard(
                    playlist: playlist,
                    busy: controller.downloading,
                    onDownload: () async {
                      await controller.downloadPlaylistPreview();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Đã thêm “${playlist.name}” vào Playlist offline và bắt đầu tải ${playlist.tracks.length} bài.',
                            ),
                          ),
                        );
                      }
                    },
                    onClose: controller.dismissPreview,
                  ),
                  const SizedBox(height: 18),
                ],
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    spacing: 8,
                    children: [
                      for (final (filter, label) in [
                        (_LibraryFilter.all, 'Tất cả'),
                        (_LibraryFilter.downloaded, 'Đã tải'),
                        if (!widget.soundCloud)
                          (_LibraryFilter.listened, 'Đã nghe'),
                        (_LibraryFilter.pending, 'Đang tải / lỗi'),
                      ])
                        ChoiceChip(
                          showCheckmark: false,
                          label: Text(label),
                          labelStyle: TextStyle(
                            color: _filter == filter
                                ? const Color(0xffddd3f1)
                                : const Color(0xff959aac),
                          ),
                          selected: _filter == filter,
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      if (widget.onPlaylist case final onPlaylist?)
                        ActionChip(
                          label: const Text('Playlist'),
                          onPressed: onPlaylist,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                if (tracks.isNotEmpty || showingHistory) ...[
                  TextField(
                    onChanged: (text) =>
                        setState(() => _search = text.toLowerCase().trim()),
                    decoration: const InputDecoration(
                      hintText: 'Tìm trong thư viện…',
                      prefixIcon: Icon(Icons.search_rounded),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
          if (controller.loading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (showingHistory && visible.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  _search.isEmpty
                      ? 'Các bài bạn đã phát trên thiết bị này sẽ hiện ở đây.'
                      : 'Không tìm thấy bài đã nghe phù hợp.',
                ),
              ),
            )
          else if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 30, 30, 130),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.music_note_rounded,
                      size: 48,
                      color: Color(0xffa68abd),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tracks.isEmpty
                          ? 'Chưa có bài đã tải'
                          : 'Không có bài phù hợp',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xffc5b6d3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tracks.isEmpty
                          ? (widget.soundCloud
                                ? 'Dán hoặc chia sẻ link bài từ SoundCloud.'
                                : 'Chia sẻ hoặc dán link YouTube / SoundCloud để nghe mọi lúc.')
                          : 'Thử đổi bộ lọc hoặc từ khóa tìm kiếm.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: context.palette.muted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 130),
            sliver: SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final track = visible[index];
                if (showingHistory) {
                  return ListTile(
                    leading: TrackArtwork(
                      path: track.artworkPath,
                      url: track.artworkUrl,
                      size: 48,
                    ),
                    title: Text(
                      track.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => controller.playSource(track.sourceUrl),
                  );
                }
                return TrackTile(
                  track: track,
                  busy: controller.isPending(track.id),
                  selected: controller.playback.trackId == track.id,
                  onPlay: () => controller.play(track),
                  onRetry: () => controller.retry(track),
                  onRemove: () => _remove(track),
                  onAddToPlaylist: track.isReady
                      ? () => widget.onAddToPlaylist(track)
                      : null,
                );
              },
            ),
          ),
        ],
      );
    },
  );
}

class LinkInputSheet extends StatefulWidget {
  const LinkInputSheet({super.key, this.soundCloud = false});
  final bool soundCloud;
  @override
  State<LinkInputSheet> createState() => _LinkInputSheetState();
}

class _LinkInputSheetState extends State<LinkInputSheet> {
  final _input = TextEditingController();
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.soundCloud ? 'Từ SoundCloud, đến bạn.' : 'Thêm vào thư viện',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            widget.soundCloud
                ? 'Dán link một bài hoặc playlist SoundCloud.'
                : 'Dán link một bài hoặc chia sẻ từ YouTube / SoundCloud sang BCMusic.',
            style: TextStyle(color: context.palette.muted, height: 1.5),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _input,
            autofocus: true,
            maxLines: 3,
            maxLength: 8192,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: widget.soundCloud
                  ? 'Link bài hát hoặc playlist'
                  : 'Link bài hát',
              counterText: '',
              suffixIcon: IconButton(
                tooltip: 'Dán liên kết',
                onPressed: () async {
                  final clipboard = await Clipboard.getData(
                    Clipboard.kTextPlain,
                  );
                  if (mounted && clipboard?.text != null) {
                    _input.text = clipboard!.text!;
                  }
                },
                icon: const Icon(Icons.content_paste_rounded),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: playButtonStyle(context),
            onPressed: () => Navigator.pop(context, _input.text),
            child: const Text('Xem thông tin bài'),
          ),
        ],
      ),
    ),
  );
}