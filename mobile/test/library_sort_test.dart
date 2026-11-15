import 'package:bcmusic/library_sort.dart';
import 'package:bcmusic/models.dart';
import 'package:flutter_test/flutter_test.dart';

OfflineTrack _track(String id, String title, String artist, int bytes) =>
    OfflineTrack(
      id: id,
      title: title,
      artist: artist,
      sourceUrl: 'https://youtu.be/dQw4w9WgXcQ',
      provider: 'youtube',
      status: 'completed',
      bytes: bytes,
    );

void main() {
  final tracks = [
    _track('1', 'Chuyến đi', 'Zed', 300),
    _track('2', 'anh', 'an', 100),
    _track('3', 'Bầu trời', 'Bob', 300),
    _track('4', 'Cánh đồng', 'an', 200),
  ];

  List<String> idsSortedBy(LibrarySort sort) => [
    for (final track in sortLibraryTracks(tracks, sort)) track.id,
  ];

  test('recent keeps the order the library reports', () {
    expect(idsSortedBy(LibrarySort.recent), ['1', '2', '3', '4']);
  });

  test('title sorts ignoring case and Vietnamese tone marks', () {
    expect(idsSortedBy(LibrarySort.title), ['2', '3', '4', '1']);
    expect(foldForSort('Chuyến Đi'), 'chuyen di');
  });

  test('artist sorts by name and keeps equal artists in their original order', () {
    expect(idsSortedBy(LibrarySort.artist), ['2', '4', '3', '1']);
  });

  test('size puts the largest first and keeps equal sizes in their original order', () {
    expect(idsSortedBy(LibrarySort.size), ['1', '3', '4', '2']);
  });

  test('every sort option has a label for the menu', () {
    for (final sort in LibrarySort.values) {
      expect(sort.label, isNotEmpty);
    }
  });
}
