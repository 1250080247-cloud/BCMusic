import 'package:flutter/material.dart';

import 'app_controller.dart';
import 'app_theme.dart';
import 'models.dart';
import 'storage_summary.dart';

const _sectionStyle = TextStyle(
  fontSize: 9.5,
  letterSpacing: 1.8,
  color: Color(0xff8f84a9),
  fontWeight: FontWeight.w600,
);

/// Shows what the offline library uses, deletes downloads in bulk and retries
/// the ones that failed.
class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key, required this.controller});

  final MusicController controller;

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  final _selected = <String>{};
  bool _working = false;

  Future<bool> _confirm(String title, String message, String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _removeTracks(List<OfflineTrack> tracks) async {
    setState(() => _working = true);
    for (final track in tracks) {
      await widget.controller.remove(track);
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _selected.removeAll(tracks.map((track) => track.id));
    });
  }

  Future<void> _deleteSelected(List<OfflineTrack> ready) async {
    final chosen = ready
        .where((track) => _selected.contains(track.id))
        .toList();
    if (chosen.isEmpty) return;
    final ok = await _confirm(
      'Xóa ${chosen.length} bản đã tải?',
      'Bài vẫn còn trong playlist, nhưng cần tải lại để nghe offline.',
      'Xóa',
    );
    if (ok) await _removeTracks(chosen);
  }

  Future<void> _deleteAll(List<OfflineTrack> ready) async {
    final ok = await _confirm(
      'Xóa tất cả bản đã tải?',
      'Toàn bộ ${ready.length} bài đã tải sẽ bị xóa khỏi máy. '
          'Playlist không bị ảnh hưởng.',
      'Xóa tất cả',
    );
    if (ok) await _removeTracks(ready);
  }

  Future<void> _retryFailed(List<OfflineTrack> failed) async {
    setState(() => _working = true);
    for (final track in failed) {
      await widget.controller.retry(track);
    }
    if (mounted) setState(() => _working = false);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final all = widget.controller.tracks;
      final summary = StorageSummary.from(all);
      final ready = summary.readyTracks;
      final failed = all.where(isFailedTrack).toList();
      final active = all.where((track) => track.isActive).toList();
      _selected.retainAll(ready.map((track) => track.id));
      final palette = context.palette;
      final allSelected = ready.isNotEmpty && _selected.length == ready.length;

      return Scaffold(
        appBar: AppBar(title: const Text('Dung lượng & bản tải')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              formatBytes(summary.totalBytes),
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${summary.readyCount} bài đã tải · '
              '${summary.activeCount} đang tải · '
              '${summary.failedCount} lỗi',
              style: TextStyle(color: palette.muted),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _working || _selected.isEmpty
                      ? null
                      : () => _deleteSelected(ready),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text('Xóa đã chọn (${_selected.length})'),
                ),
                OutlinedButton(
                  onPressed: _working || ready.isEmpty
                      ? null
                      : () => setState(() {
                          if (allSelected) {
                            _selected.clear();
                          } else {
                            _selected
                              ..clear()
                              ..addAll(ready.map((track) => track.id));
                          }
                        }),
                  child: Text(allSelected ? 'Bỏ chọn' : 'Chọn tất cả'),
                ),
                if (failed.isNotEmpty)
                  OutlinedButton(
                    onPressed: _working ? null : () => _retryFailed(failed),
                    child: Text('Thử lại ${failed.length} bản lỗi'),
                  ),
                TextButton(
                  onPressed: _working || ready.isEmpty
                      ? null
                      : () => _deleteAll(ready),
                  child: const Text('Xóa tất cả'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (ready.isEmpty)
              Text(
                'Chưa có bài nào được tải về máy.',
                style: TextStyle(color: palette.muted),
              )
            else ...[
              const Text('ĐÃ TẢI · LỚN NHẤT TRƯỚC', style: _sectionStyle),
              for (final track in ready)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _selected.contains(track.id),
                  onChanged: _working
                      ? null
                      : (value) => setState(() {
                          if (value == true) {
                            _selected.add(track.id);
                          } else {
                            _selected.remove(track.id);
                          }
                        }),
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${track.artist} · ${formatBytes(track.bytes)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            if (active.isNotEmpty || failed.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('ĐANG TẢI / LỖI', style: _sectionStyle),
              for (final track in [...active, ...failed])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    track.isActive
                        ? 'Đang tải…'
                        : (track.error ?? 'Tải thất bại'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    tooltip: track.isActive ? 'Hủy' : 'Thử lại',
                    onPressed: _working
                        ? null
                        : () {
                            if (track.isActive) {
                              widget.controller.remove(track);
                            } else {
                              widget.controller.retry(track);
                            }
                          },
                    icon: Icon(
                      track.isActive
                          ? Icons.close_rounded
                          : Icons.refresh_rounded,
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}
