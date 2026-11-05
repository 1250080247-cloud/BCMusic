import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_controller.dart';
import 'app_shell.dart';
import 'app_theme.dart';
import 'discovery.dart';
import 'platform_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString(
      'assets/licenses/NewPipeExtractor-GPL-3.0.txt',
    );
    yield LicenseEntryWithLineBreaks(['NewPipeExtractor'], text);
  });
  final controller = MusicController(AndroidMusicPlatform());
  final discovery = DiscoveryController(WebsiteDiscoveryRepository());
  unawaited(controller.initialize());
  runApp(BCMusicApp(controller: controller, discovery: discovery));
}

class BCMusicApp extends StatelessWidget {
  const BCMusicApp({
    super.key,
    required this.controller,
    required this.discovery,
    this.textScaler,
    this.phonePreview = false,
  });
  final MusicController controller;
  final DiscoveryController discovery;
  final TextScaler? textScaler;
  final bool phonePreview;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: controller.lightTheme,
    builder: (context, light, child) => MaterialApp(
      title: 'BCMusic',
      debugShowCheckedModeBanner: false,
      theme: bcmusicTheme(light: light),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final scaler = textScaler ?? media.textScaler;
        if (!phonePreview || media.size.width <= 460) {
          return MediaQuery(
            data: media.copyWith(textScaler: scaler),
            child: child!,
          );
        }
        final width = (media.size.height * .474).clamp(320.0, 440.0).toDouble();
        return ColoredBox(
          color: const Color(0xff08090d),
          child: Center(
            child: SizedBox(
              width: width,
              height: media.size.height,
              child: ClipRect(
                child: MediaQuery(
                  data: media.copyWith(
                    size: Size(width, media.size.height),
                    textScaler: scaler,
                  ),
                  child: child!,
                ),
              ),
            ),
          ),
        );
      },
      home: AppShell(controller: controller, discovery: discovery),
    ),
  );
}
