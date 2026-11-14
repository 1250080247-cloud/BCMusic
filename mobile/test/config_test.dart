import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bcmusic/app_config.dart';
import 'package:bcmusic/discovery.dart';
import 'package:bcmusic/models.dart';

void main() {
  group('BCMusicConfig centralized Base URL tests', () {
    test('defaultWebsiteOrigin and defaultWebsiteHost match production Vercel deployment', () {
      expect(BCMusicConfig.defaultWebsiteOrigin, 'https://bc-music-gilt.vercel.app');
      expect(BCMusicConfig.defaultWebsiteHost, 'bc-music-gilt.vercel.app');
      expect(BCMusicConfig.websiteOrigin, 'https://bc-music-gilt.vercel.app');
      expect(BCMusicConfig.websiteHost, 'bc-music-gilt.vercel.app');
    });

    test('websiteUri creates correct HTTPS URI with path and query parameters', () {
      final uriWithoutSlash = BCMusicConfig.websiteUri('api/lyrics', {'title': 'Test Song'});
      expect(uriWithoutSlash.scheme, 'https');
      expect(uriWithoutSlash.host, 'bc-music-gilt.vercel.app');
      expect(uriWithoutSlash.path, '/api/lyrics');
      expect(uriWithoutSlash.queryParameters['title'], 'Test Song');

      final uriWithSlash = BCMusicConfig.websiteUri('/api/search', {'q': 'Sơn Tùng'});
      expect(uriWithSlash.toString(), 'https://bc-music-gilt.vercel.app/api/search?q=S%C6%A1n+T%C3%B9ng');
    });

    test('discovery repository uses BCMusicConfig.websiteHost by default', () {
      final repo = WebsiteDiscoveryRepository();
      expect(repo.host, BCMusicConfig.websiteHost);
      repo.dispose();
    });

    test('AccountProfile avatarUri builds URI from BCMusicConfig', () {
      const profile = AccountProfile(
        id: '662b667210e75553e19eb45a',
        name: 'Tester',
        username: 'tester',
        avatarVersion: '2',
      );
      final avatarUri = profile.avatarUri;
      expect(avatarUri, isNotNull);
      expect(avatarUri!.host, BCMusicConfig.websiteHost);
      expect(avatarUri.path, '/api/user/avatar');
      expect(avatarUri.queryParameters['userId'], '662b667210e75553e19eb45a');
      expect(avatarUri.queryParameters['v'], '2');
    });
  });

  group('BCMusicConfig app version and update source', () {
    test('appVersion matches the version declared in pubspec.yaml', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final match = RegExp(
        r'^version:\s*([0-9.]+)\+',
        multiLine: true,
      ).firstMatch(pubspec);
      expect(match, isNotNull);
      expect(BCMusicConfig.appVersion, match!.group(1));
    });

    test('update check reads the latest GitHub release of the BCMusic repo', () {
      expect(
        BCMusicConfig.latestReleaseUri.toString(),
        'https://api.github.com/repos/1250080247-cloud/BCMusic/releases/latest',
      );
      expect(
        BCMusicConfig.userAgent,
        'BCMusic/${BCMusicConfig.appVersion} (Android)',
      );
    });
  });
}
