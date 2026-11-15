import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'playlist_backup.dart';

/// Backs up local playlists as text and restores them on this or another phone.
class PlaylistBackupScreen extends StatefulWidget {
  const PlaylistBackupScreen({
    super.key,
    required this.controller,
    this.createPlaylist,
    this.addTrack,
  });

  final MusicController controller;

  /// Replace the controller's actions, for tests.
  final Future<String?> Function(String name)? createPlaylist;
  final Future<void> Function(String playlistId, String sourceUrl)? addTrack;

  @override
  State<PlaylistBackupScreen> createState() => _PlaylistBackupScreenState();
}

class _PlaylistBackupScreenState extends State<PlaylistBackupScreen> {
  final _input = TextEditingController();
  PlaylistBackup? _preview;
  String? _error;
  RestoreReport? _report;
  bool _restoring = false;
  int _done = 0, _total = 0;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _copyBackup() async {
    final backup = encodePlaylistBackup(
      playlists: widget.controller.snapshot.playlists,
      tracks: widget.controller.tracks,
    );
    await Clipboard.setData(ClipboardData(text: backup.text));
    if (!mounted) return;
    final skipped = backup.skippedTracks > 0
        ? ' Bỏ qua ${backup.skippedTracks} bài không còn trong thư viện.'
        : '';
    _showMessage(
      'Đã sao chép ${backup.playlistCount} playlist, '
      '${backup.trackCount} bài.$skipped',
    );
  }

  Future<void> _pasteFromClipboard() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (!mounted) return;
    if (text == null || text.trim().isEmpty) {
      _showMessage('Clipboard đang trống.');
      return;
    }
    _input.text = text;
    _readInput();
  }

  void _readInput() {
    try {
      final backup = decodePlaylistBackup(_input.text);
      setState(() {
        _preview = backup;
        _error = null;
        _report = null;
      });
    } on FormatException catch (error) {
      setState(() {
        _preview = null;
        _error = error.message;
      });
    }
  }

  Future<void> _restore(PlaylistBackup backup) async {
    setState(() {
      _restoring = true;
      _done = 0;
      _total = backup.trackCount;
      _report = null;
    });
    final report = await restorePlaylistBackup(
      backup,
      createPlaylist:
          widget.createPlaylist ?? widget.controller.createEmptyPlaylist,
      addTrack: widget.addTrack ?? widget.controller.addSourceToPlaylist,
      onProgress: (done, total) {
        if (!mounted) return;
        setState(() {
          _done = done;
          _total = total;
        });
      },
    );
    if (!mounted) return;
    setState(() {
      _restoring = false;
      _report = report;
      _preview = null;
      _input.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final playlistCount = widget.controller.snapshot.playlists.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Sao lưu playlist')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Playlist chỉ được lưu trên máy này. Sao lưu để giữ lại, hoặc '
            'chuyển sang điện thoại khác.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: playlistCount == 0 ? null : _copyBackup,
            icon: const Icon(Icons.copy_rounded),
            label: Text('Sao chép bản sao lưu ($playlistCount playlist)'),
          ),
          const SizedBox(height: 28),
          const Text(
            'Khôi phục',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Dán nội dung bản sao lưu. Các bài chưa có trên máy sẽ được tải về.',
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _input,
            minLines: 3,
            maxLines: 6,
            enabled: !_restoring,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              hintText: 'Dán nội dung bản sao lưu vào đây',
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _restoring ? null : _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_rounded),
                  label: const Text('Dán từ clipboard'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _restoring || _input.text.trim().isEmpty
                      ? null
                      : _readInput,
                  child: const Text('Xem trước'),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Color(0xffff8a8a))),
          ],
          if (_preview case final preview?) ...[
            const SizedBox(height: 18),
            _PreviewCard(
              preview: preview,
              restoring: _restoring,
              onRestore: () => _restore(preview),
            ),
          ],
          if (_restoring) ...[
            const SizedBox(height: 18),
            LinearProgressIndicator(
              value: _total == 0 ? null : _done / _total,
            ),
            const SizedBox(height: 8),
            Text(
              'Đang khôi phục $_done/$_total bài…',
              style: TextStyle(color: palette.muted),
            ),
          ],
          if (_report case final report?) ...[
            const SizedBox(height: 18),
            _ReportCard(report: report),
          ],
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.preview,
    required this.restoring,
    required this.onRestore,
  });

  final PlaylistBackup preview;
  final bool restoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final shown = preview.playlists.take(8).toList();
    final hidden = preview.playlists.length - shown.length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sẽ khôi phục ${preview.playlists.length} playlist, '
              '${preview.trackCount} bài',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (preview.skippedEntries > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Bỏ qua ${preview.skippedEntries} mục không hợp lệ.',
                  style: TextStyle(color: palette.muted),
                ),
              ),
            const SizedBox(height: 10),
            for (final playlist in shown)
              Text(
                '• ${playlist.name} (${playlist.tracks.length} bài)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            if (hidden > 0)
              Text(
                'Và $hidden playlist khác',
                style: TextStyle(color: palette.muted),
              ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: restoring || preview.playlists.isEmpty
                  ? null
                  : onRestore,
              child: const Text('Bắt đầu khôi phục'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final RestoreReport report;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final problems = report.tracksFailed > 0 || report.playlistsFailed > 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Đã tạo ${report.playlistsCreated} playlist, '
              'thêm ${report.tracksAdded} bài.',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (problems)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${report.tracksFailed} bài chưa khôi phục được '
                  '(link không còn hoạt động hoặc mất mạng). '
                  'Bạn có thể thử lại sau.',
                  style: TextStyle(color: palette.muted, height: 1.4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
