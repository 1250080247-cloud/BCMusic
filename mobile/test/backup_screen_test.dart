import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/app_theme.dart';
import 'package:bcmusic/backup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_music_platform.dart';

const _backup = '''
{"format":"bcmusic.playlists","version":1,"exportedAt":"2026-11-15T09:00:00.000Z",
"playlists":[{"name":"Buổi sáng","tracks":[
  {"title":"Một","artist":"A","sourceUrl":"https://www.youtube.com/watch?v=dQw4w9WgXcQ"},
  {"title":"Hai","artist":"B","sourceUrl":"https://www.youtube.com/watch?v=M7lc1UVf-VE"}
]}]}''';

void main() {
  testWidgets('explains why pasted text cannot be restored', (tester) async {
    final controller = MusicController(FakeMusicPlatform());
    await controller.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: bcmusicTheme(light: false),
        home: PlaylistBackupScreen(controller: controller),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'không phải bản sao lưu');
    await tester.pump();
    await tester.tap(find.text('Xem trước'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nội dung không phải là bản sao lưu hợp lệ.'),
      findsOneWidget,
    );
  });

  testWidgets('previews a backup, restores it and reports the result', (tester) async {
    // The preview and the restore button need more room than the default 800x600.
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MusicController(FakeMusicPlatform());
    await controller.initialize();
    final created = <String>[];
    final added = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: bcmusicTheme(light: false),
        home: PlaylistBackupScreen(
          controller: controller,
          createPlaylist: (name) async {
            created.add(name);
            return 'id_$name';
          },
          addTrack: (playlistId, url) async {
            added.add('$playlistId ${url.split('=').last}');
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), _backup);
    await tester.pump();
    await tester.tap(find.text('Xem trước'));
    await tester.pumpAndSettle();
    expect(find.text('Sẽ khôi phục 1 playlist, 2 bài'), findsOneWidget);

    await tester.tap(find.text('Bắt đầu khôi phục'));
    await tester.pumpAndSettle();

    expect(created, ['Buổi sáng']);
    expect(added, [
      'id_Buổi sáng dQw4w9WgXcQ',
      'id_Buổi sáng M7lc1UVf-VE',
    ]);
    expect(find.text('Đã tạo 1 playlist, thêm 2 bài.'), findsOneWidget);
  });
}
