import 'package:bcmusic/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('canonicalizes a shared YouTube short link without tracking', () {
    final link = SourceLink.parse(
      'Bài hay https://youtu.be/M7lc1UVf-VE?si=tracking',
    );
    expect(link.url, 'https://www.youtube.com/watch?v=M7lc1UVf-VE');
  });

  test('accepts SoundCloud track and short links', () {
    expect(
      SourceLink.parse('https://soundcloud.com/artist/track?in=list').provider,
      'soundcloud',
    );
    expect(
      SourceLink.parse('https://on.soundcloud.com/abc123').provider,
      'soundcloud',
    );
    final playlist = SourceLink.parse('https://soundcloud.com/artist/sets/album');
    expect(playlist.provider, 'soundcloud');
    expect(playlist.isPlaylist, isTrue);
  });

  test('rejects unsupported, ambiguous and deceptive URLs', () {
    for (final value in [
      '',
      'file:///secret',
      'https://youtube.com.evil.test/watch?v=M7lc1UVf-VE',
      'https://evil.test/?url=https://youtube.com/watch?v=M7lc1UVf-VE',
      'https://youtube.com/playlist?list=123',
      'https://user@youtube.com/watch?v=M7lc1UVf-VE',
      'https://youtu.be/M7lc1UVf-VE https://soundcloud.com/artist/track',
    ]) {
      expect(
        () => SourceLink.parse(value),
        throwsFormatException,
        reason: value,
      );
    }
  });

  test('offline readiness requires a completed download', () {
    final track = OfflineTrack.fromMap({
      'id': 'youtube_M7lc1UVf-VE',
      'title': 'Bài thử',
      'artist': '',
      'sourceUrl': 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
      'provider': 'youtube',
      'status': 'downloading',
      'progress': -1,
      'bytes': 100,
      'durationMs': 0,
    });
    expect(track.isReady, isFalse);
    expect(track.progress, isNull);
    expect(
      OfflineTrack.fromMap({...track.toMap(), 'status': 'completed'}).isReady,
      isTrue,
    );
  });
}
