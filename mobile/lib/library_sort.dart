import 'models.dart';

/// Order of the offline library list.
enum LibrarySort {
  recent('Mới nhất'),
  title('Tên A–Z'),
  artist('Nghệ sĩ A–Z'),
  size('Dung lượng lớn nhất');

  const LibrarySort(this.label);
  final String label;
}

const _diacriticGroups = {
  'àáạảãâầấậẩẫăằắặẳẵ': 'a',
  'èéẹẻẽêềếệểễ': 'e',
  'ìíịỉĩ': 'i',
  'òóọỏõôồốộổỗơờớợởỡ': 'o',
  'ùúụủũưừứựửữ': 'u',
  'ỳýỵỷỹ': 'y',
  'đ': 'd',
};

final _foldedLetters = {
  for (final group in _diacriticGroups.entries)
    for (final letter in group.key.split('')) letter: group.value,
};

/// Lower-cases [text] and drops Vietnamese tone marks, so "Chuyến" sorts as
/// "chuyen" and sits between "bầu" and "cánh" in the same order as Latin text.
String foldForSort(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_foldedLetters[char] ?? char);
  }
  return buffer.toString();
}

/// Returns [tracks] in the requested order. Equal keys keep their original
/// order, and [LibrarySort.recent] keeps the order the library reports.
List<OfflineTrack> sortLibraryTracks(
  Iterable<OfflineTrack> tracks,
  LibrarySort sort,
) {
  final compare = switch (sort) {
    LibrarySort.recent => null,
    LibrarySort.title => (OfflineTrack a, OfflineTrack b) =>
        foldForSort(a.title).compareTo(foldForSort(b.title)),
    LibrarySort.artist => (OfflineTrack a, OfflineTrack b) =>
        foldForSort(a.artist).compareTo(foldForSort(b.artist)),
    LibrarySort.size => (OfflineTrack a, OfflineTrack b) =>
        b.bytes.compareTo(a.bytes),
  };
  final indexed = [for (final (index, track) in tracks.indexed) (index, track)];
  if (compare != null) {
    indexed.sort((x, y) {
      final result = compare(x.$2, y.$2);
      return result != 0 ? result : x.$1.compareTo(y.$1);
    });
  }
  return [for (final (_, track) in indexed) track];
}
