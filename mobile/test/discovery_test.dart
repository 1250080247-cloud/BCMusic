import 'dart:async';

import 'package:bcmusic/discovery.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeDiscoveryRepository implements DiscoveryRepository {
  final requests = <String, Completer<List<DiscoverySong>>>{};
  @override
  Future<List<DiscoverySong>> feed(String query, String order) =>
      (requests['$query/$order'] = Completer()).future;
  @override
  Future<List<DiscoverySong>> search(String query) =>
      (requests['search/$query'] = Completer()).future;
  @override
  void dispose() {}
}

void main() {
  test('parses valid YouTube rows and rejects foreign/invalid source IDs', () {
    final songs = DiscoverySong.parseItems({
      'items': [
        {
          'id': 'M7lc1UVf-VE',
          'title': 'A &amp; B',
          'artist': 'Artist',
          'durationSeconds': 42,
        },
        {'id': '../file', 'title': 'bad'},
        {'id': 'https://evil.test', 'title': 'bad'},
      ],
    });
    expect(songs.single.title, 'A & B');
    expect(
      songs.single.sourceUrl,
      'https://www.youtube.com/watch?v=M7lc1UVf-VE',
    );
    expect(songs.single.durationMs, 42000);
  });

  test('late search cannot overwrite newer query', () async {
    final repo = FakeDiscoveryRepository();
    final controller = DiscoveryController(repo);
    final first = controller.search('old');
    final second = controller.search('new');
    repo.requests['search/new']!.complete([
      const DiscoverySong(id: 'M7lc1UVf-VE', title: 'New', artist: ''),
    ]);
    await second;
    repo.requests['search/old']!.complete([]);
    await first;
    expect(controller.searchResults.single.title, 'New');
    controller.dispose();
  });

  test(
    'feed sections finish independently and preserve successful results',
    () async {
      final repo = FakeDiscoveryRepository();
      final controller = DiscoveryController(repo);
      final loading = controller.selectGenre(0);
      repo.requests['tiktok remix trending/relevance']!.complete([]);
      repo.requests['tiktok remix/viewCount']!.complete([
        const DiscoverySong(id: 'M7lc1UVf-VE', title: 'Available', artist: ''),
      ]);
      repo.requests['tiktok remix/date']!.completeError(
        const DiscoveryFailure('Không có kết nối.'),
      );
      await loading;
      expect(controller.sections[1].songs.single.title, 'Available');
      expect(controller.sections[2].error, isNotNull);
      expect(controller.sections.every((section) => !section.loading), isTrue);
      controller.dispose();
    },
  );

  test('WebsiteDiscoveryRepository uses defaultWebsiteHost and allows custom host', () {
    expect(WebsiteDiscoveryRepository.defaultWebsiteHost, 'bc-music-gilt.vercel.app');
    final custom = WebsiteDiscoveryRepository(host: 'staging.bcmusic.test');
    expect(custom.host, 'staging.bcmusic.test');
    custom.dispose();
  });
}
