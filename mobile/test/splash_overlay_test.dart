import 'package:bcmusic/app_controller.dart';
import 'package:bcmusic/app_shell.dart';
import 'package:bcmusic/app_theme.dart';
import 'package:bcmusic/discovery.dart';
import 'package:bcmusic/models.dart';
import 'package:bcmusic/splash_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'home_screen_test.dart' show EmptyDiscoveryRepository;
import 'support/fake_music_platform.dart';

class _StatefulHomeProbe extends StatefulWidget {
  const _StatefulHomeProbe({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_StatefulHomeProbe> createState() => _StatefulHomeProbeState();
}

class _StatefulHomeProbeState extends State<_StatefulHomeProbe> {
  static int initCount = 0;

  @override
  void initState() {
    super.initState();
    initCount++;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: ElevatedButton(
        onPressed: widget.onTap,
        child: const Text('Home Action'),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'SplashOverlay shows crisp logo, Orbit Glow, blocks touches while active, and removes overlay cleanly on finish',
    (tester) async {
      _StatefulHomeProbeState.initCount = 0;
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: bcmusicTheme(),
          home: SplashOverlay(
            enabled: true,
            child: _StatefulHomeProbe(onTap: () => taps++),
          ),
        ),
      );

      // Step into Phase 1 + Orbit Glow + Phase 2 (~350ms).
      await tester.pump(const Duration(milliseconds: 350));

      // Crisp logo with FilterQuality.high, isAntiAlias, and gaplessPlayback.
      final logoFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Image &&
            widget.image is AssetImage &&
            (widget.image as AssetImage).assetName == 'assets/images/logo.png',
      );
      expect(logoFinder, findsOneWidget);
      final logoImage = tester.widget<Image>(logoFinder);
      expect(logoImage.filterQuality, FilterQuality.high);
      expect(logoImage.isAntiAlias, isTrue);
      expect(logoImage.gaplessPlayback, isTrue);

      // Brand title, subtitle, and vector Orbit Glow CustomPaint.
      expect(find.text('BCMusic.'), findsOneWidget);
      expect(find.text('ÂM NHẠC CHO RIÊNG BẠN'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SplashOverlay),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is CustomPaint &&
                widget.painter != null &&
                widget.size == const Size.square(114),
          ),
        ),
        findsOneWidget,
      );

      // Overlay absorbs pointer events while active.
      final absorbFinder = find.descendant(
        of: find.byType(SplashOverlay),
        matching: find.byWidgetPredicate(
          (widget) => widget is AbsorbPointer && widget.absorbing,
        ),
      );
      expect(absorbFinder, findsOneWidget);
      await tester.tap(find.text('Home Action'), warnIfMissed: false);
      await tester.pump();
      expect(taps, 0);

      // Finite animation completes cleanly via pumpAndSettle().
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Overlay and AbsorbPointer are completely removed after finish.
      expect(find.text('BCMusic.'), findsNothing);
      expect(find.text('ÂM NHẠC CHO RIÊNG BẠN'), findsNothing);
      expect(absorbFinder, findsNothing);

      // Child state was preserved (not re-initialized) and is now interactive.
      expect(_StatefulHomeProbeState.initCount, 1);
      await tester.tap(find.text('Home Action'));
      await tester.pump();
      expect(taps, 1);
    },
  );

  testWidgets(
    'SplashOverlay skips splash immediately when MediaQuery.disableAnimations is true',
    (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: bcmusicTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: SplashOverlay(
            enabled: true,
            child: _StatefulHomeProbe(onTap: () => taps++),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BCMusic.'), findsNothing);
      expect(find.text('ÂM NHẠC CHO RIÊNG BẠN'), findsNothing);
      expect(
        find.descendant(
          of: find.byType(SplashOverlay),
          matching: find.byWidgetPredicate(
            (widget) => widget is AbsorbPointer && widget.absorbing,
          ),
        ),
        findsNothing,
      );

      await tester.tap(find.text('Home Action'));
      await tester.pump();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SplashOverlay skips splash immediately when enabled is false',
    (tester) async {
      var taps = 0;

      await tester.pumpWidget(
        MaterialApp(
          theme: bcmusicTheme(),
          home: SplashOverlay(
            enabled: false,
            child: _StatefulHomeProbe(onTap: () => taps++),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('BCMusic.'), findsNothing);
      expect(find.text('ÂM NHẠC CHO RIÊNG BẠN'), findsNothing);
      await tester.tap(find.text('Home Action'));
      await tester.pump();
      expect(taps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  for (final light in [false, true]) {
    testWidgets(
      'SplashOverlay renders without overflow on 360x640 at textScaler 2.0 (light=$light)',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final expectedBg = light
            ? const Color(0xfff6f7fb)
            : const Color(0xff0b0b10);

        await tester.pumpWidget(
          MaterialApp(
            theme: bcmusicTheme(light: light),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2.0)),
              child: child!,
            ),
            home: SplashOverlay(
              enabled: true,
              child: _StatefulHomeProbe(onTap: () {}),
            ),
          ),
        );

        for (final stepMs in [0, 220, 330, 300]) {
          await tester.pump(Duration(milliseconds: stepMs));
          expect(tester.takeException(), isNull);
        }

        // Verify expected Dark (#0B0B10) / Light (#F6F7FB) splash backdrop while visible.
        expect(
          find.byWidgetPredicate(
            (widget) => widget is ColoredBox && widget.color == expectedBg,
          ),
          findsAtLeastNWidgets(1),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('BCMusic.'), findsNothing);
      },
    );
  }

  testWidgets(
    'AppShell header logo uses FilterQuality.high and isAntiAlias',
    (tester) async {
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

      final headerLogo = tester.widget<Image>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Image &&
              widget.image is AssetImage &&
              (widget.image as AssetImage).assetName ==
                  'assets/images/logo.png',
        ),
      );
      expect(headerLogo.filterQuality, FilterQuality.high);
      expect(headerLogo.isAntiAlias, isTrue);

      await tester.pumpWidget(const SizedBox());
      controller.dispose();
      discovery.dispose();
      await platform.updates.close();
    },
  );
}
