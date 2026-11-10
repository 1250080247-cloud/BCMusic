import 'package:flutter_test/flutter_test.dart';
import 'package:bcmusic/lyrics.dart';

void main() {
  group('Lyrics parser and cleaner tests', () {
    test('cleanSongTitle removes MV, official, audio and extra tags', () {
      expect(
        cleanSongTitle('Sơn Tùng M-TP - CHÚNG TA CỦA HIỆN TẠI | OFFICIAL MUSIC VIDEO'),
        'CHÚNG TA CỦA HIỆN TẠI',
      );
      expect(
        cleanSongTitle('Alan Walker - Faded (Official Lyric Video)'),
        'Faded',
      );
      expect(
        cleanSongTitle('Vũ. - Bước Qua Nhau [MV] [4K Remastered]'),
        'Bước Qua Nhau',
      );
    });

    test('cleanArtist removes - Topic and VEVO suffixes', () {
      expect(cleanArtist('SonTung-Topic'), 'SonTung');
      expect(cleanArtist('TaylorSwiftVEVO'), 'TaylorSwift');
      expect(cleanArtist('Den Vau '), 'Den Vau');
    });

    test('parseLrc correctly parses standard LRC timestamps and lines', () {
      const lrc = '''
[00:12.50]Dòng đầu tiên
[00:15.80]Dòng thứ hai
[01:02.100]Dòng thứ ba sau một phút
''';
      final lines = parseLrc(lrc);
      expect(lines.length, 3);
      expect(lines[0].timeMs, 12500);
      expect(lines[0].text, 'Dòng đầu tiên');
      expect(lines[1].timeMs, 15800);
      expect(lines[1].text, 'Dòng thứ hai');
      expect(lines[2].timeMs, 62100);
      expect(lines[2].text, 'Dòng thứ ba sau một phút');
    });

    test('parseLrc handles empty and corrupted LRC text gracefully', () {
      expect(parseLrc(null), isEmpty);
      expect(parseLrc('   '), isEmpty);
      expect(parseLrc('[invalid:timestamp] Không có giờ'), isEmpty);
    });

    test('activeLyricIndex finds current lyric based on playback position', () {
      final lines = [
        const LyricLine(timeMs: 5000, text: 'Câu 1'),
        const LyricLine(timeMs: 10000, text: 'Câu 2'),
        const LyricLine(timeMs: 20000, text: 'Câu 3'),
      ];

      expect(activeLyricIndex(lines, 3000), -1); // Trước câu 1
      expect(activeLyricIndex(lines, 5000), 0);  // Đúng câu 1
      expect(activeLyricIndex(lines, 8000), 0);  // Giữa câu 1 và câu 2
      expect(activeLyricIndex(lines, 10000), 1); // Bắt đầu câu 2
      expect(activeLyricIndex(lines, 15000), 1); // Giữa câu 2 và câu 3
      expect(activeLyricIndex(lines, 25000), 2); // Sau câu 3
    });
  });
}
