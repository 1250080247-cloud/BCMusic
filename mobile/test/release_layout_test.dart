import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/app_shell.dart';
import 'package:bcmusic/discovery.dart';
import 'package:bcmusic/main.dart';
import 'package:bcmusic/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'controller_test.dart' show FakeMusicPlatform;
import 'home_screen_test.dart' show EmptyDiscoveryRepository;

void main() {
  for (final light in [false, true]) {
    for (final size in [
      const Size(375, 812),
      const Size(812, 375),
      const Size(800, 1100),
    ]) {
      testWidgets('1.2 navigation with large text, light=$light, size=$size', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final platform = FakeMusicPlatform()
          ..state = LibrarySnapshot(
            preferences: AppPreferences(light: light, motion: false),
          );
        final controller = MusicController(platform);
        await controller.initialize();
        final discovery = DiscoveryController(EmptyDiscoveryRepository());
        await tester.pumpWidget(
          BCMusicApp(
            controller: controller,
            discovery: discovery,
            textScaler: const TextScaler.linear(2),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in [
          'Tìm kiếm',
          'Thư viện',
          'Playlist',
          'SoundCloud',
        ]) {
          await tester.tap(
            find.descendant(
              of: find.byType(GlassNavigationBar),
              matching: find.text(label),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
        }
        await tester.tap(find.byTooltip('Cài đặt'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
        discovery.dispose();
        await platform.updates.close();
      });
    }
  }
}
