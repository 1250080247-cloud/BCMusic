import 'dart:convert';

import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/app_shell.dart';
import 'package:bcmusic/app_theme.dart';
import 'package:bcmusic/discovery.dart';
import 'package:bcmusic/lyrics.dart';
import 'package:bcmusic/models.dart';
import 'package:bcmusic/player_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_screen_test.dart' show EmptyDiscoveryRepository;
import 'support/fake_music_platform.dart';

class _CachedLyricsPlatform extends FakeMusicPlatform {
  final Map<String, String> cachedLyrics = {};

  @override
  Future<String?> getLyrics(String trackId) async => cachedLyrics[trackId];
}

void main() {
  const track1 = OfflineTrack(
    id: 'track-1',
    title: 'Đêm Trăng',
    artist: 'Ca Sĩ A',
    sourceUrl: 'https://www.youtube.com/watch?v=song1111111',
    provider: 'youtube',
    status: 'ready',
  );
  const track2 = OfflineTrack(
    id: 'track-2',
    title: 'Mưa Chiều',
    artist: 'Ca Sĩ B',
    sourceUrl: 'https://www.youtube.com/watch?v=song2222222',
    provider: 'youtube',
    status: 'ready',
  );

  Future<void> tapNavTab(WidgetTester tester, String label) => tester.tap(
    find.descendant(
      of: find.byType(GlassNavigationBar),
      matching: find.text(label),
    ),
  );

  testWidgets(
    'AppShell preserves IndexedStack state and handles rapid tab switching',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final platform = FakeMusicPlatform()
        ..state = const LibrarySnapshot(
          preferences: AppPreferences(motion: false),
        );
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

      // Enter text in the Search tab to verify IndexedStack keeps tab state.
      await tapNavTab(tester, 'Tìm kiếm');
      await tester.pumpAndSettle();
      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'lofi chill');
      await tester.pump();

      // Rapidly switch across tabs mid-animation.
      for (final label in [
        'Thư viện',
        'Playlist',
        'SoundCloud',
        'Trang chủ',
        'Tìm kiếm',
      ]) {
        await tapNavTab(tester, label);
        await tester.pump(const Duration(milliseconds: 40));
      }
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final indexedStack = tester.widget<IndexedStack>(
        find.byType(IndexedStack),
      );
      expect(indexedStack.index, 1);
      expect(find.text('lofi chill'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      discovery.dispose();
      await platform.updates.close();
    },
  );

  testWidgets(
    'AppShell respects MediaQuery.disableAnimations for tabs and mini-player',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final platform = FakeMusicPlatform()
        ..state = const LibrarySnapshot(
          preferences: AppPreferences(motion: false),
        );
      final controller = MusicController(platform);
      await controller.initialize();
      final discovery = DiscoveryController(EmptyDiscoveryRepository());

      await tester.pumpWidget(
        MaterialApp(
          theme: bcmusicTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: AppShell(controller: controller, discovery: discovery),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PlayerControls), findsNothing);

      // Switch tab with disableAnimations: true.
      await tapNavTab(tester, 'Thư viện');
      await tester.pump();
      expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 2);

      // Show mini-player immediately without waiting for animation duration.
      platform.updates.add(
        const LibrarySnapshot(
          tracks: [track1],
          playback: PlaybackState(
            trackId: 'track-1',
            isPlaying: true,
            positionMs: 12000,
            durationMs: 180000,
            offline: true,
            track: track1,
          ),
          preferences: AppPreferences(motion: false),
        ),
      );
      await tester.pump();
      expect(find.byType(PlayerControls), findsOneWidget);

      // Hide mini-player again.
      platform.updates.add(
        const LibrarySnapshot(
          tracks: [track1],
          playback: PlaybackState(),
          preferences: AppPreferences(motion: false),
        ),
      );
      await tester.pump();
      expect(find.byType(PlayerControls), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      discovery.dispose();
      await platform.updates.close();
    },
  );

  testWidgets(
    'Mini-player AnimatedSwitcher rapid toggle keeps Hero tag unique on open',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final platform = _CachedLyricsPlatform()
        ..state = const LibrarySnapshot(
          tracks: [track1, track2],
          preferences: AppPreferences(motion: false),
        );
      final cachedLyricsJson = jsonEncode(
        const LyricsData(
          status: 'synced',
          source: 'BCMusic Cache',
          lines: [
            LyricLine(timeMs: 1000, text: 'Dòng lời đầu tiên'),
            LyricLine(timeMs: 8000, text: 'Dòng lời thứ hai'),
          ],
        ).toMap(),
      );
      platform.cachedLyrics['track-1'] = cachedLyricsJson;
      platform.cachedLyrics['track-2'] = cachedLyricsJson;
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

      // Appear -> mid-animation disappear -> immediate re-appear while
      // previous mini-player is still reversing out.
      platform.updates.add(
        const LibrarySnapshot(
          tracks: [track1, track2],
          playback: PlaybackState(
            trackId: 'track-1',
            isPlaying: true,
            positionMs: 5000,
            durationMs: 180000,
            offline: true,
            track: track1,
          ),
          preferences: AppPreferences(motion: false),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));

      platform.updates.add(
        const LibrarySnapshot(
          tracks: [track1, track2],
          playback: PlaybackState(),
          preferences: AppPreferences(motion: false),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 30));

      platform.updates.add(
        const LibrarySnapshot(
          tracks: [track1, track2],
          playback: PlaybackState(
            trackId: 'track-2',
            isPlaying: true,
            positionMs: 3000,
            durationMs: 190000,
            offline: true,
            track: track2,
          ),
          preferences: AppPreferences(motion: false),
        ),
      );
      // Build incoming mini-player, then advance 100ms (~83% expanded via
      // easeOutCubic) while outgoing mini-player is still within its 180ms
      // reverse window.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Open Now Playing even while previous mini-player is still animating out.
      await tester.tap(
        find.descendant(
          of: find.byType(PlayerControls),
          matching: find.text('Mưa Chiều'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Thu nhỏ trình phát'), findsOneWidget);

      await tester.tap(find.byTooltip('Thu nhỏ trình phát'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      discovery.dispose();
      await platform.updates.close();
    },
  );

  testWidgets(
    'Now Playing container transform, trio panel switcher, and safe _panel != 0 close',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1100);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final platform = _CachedLyricsPlatform()
        ..state = const LibrarySnapshot(
          tracks: [track1, track2],
          playback: PlaybackState(
            trackId: 'track-1',
            isPlaying: true,
            positionMs: 10000,
            durationMs: 200000,
            offline: true,
            track: track1,
          ),
          preferences: AppPreferences(motion: false),
        );
      platform.cachedLyrics['track-1'] = jsonEncode(
        const LyricsData(
          status: 'synced',
          source: 'BCMusic Cache',
          lines: [
            LyricLine(timeMs: 2000, text: 'Dòng lời đầu tiên'),
            LyricLine(timeMs: 12000, text: 'Dòng lời thứ hai'),
          ],
        ).toMap(),
      );
      final controller = MusicController(platform);
      await controller.initialize();

      await tester.pumpWidget(
        MaterialApp(
          theme: bcmusicTheme(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: PlayerControls(
                  controller: controller,
                  onAddToPlaylist: (_) {},
                  onDownload: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Open Now Playing and verify container expands from bottom card rect.
      await tester.tap(find.text('Đêm Trăng').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final openingBox = tester.widget<Positioned>(
        find
            .ancestor(
              of: find.byTooltip('Thu nhỏ trình phát'),
              matching: find.byType(Positioned),
            )
            .first,
      );
      expect(openingBox.top, greaterThan(0));
      expect(openingBox.height, lessThan(1100));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Thu nhỏ trình phát'), findsOneWidget);

      // Verify closing collapses back toward the mini-player rect immediately.
      await tester.tap(find.byTooltip('Thu nhỏ trình phát'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 65));
      final closingBox = tester.widget<Positioned>(
        find
            .ancestor(
              of: find.byTooltip('Thu nhỏ trình phát'),
              matching: find.byType(Positioned),
            )
            .first,
      );
      expect(closingBox.top, greaterThan(200));
      expect(closingBox.height, lessThan(850));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Thu nhỏ trình phát'), findsNothing);

      // Re-open for panel checks.
      await tester.tap(find.text('Đêm Trăng').first);
      await tester.pumpAndSettle();

      // 2. Switch to panel 1 ('Tiếp theo') and close while _panel == 1.
      await tester.tap(find.text('Tiếp theo'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(find.text('ĐANG PHÁT'), findsOneWidget);

      await tester.tap(find.byTooltip('Thu nhỏ trình phát'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Thu nhỏ trình phát'), findsNothing);

      // 3. Re-open, switch to panel 2 ('Lời bài hát'), and close while _panel == 2.
      await tester.tap(find.text('Đêm Trăng').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lời bài hát'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Thu nhỏ trình phát'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Thu nhỏ trình phát'), findsNothing);

      // 4. Re-open, rapidly toggle panels 0 -> 1 -> 2 -> 0, and close from _panel == 0.
      await tester.tap(find.text('Đêm Trăng').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiếp theo'));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.text('Lời bài hát'));
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.text('Đang phát').last);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.tap(find.byTooltip('Thu nhỏ trình phát'));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // 5. Open, switch panels, and close with disableAnimations: true.
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: bcmusicTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Scaffold(
            body: PlayerControls(
              controller: controller,
              onAddToPlaylist: (_) {},
              onDownload: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Đêm Trăng'));
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Thu nhỏ trình phát'), findsOneWidget);

      await tester.tap(find.text('Tiếp theo'));
      await tester.pump();
      expect(find.text('ĐANG PHÁT'), findsOneWidget);

      await tester.tap(find.byTooltip('Thu nhỏ trình phát'));
      await tester.pump();
      await tester.pump();
      expect(find.byTooltip('Thu nhỏ trình phát'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      await platform.updates.close();
    },
  );

  testWidgets(
    'bcmusicTheme pageTransitionsTheme uses opaque backdrop and honors disableAnimations',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: bcmusicTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                        body: Center(child: Text('Detail Page')),
                      ),
                    ),
                  ),
                  child: const Text('Open Detail'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Detail'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Detail Page'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox && widget.color == AppPalette.dark.background,
        ),
        findsAtLeastNWidgets(1),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Verify disableAnimations bypasses route transition.
      await tester.pumpWidget(
        MaterialApp(
          key: UniqueKey(),
          theme: bcmusicTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(
                        body: Center(child: Text('Instant Detail')),
                      ),
                    ),
                  ),
                  child: const Text('Open Instant'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Instant'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Instant Detail'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
