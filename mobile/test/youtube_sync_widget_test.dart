import 'dart:async';
import 'dart:convert';

import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/app_shell.dart';
import 'package:bcmusic/app_theme.dart';
import 'package:bcmusic/discovery.dart';
import 'package:bcmusic/models.dart';
import 'package:bcmusic/platform_bridge.dart';
import 'package:bcmusic/playlist_screen.dart';
import 'package:bcmusic/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_screen_test.dart' show EmptyDiscoveryRepository;

class _YouTubeMockPlatform extends AndroidMusicPlatform {
  final updates = StreamController<LibrarySnapshot>.broadcast(sync: true);
  LibrarySnapshot state = const LibrarySnapshot(
    account: AccountProfile(
      id: '507f1f77bcf86cd799439011',
      name: 'An Nguyễn',
      username: 'an.nguyen',
    ),
    preferences: AppPreferences(motion: false),
  );

  bool available = true;
  bool connected = true;
  bool needsReconnect = false;
  int syncCalls = 0;
  int disconnectCalls = 0;
  int connectCalls = 0;
  final createdPlaylists = <String>[];
  final enqueuedUrls = <String>[];

  static const sampleSongs = [
    {
      'id': 'M7lc1UVf-VE',
      'title': 'Chìm Sâu',
      'artist': 'RPT MCK',
      'sourceUrl': 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
      'thumbnail': 'https://i.ytimg.com/vi/M7lc1UVf-VE/hqdefault.jpg',
      'durationSeconds': 156,
    },
    {
      'id': 'dQw4w9WgXcQ',
      'title': 'Nàng Thơ',
      'artist': 'Hoàng Dũng',
      'sourceUrl': 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      'thumbnail': 'https://i.ytimg.com/vi/dQw4w9WgXcQ/hqdefault.jpg',
      'durationSeconds': 254,
    },
  ];

  @override
  Stream<LibrarySnapshot> get events => updates.stream;

  @override
  Future<LibrarySnapshot> getState() async => state;

  @override
  Future<String?> getYouTubeStatus() async => jsonEncode({
    'available': available,
    'connected': connected,
    'needsReconnect': needsReconnect,
    'lastSyncedAt': connected ? '2026-11-25T10:00:00.000Z' : null,
    'likedCount': connected ? 2 : 0,
    'playlistCount': connected ? 1 : 0,
  });

  @override
  Future<void> startYouTubeConnect() async {
    connectCalls++;
    connected = true;
    needsReconnect = false;
  }

  @override
  Future<String?> syncYouTube() async {
    syncCalls++;
    return jsonEncode({
      'success': true,
      'available': available,
      'connected': connected,
      'needsReconnect': needsReconnect,
      'lastSyncedAt': '2026-11-25T11:30:00.000Z',
      'likedCount': 2,
      'playlistCount': 1,
    });
  }

  @override
  Future<String?> disconnectYouTube() async {
    disconnectCalls++;
    connected = false;
    needsReconnect = false;
    return jsonEncode({
      'success': true,
      'available': available,
      'connected': false,
      'needsReconnect': false,
      'lastSyncedAt': null,
      'likedCount': 0,
      'playlistCount': 0,
    });
  }

  @override
  Future<String?> getYouTubeForYou() async => jsonEncode({
    'connected': connected,
    'needsReconnect': needsReconnect,
    'sections': [
      {
        'id': 'liked',
        'eyebrow': 'YÊU THÍCH CỦA BẠN',
        'title': 'Nhạc bạn đã thích',
        'items': sampleSongs,
      },
      {
        'id': 'taste',
        'eyebrow': 'DỰA TRÊN GU NGHE',
        'title': 'Hợp gu nghe gần đây',
        'items': [sampleSongs[1]],
      },
      {
        'id': 'subscribed',
        'eyebrow': 'KÊNH BẠN ĐĂNG KÝ',
        'title': 'Từ nghệ sĩ bạn theo dõi',
        'items': [sampleSongs[0]],
      },
    ],
  });

  @override
  Future<String?> getProfileCollections() async => jsonEncode({
    'favorites': [sampleSongs[0]],
    'playlists': [
      if (connected) ...[
        {
          'id': 'yt_liked',
          'name': 'Nhạc đã thích',
          'source': 'youtube',
          'isLiked': true,
          'readOnly': true,
          'songs': sampleSongs,
        },
        {
          'id': 'yt_pl_1',
          'name': 'Đêm muộn YouTube',
          'source': 'youtube',
          'isLiked': false,
          'readOnly': true,
          'songs': [sampleSongs[0]],
        },
      ],
      {
        'id': 'web_1',
        'name': 'Chill BCMusic',
        'source': 'bcmusic',
        'isLiked': false,
        'songs': [sampleSongs[1]],
      },
    ],
  });

  @override
  Future<LocalPlaylist> createNamedPlaylist(String name) async {
    createdPlaylists.add(name);
    return LocalPlaylist(id: 'local_${createdPlaylists.length}', name: name);
  }

  @override
  Future<void> enqueueAndAddToPlaylist(
    String playlistId,
    String id, {
    String? url,
  }) async {
    if (url != null) enqueuedUrls.add(url);
  }

  @override
  Future<void> playSource(String url, {bool autoTransition = false}) async {}

  @override
  Future<String?> getAppVersion() async => null;
}

void main() {
  testWidgets(
    'Home chip "Dành cho bạn" appears when YouTube connected, loads 3 sections, and disappears on disconnect',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final platform = _YouTubeMockPlatform();
      final controller = MusicController(platform);
      await controller.initialize();
      final discovery = DiscoveryController(EmptyDiscoveryRepository());

      await tester.pumpWidget(
        MaterialApp(
          theme: bcmusicTheme(),
          home: AppShell(controller: controller, discovery: discovery),
        ),
      );
      await tester.pumpAndSettle();

      // Chip 'Dành cho bạn' is present when connected.
      expect(find.text('Dành cho bạn'), findsOneWidget);

      // Selecting 'Dành cho bạn' and switching back across animated frames must not overflow ChoiceChip.
      await tester.tap(find.text('Dành cho bạn'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();
      expect(find.text('Nhạc bạn đã thích'), findsOneWidget);
      expect(find.text('Hợp gu nghe gần đây'), findsOneWidget);
      expect(find.text('YouTube'), findsNothing);
      expect(find.text('TỪ YOUTUBE CỦA BẠN'), findsNothing);

      // Switch back to a genre chip and back to 'Dành cho bạn' mid-animation to verify zero RenderFlex overflow.
      await tester.tap(find.text('TikTok Remix'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.text('Dành cho bạn'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 20));
        expect(tester.takeException(), isNull);
      }
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Từ nghệ sĩ bạn theo dõi'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Từ nghệ sĩ bạn theo dõi'), findsOneWidget);

      // Disconnecting removes the chip cleanly.
      await controller.disconnectYouTube();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Top thịnh hành'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Dành cho bạn'), findsNothing);
      expect(find.text('Top thịnh hành'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      discovery.dispose();
      await platform.updates.close();
    },
  );

  for (final light in [false, true]) {
    testWidgets(
      'Playlist tab keeps 2 sections, renders Ruby Dịu YouTube cards, and read-only detail hides remove action (light=$light)',
      (tester) async {
        tester.view.physicalSize = const Size(430, 932);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final platform = _YouTubeMockPlatform()
          ..state = LibrarySnapshot(
            account: const AccountProfile(
              id: '507f1f77bcf86cd799439011',
              name: 'An Nguyễn',
              username: 'an.nguyen',
            ),
            preferences: AppPreferences(light: light, motion: false),
          );
        final controller = MusicController(platform);
        await controller.initialize();

        await tester.pumpWidget(
          MaterialApp(
            theme: bcmusicTheme(light: light),
            home: Scaffold(
              body: PlaylistScreen(controller: controller, active: true),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only 2 section headings exist: Playlist tài khoản & Playlist offline.
        expect(find.text('Playlist tài khoản'), findsOneWidget);
        expect(find.text('Playlist offline'), findsOneWidget);
        expect(find.text('+ YouTube'), findsOneWidget);

        // Ruby Dịu cards for Liked Music (♥ YouTube) and YouTube playlist (▶ YouTube).
        expect(find.text('Nhạc đã thích'), findsOneWidget);
        expect(find.text('♥ YouTube'), findsOneWidget);
        expect(find.text('Đêm muộn YouTube'), findsOneWidget);
        expect(find.text('▶ YouTube'), findsOneWidget);
        expect(find.text('Chill BCMusic'), findsOneWidget);

        // Open YouTube playlist detail -> read-only mode.
        await tester.tap(find.text('Nhạc đã thích'));
        await tester.pumpAndSettle();

        expect(find.text('YouTube · Chỉ đọc'), findsOneWidget);
        expect(find.text('Phát tất cả'), findsOneWidget);
        expect(find.text('Trộn bài'), findsOneWidget);
        expect(find.text('Lưu thành Playlist offline'), findsOneWidget);

        // Open track action menu -> must NOT show 'Xóa khỏi playlist'.
        await tester.tap(find.byTooltip('Tùy chọn Chìm Sâu'));
        await tester.pumpAndSettle();
        expect(find.text('Xóa khỏi playlist'), findsNothing);
        Navigator.of(tester.element(find.text('Chia sẻ'))).pop();
        await tester.pumpAndSettle();

        // Save as offline playlist queues tracks cleanly.
        await tester.tap(find.text('Lưu thành Playlist offline'));
        await tester.pumpAndSettle();
        expect(platform.createdPlaylists, ['Nhạc đã thích']);
        expect(platform.enqueuedUrls.length, 2);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        await platform.updates.close();
      },
    );
  }

  testWidgets(
    'ProfileScreen YouTube Sync card covers not connected, connected, and expired states',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Not connected state.
      final platform = _YouTubeMockPlatform()
        ..available = true
        ..connected = false
        ..needsReconnect = false;
      final controller = MusicController(platform);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: bcmusicTheme(),
          home: ProfileScreen(controller: controller),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kết nối YouTube'), findsOneWidget);
      expect(find.text('Kết nối tài khoản YouTube'), findsOneWidget);

      // Connect -> transitions to Connected ('Đang bật') state.
      await tester.tap(find.text('Kết nối tài khoản YouTube'));
      await tester.pumpAndSettle();
      expect(platform.connectCalls, 1);
      expect(find.text('Đang bật'), findsOneWidget);
      expect(find.text('Đồng bộ ngay'), findsOneWidget);
      expect(find.text('Ngắt kết nối'), findsOneWidget);

      // Trigger manual sync.
      await tester.tap(find.text('Đồng bộ ngay'));
      await tester.pumpAndSettle();
      expect(platform.syncCalls, 1);

      // Disconnect -> returns to Not connected.
      await tester.tap(find.text('Ngắt kết nối'));
      await tester.pumpAndSettle();
      expect(platform.disconnectCalls, 1);
      expect(find.text('Kết nối tài khoản YouTube'), findsOneWidget);

      // 3. Expired state ('Cần kết nối lại').
      platform
        ..connected = false
        ..needsReconnect = true;
      await controller.refreshYouTubeStatus();
      await tester.pumpAndSettle();
      expect(find.text('Cần kết nối lại'), findsOneWidget);
      expect(find.text('Kết nối lại YouTube'), findsOneWidget);

      // 4. Hidden when server reports available=false.
      platform
        ..available = false
        ..connected = false
        ..needsReconnect = false;
      await controller.refreshYouTubeStatus();
      await tester.pumpAndSettle();
      expect(find.text('Kết nối YouTube'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await platform.updates.close();
    },
  );
}
