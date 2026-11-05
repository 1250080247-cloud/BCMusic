import 'package:bcmusic/account_screen.dart';
import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/main.dart';
import 'package:bcmusic/models.dart';
import 'package:bcmusic/discovery.dart';
import 'package:bcmusic/discovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'controller_test.dart' show FakeMusicPlatform;

class EmptyDiscoveryRepository implements DiscoveryRepository {
  @override
  Future<List<DiscoverySong>> feed(String query, String order) async => [];
  @override
  Future<List<DiscoverySong>> search(String query) async => [];
  @override
  void dispose() {}
}

void main() {
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
            onSong: (_, _) {},
            onPlay: (_, queue) => playedQueue = queue,
            onRetry: () {},
          ),
        ),
      ),
    );
    final list = find.byType(ListView);
    expect(find.byTooltip('Phát Bài 5').hitTestable(), findsOneWidget);
    expect(find.byTooltip('Phát Bài 6').hitTestable(), findsNothing);
    await tester.scrollUntilVisible(find.text('Bài 10'), 190);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Phát Bài 10'));
    expect(playedQueue, hasLength(10));
    expect(find.byTooltip('Phát Bài 11'), findsNothing);
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
    await tester.tap(find.text('Đóng'));
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
      expect(find.text('Giao diện sáng'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      discovery.dispose();
      await platform.updates.close();
    },
  );
}
