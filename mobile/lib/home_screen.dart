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
  });
  final MusicController controller;
  final bool soundCloud;
  final ValueChanged<OfflineTrack> onAddToPlaylist;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _filter = 0;
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
      final visible = tracks
          .where(
            (track) =>
                (_filter == 0 ||
                    (_filter == 1 ? track.isReady : !track.isReady)) &&
                '${track.title} ${track.artist}'.toLowerCase().contains(
                  _search,
                ),
          )
          .toList();
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverList.list(
              children: [
                Text(
                  widget.soundCloud ? 'NGUỒN NHẠC' : 'NGHE KHÔNG GIỚI HẠN',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.soundCloud ? 'SoundCloud' : 'Thư viện offline',
                  style: const TextStyle(
                    fontSize: 29,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.9,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '$completed bài sẵn sàng offline · Nghe cả khi khóa màn hình',
                  style: TextStyle(color: context.palette.muted, height: 1.5),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    border: Border.all(color: context.palette.border),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.download_done_rounded),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$completed bài đã tải',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${(tracks.fold<int>(0, (total, track) => total + track.bytes) / (1024 * 1024)).toStringAsFixed(1)} MB đã sử dụng',
                              style: TextStyle(
                                color: context.palette.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _addTrack,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    widget.soundCloud ? 'Nhập link SoundCloud' : 'Thêm bài',
                  ),
                ),
                const SizedBox(height: 20),
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
                  const SizedBox(height: 20),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (index, label) in [
                      'Tất cả',
                      'Đã tải',
                      'Đang tải / lỗi',
                    ].indexed)
                      ChoiceChip(
                        label: Text(label),
                        selected: _filter == index,
                        onSelected: (_) => setState(() => _filter = index),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (tracks.isNotEmpty) ...[
                  TextField(
                    onChanged: (text) =>
                        setState(() => _search = text.toLowerCase().trim()),
                    decoration: const InputDecoration(
                      hintText: 'Tìm trong thư viện',
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
          else if (visible.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(30, 30, 30, 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.headphones_rounded,
                      size: 58,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      tracks.isEmpty
                          ? 'Chưa có bài đã tải'
                          : 'Không có bài phù hợp',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tracks.isEmpty
                          ? (widget.soundCloud
                                ? 'Dán hoặc chia sẻ link bài từ SoundCloud.'
                                : 'Chia sẻ hoặc dán link YouTube / SoundCloud. Tải trước khi có mạng để nghe mọi lúc.')
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 30),
            sliver: SliverList.builder(
              itemCount: visible.length,
              itemBuilder: (context, index) {
                final track = visible[index];
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
        28,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Thêm vào thư viện',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            widget.soundCloud ? 'Dán link một bài SoundCloud.' : 'Dán link một bài hoặc chia sẻ từ YouTube / SoundCloud sang BCMusic.',
            style: TextStyle(color: context.palette.muted, height: 1.5),
          ),
          const SizedBox(height: 22),
          TextField(
            controller: _input,
            autofocus: true,
            maxLines: 3,
            maxLength: 8192,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Link bài hát',
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
            onPressed: () => Navigator.pop(context, _input.text),
            child: const Text('Xem thông tin bài'),
          ),
          const SizedBox(height: 12),
          Text(
            'Chỉ tải nội dung bạn có quyền lưu.',
            style: TextStyle(fontSize: 12, color: context.palette.muted),
          ),
        ],
      ),
    ),
  );
}
