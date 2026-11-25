class BCMusicConfig {
  const BCMusicConfig._();

  static const String defaultWebsiteOrigin = String.fromEnvironment(
    'BCMUSIC_WEBSITE_URL',
    defaultValue: 'https://bc-music-gilt.vercel.app',
  );

  static const String defaultWebsiteHost = String.fromEnvironment(
    'BCMUSIC_BACKEND_HOST',
    defaultValue: 'bc-music-gilt.vercel.app',
  );

  /// Phiên bản app đang chạy. Phải khớp với `version` trong pubspec.yaml;
  /// test/config_test.dart kiểm tra điều này.
  static const String appVersion = '1.3.2';

  /// Repo GitHub phát hành APK. Mỗi bản phát hành là một GitHub Release có
  /// tag dạng vX.Y.Z và file .apk đính kèm.
  static const String releaseRepo = String.fromEnvironment(
    'BCMUSIC_RELEASE_REPO',
    defaultValue: '1250080247-cloud/BCMusic',
  );

  static const String userAgent = 'BCMusic/$appVersion (Android)';

  static Uri get latestReleaseUri => Uri.https(
    'api.github.com',
    '/repos/$releaseRepo/releases/latest',
  );

  static String get websiteOrigin {
    final origin = defaultWebsiteOrigin.trim();
    if (origin.endsWith('/')) {
      return origin.substring(0, origin.length - 1);
    }
    return origin;
  }

  static String get websiteHost {
    final parsed = Uri.tryParse(websiteOrigin);
    if (parsed != null && parsed.host.isNotEmpty) {
      return parsed.host;
    }
    return defaultWebsiteHost;
  }

  static Uri websiteUri(String path, [Map<String, dynamic>? queryParameters]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse(websiteOrigin);
    return Uri(
      scheme: base.scheme.isNotEmpty ? base.scheme : 'https',
      host: websiteHost,
      port: base.hasPort ? base.port : null,
      path: normalizedPath,
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value?.toString()),
      ),
    );
  }
}
