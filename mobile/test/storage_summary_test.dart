import 'package:bcmusic/models.dart';
import 'package:bcmusic/storage_summary.dart';
import 'package:flutter_test/flutter_test.dart';

OfflineTrack _track(
  String id, {
  String status = 'completed',
  int bytes = 0,
}) => OfflineTrack(
  id: id,
  title: id,
  artist: 'Ca sĩ',
  sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  provider: 'youtube',
  status: status,
  bytes: bytes,
);

void main() {
  test('totals only completed downloads and lists them largest first', () {
    final summary = StorageSummary.from([
      _track('a', bytes: 1000),
      _track('b', bytes: 3000),
      _track('c', status: 'downloading', bytes: 500),
      _track('d', status: 'failed', bytes: 900),
    ]);
    expect(summary.totalBytes, 4000);
    expect(summary.readyCount, 2);
    expect(summary.readyTracks.map((track) => track.id), ['b', 'a']);
    expect(summary.activeCount, 1);
    expect(summary.failedCount, 1);
  });

  test('a stopped download counts as failed and a preview counts as neither', () {
    final summary = StorageSummary.from([
      _track('stopped', status: 'stopped'),
      _track('preview', status: 'preview'),
    ]);
    expect(summary.failedCount, 1);
    expect(summary.activeCount, 0);
    expect(summary.readyCount, 0);
  });

  test('formatBytes picks a readable unit', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(formatBytes(3 * 1024 * 1024 * 1024 ~/ 2), '1.5 GB');
  });
}
