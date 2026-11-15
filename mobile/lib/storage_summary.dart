import 'models.dart';

/// Totals for the offline library shown on the downloads screen.
class StorageSummary {
  const StorageSummary({
    required this.readyTracks,
    required this.totalBytes,
    required this.activeCount,
    required this.failedCount,
  });

  factory StorageSummary.from(Iterable<OfflineTrack> tracks) {
    final all = tracks.toList();
    final ready = all.where((track) => track.isReady).toList()
      ..sort((a, b) => b.bytes.compareTo(a.bytes));
    return StorageSummary(
      readyTracks: ready,
      totalBytes: ready.fold(0, (total, track) => total + track.bytes),
      activeCount: all.where((track) => track.isActive).length,
      failedCount: all.where(isFailedTrack).length,
    );
  }

  /// Completed downloads, largest first.
  final List<OfflineTrack> readyTracks;
  final int totalBytes, activeCount, failedCount;

  int get readyCount => readyTracks.length;
}

/// A download that stopped with an error or was stopped, so it can be retried.
bool isFailedTrack(OfflineTrack track) =>
    !track.isReady &&
    !track.isActive &&
    (track.status == 'failed' || track.status == 'stopped');

/// Formats a byte count for display, for example "512 B", "2 KB" or "1.4 GB".
String formatBytes(int bytes) {
  const kb = 1024;
  const mb = kb * 1024;
  const gb = mb * 1024;
  if (bytes >= gb) return '${(bytes / gb).toStringAsFixed(1)} GB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(0)} KB';
  return '$bytes B';
}
