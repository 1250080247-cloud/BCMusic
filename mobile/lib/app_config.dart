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
