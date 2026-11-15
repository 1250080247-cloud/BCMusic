import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/app_theme.dart';
import 'package:bcmusic/downloads_screen.dart';
import 'package:bcmusic/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_music_platform.dart';

OfflineTrack _track(
  String id, {
  String title = 'Bài',
  int bytes = 0,
  String status = 'completed',
  String? error,
}) => OfflineTrack(
  id: id,
  title: title,
  artist: 'Ca sĩ',
  sourceUrl: 'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
  provider: 'youtube',
  status: status,
  bytes: bytes,
  error: error,
);

void main() {
  testWidgets('lists downloads largest first and deletes the selected ones after confirmation', (tester) async {
    final platform = FakeMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();
    platform.updates.add(
      LibrarySnapshot(
        tracks: [
          _track('small', title: 'Nhỏ', bytes: 2 * 1024 * 1024),
          _track('big', title: 'Lớn', bytes: 9 * 1024 * 1024),
          _track('busy', title: 'Đang tải', status: 'downloading'),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: bcmusicTheme(light: false),
        home: DownloadsScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('11.0 MB'), findsOneWidget);
    expect(find.text('2 bài đã tải · 1 đang tải · 0 lỗi'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Lớn')).dy,
      lessThan(tester.getTopLeft(find.text('Nhỏ')).dy),
    );

    await tester.tap(find.text('Nhỏ'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa đã chọn (1)'), findsOneWidget);

    await tester.tap(find.text('Xóa đã chọn (1)'));
    await tester.pumpAndSettle();
    expect(find.text('Xóa 1 bản đã tải?'), findsOneWidget);

    await tester.tap(find.widgetWithText(TextButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(platform.removed, ['small']);
  });

  testWidgets('shows an empty state and retries failed downloads', (tester) async {
    final platform = FakeMusicPlatform();
    final controller = MusicController(platform);
    await controller.initialize();
    platform.updates.add(
      LibrarySnapshot(
        tracks: [
          _track('oops', title: 'Lỗi', status: 'failed', error: 'Mất mạng'),
        ],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: bcmusicTheme(light: false),
        home: DownloadsScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Chưa có bài nào được tải về máy.'), findsOneWidget);
    expect(find.text('Mất mạng'), findsOneWidget);

    await tester.tap(find.text('Thử lại 1 bản lỗi'));
    await tester.pumpAndSettle();
    expect(platform.retried, ['oops']);
  });
}
