import 'dart:async';

import 'package:bcmusic/account_screen.dart';
import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/main.dart';
import 'package:bcmusic/models.dart';
import 'package:bcmusic/discovery.dart';
import 'package:bcmusic/discovery_screen.dart';
import 'package:bcmusic/home_screen.dart';
import 'package:bcmusic/platform_bridge.dart';
import 'package:bcmusic/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'controller_test.dart' show FakeMusicPlatform, sample;

class EmptyDiscoveryRepository implements DiscoveryRepository {
  EmptyDiscoveryRepository({this.songs = const []});

  final List<DiscoverySong> songs;

  @override
  Future<List<DiscoverySong>> feed(String query, String order) async => songs;
  @override
  Future<List<DiscoverySong>> search(String query) async => [];
  @override
  void dispose() {}
}

class _SuggestedSearchRepository extends EmptyDiscoveryRepository
    implements SearchSuggestions {
  @override
  Future<List<String>> suggestions(String query) async => ['$query remix'];
}

class _AccountPlaylistPlatform extends AndroidMusicPlatform {
  final local = const LocalPlaylist(
    id: 'offline',
    name: 'Danh sách offline',
    trackIds: [],
  );
  final played = <String>[];
  final favorites = <String>{};
  Map<String, String>? lastFavorite;
  final updates = StreamController<LibrarySnapshot>.broadcast();

  @override
  Stream<LibrarySnapshot> get events => updates.stream;

  @override
  Future<LibrarySnapshot> getState() async => LibrarySnapshot(
    account: const AccountProfile(
      name: 'Người nghe nhạc',
      username: 'listener',
    ),
    playlists: [local],
  );

  @override
  Future<String?> getProfileCollections() async => '''
    {"playlists":[{"id":"account","name":"Danh sách tài khoản","songs":[
      {"id":"M7lc1UVf-VE","title":"Bài trong playlist tài khoản"}
    ]}]}
  ''';

  @override
  Future<void> playSource(String url, {bool autoTransition = false}) async => played.add(url);

  @override
  Future<List<String>> getFavoriteIds() async => favorites.toList();

  @override
  Future<void> setFavorite(
    String accountId,
    Map<String, String> song,
    bool liked,
  ) async {
    expect(accountId, 'listener');
    lastFavorite = song;
    if (liked) {
      favorites.add(song['id']!);
    } else {
      favorites.remove(song['id']);
    }
  }
}

void main() {
  testWidgets('search suggestions submit a query and history can be reused', (
    tester,
  ) async {
    final discovery = DiscoveryController(_SuggestedSearchRepository());
    addTearDown(discovery.dispose);
    final history = <String>['Nhạc cũ'];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListenableBuilder(
            listenable: discovery,
            builder: (context, _) => SearchScreen(
              controller: discovery,
              history: history,
              onRecordSearch: (query) => history.insert(0, query),
              onTrackAction: (_, _) {},
              onSong: (_, _) {},
              onPlay: (_, _) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Lịch sử tìm kiếm'), findsOneWidget);
    expect(find.text('Nhạc cũ'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Nhạc mới');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nhạc mới remix'));
    await tester.pumpAndSettle();
    expect(discovery.query, 'Nhạc mới remix');
    await tester.tap(find.byTooltip('Xóa từ khóa'));
    await tester.pumpAndSettle();
    expect(find.text('Nhạc mới remix'), findsOneWidget);
  });

  test('account favorite uses the same YouTube ID as the web app', () async {
    final platform = _AccountPlaylistPlatform();
    final controller = MusicController(platform);
    addTearDown(platform.updates.close);
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(await controller.toggleLiked(sample), isTrue);
    expect(platform.lastFavorite?['id'], 'M7lc1UVf-VE');
    expect(platform.lastFavorite?['sourceUrl'], sample.sourceUrl);
    expect(controller.isLiked(sample), isTrue);

    await controller.refreshFavorites();
    expect(controller.isLiked(sample), isTrue);
    expect(await controller.toggleLiked(sample), isTrue);
    expect(platform.favorites, isEmpty);
    expect(controller.isLiked(sample), isFalse);
  });

  testWidgets('playlist tab shows account and offline playlists', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final platform = _AccountPlaylistPlatform();
    final controller = MusicController(platform);
    await controller.initialize();
    final discovery = DiscoveryController(EmptyDiscoveryRepository());
    addTearDown(platform.updates.close);
    addTearDown(controller.dispose);
    addTearDown(discovery.dispose);
    await tester.pumpWidget(
      BCMusicApp(controller: controller, discovery: discovery),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Playlist'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Danh sách offline'), findsOneWidget);
    expect(find.text('Danh sách tài khoản'), findsOneWidget);
    await tester.tap(find.text('Danh sách tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bài trong playlist tài khoản'));
    await tester.pumpAndSettle();
    expect(platform.played, [sample.sourceUrl]);
    await tester.pageBack();
    await tester.pumpAndSettle();

    platform.updates.add(LibrarySnapshot(playlists: [platform.local]));
    await tester.pumpAndSettle();
    expect(find.text('Danh sách tài khoản'), findsNothing);
    expect(find.text('Danh sách offline'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('feed menu downloads the selected song into the library', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final platform = FakeMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();
    final discovery = DiscoveryController(
      EmptyDiscoveryRepository(
        songs: const [
          DiscoverySong(id: 'M7lc1UVf-VE', title: 'Bài thử', artist: 'Nghệ sĩ'),
        ],
      ),
    );
    await tester.pumpWidget(
      BCMusicApp(controller: controller, discovery: discovery),
    );
    await tester.pumpAndSettle();
    final menu = find.descendant(
      of: find.byWidgetPredicate(
        (widget) => widget is FeedRows && widget.ranked,
      ),
      matching: find.byTooltip('Tùy chọn Bài thử'),
    );
    await tester.scrollUntilVisible(
      menu,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(find.text('Tải xuống'), findsOneWidget);
    await tester.tap(find.text('Tải xuống'));
    await tester.pump();
    platform.pending[sample.sourceUrl]!.complete(sample);
    await tester.pumpAndSettle();
    expect(find.text('Thư viện offline'), findsOneWidget);
    expect(platform.enqueued, [sample.id]);
    expect(platform.playedSources, isEmpty);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    discovery.dispose();
    await platform.updates.close();
  });

  testWidgets('feed shows five rows and scrolls to the tenth', (tester) async {
    final songs = List.generate(
      12,
      (index) => DiscoverySong(
        id: 'song$index',
        title: 'Bài ${index + 1}',
        artist: 'BCMusic',
      ),
    );
    List<DiscoverySong>? playedQueue;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeedRows(
            section: FeedSection(songs: songs, loading: false),
            ranked: true,
            onPlay: (_, queue) => playedQueue = queue,
            onRetry: () {},
          ),
        ),
      ),
    );
    final list = find.byType(ListView);
    expect(find.text('Bài 5').hitTestable(), findsOneWidget);
    expect(find.text('Bài 6').hitTestable(), findsNothing);
    await tester.scrollUntilVisible(find.text('Bài 10'), 190);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bài 10'));
    expect(playedQueue, hasLength(10));
    expect(find.text('Bài 11'), findsNothing);
    expect(tester.getSize(list).height, lessThan(400));
  });

  testWidgets('signed-in account menu opens the current profile', (
    tester,
  ) async {
    final platform = FakeMusicPlatform()
      ..state = const LibrarySnapshot(
        account: AccountProfile(name: 'Người nghe nhạc', username: 'listener'),
      );
    final controller = MusicController(platform);
    await controller.initialize();
    final discovery = DiscoveryController(EmptyDiscoveryRepository());
    await tester.pumpWidget(
      BCMusicApp(controller: controller, discovery: discovery),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Tài khoản'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hồ sơ'));
    await tester.pumpAndSettle();
    expect(find.text('@listener'), findsOneWidget);
    expect(find.text('Đăng nhập BCMusic'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('@listener'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    discovery.dispose();
    await platform.updates.close();
  });

  testWidgets('empty library explains offline use and accepts a link', (
    tester,
  ) async {
    final platform = FakeMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();
    final discovery = DiscoveryController(EmptyDiscoveryRepository());
    await tester.pumpWidget(
      BCMusicApp(controller: controller, discovery: discovery),
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Chạm cảm xúc', findRichText: true),
      findsOneWidget,
    );
    await tester.tap(find.text('Thư viện'));
    await tester.pumpAndSettle();
    expect(find.text('BCMusic'), findsOneWidget);
    expect(find.text('Chưa có bài đã tải'), findsOneWidget);
    await tester.tap(find.text('Thêm bài'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'https://evil.test/audio');
    await tester.tap(find.text('Xem thông tin bài'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Chỉ hỗ trợ'), findsOneWidget);
    expect(platform.pending, isEmpty);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    discovery.dispose();
    await platform.updates.close();
  });

  testWidgets('small screen with large text has no layout overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final platform = FakeMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();
    final discovery = DiscoveryController(EmptyDiscoveryRepository());
    await tester.pumpWidget(
      BCMusicApp(
        controller: controller,
        discovery: discovery,
        textScaler: const TextScaler.linear(1.5),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Thư viện'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Tất cả'),
      160,
      scrollable: find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      ).first,
    );
    final all = tester.getCenter(find.text('Tất cả'));
    final downloaded = tester.getCenter(find.text('Đã tải'));
    final listened = tester.getCenter(find.text('Đã nghe'));
    final pending = tester.getCenter(find.text('Đang tải / lỗi'));
    expect([downloaded.dy, listened.dy, pending.dy], everyElement(all.dy));
    expect(downloaded.dx, lessThan(listened.dx));
    expect(listened.dx, lessThan(pending.dx));
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
    discovery.dispose();
    await platform.updates.close();
  });

  testWidgets(
    'one account menu opens both forms and settings stays available',
    (tester) async {
      final platform = FakeMusicPlatform();
      final controller = MusicController(platform);
      await controller.initialize();
      final discovery = DiscoveryController(EmptyDiscoveryRepository());
      await tester.pumpWidget(
        BCMusicApp(controller: controller, discovery: discovery),
      );
      await tester.pumpAndSettle();

      expect(find.text('Đăng nhập'), findsNothing);
      expect(find.text('Đăng ký'), findsNothing);
      await tester.tap(find.byTooltip('Tài khoản'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng nhập BCMusic'), findsOneWidget);
      expect(find.text('Tên đăng nhập'), findsOneWidget);
      final fields = find.descendant(
        of: find.byType(AccountScreen),
        matching: find.byType(EditableText),
      );
      expect(
        tester.widget<EditableText>(fields.first).controller.text,
        const String.fromEnvironment('BCMUSIC_LOGIN_USERNAME'),
      );
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Tài khoản'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng ký'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng ký BCMusic'), findsOneWidget);
      expect(find.text('Tên hiển thị'), findsOneWidget);
      expect(
        tester.widget<EditableText>(fields.at(1)).controller.text,
        isEmpty,
      );
      await tester.tap(find.byTooltip('Đóng'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Cài đặt'));
      await tester.pumpAndSettle();
      expect(find.text('Tốc độ phát'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Giao diện sáng'),
        100,
        scrollable: find.descendant(
          of: find.byType(SettingsScreen),
          matching: find.byType(Scrollable),
        ).first,
      );
      expect(find.text('Giao diện sáng'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      discovery.dispose();
      await platform.updates.close();
    },
  );
}
