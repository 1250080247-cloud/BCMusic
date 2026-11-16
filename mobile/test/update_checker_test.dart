import 'dart:convert';
import 'dart:io';

import 'package:bcmusic/app_config.dart';
import 'package:bcmusic/update_checker.dart';
import 'package:flutter_test/flutter_test.dart';

/// Payload GitHub returned for the v1.3.0 release (trimmed to the fields used).
const _githubReleaseV130 = r'''
{"tag_name":"v1.3.0","target_commitish":"main","name":"BCMusic 1.3.0",
"body":"Fix web preview, fix nav overflow","draft":false,"prerelease":false,
"published_at":"2026-11-13T08:31:43Z",
"html_url":"https://github.com/1250080247-cloud/BCMusic/releases/tag/v1.3.0",
"assets":[{"name":"bcmusic-v1.3.0-arm64.apk","state":"uploaded",
"content_type":"application/vnd.android.package-archive","size":20787204,
"browser_download_url":"https://github.com/1250080247-cloud/BCMusic/releases/download/v1.3.0/bcmusic-v1.3.0-arm64.apk"}]}
''';

Map<String, dynamic> _release({
  String tag = 'v1.3.1',
  bool draft = false,
  bool prerelease = false,
  Object? body = 'Sửa lỗi kiểm tra cập nhật.',
  Object? publishedAt = '2026-11-20T12:00:00Z',
  List<Map<String, dynamic>> assets = const [],
}) => {
  'tag_name': tag,
  'draft': draft,
  'prerelease': prerelease,
  'body': body,
  'published_at': publishedAt,
  'html_url': 'https://github.com/1250080247-cloud/BCMusic/releases/tag/$tag',
  'assets': assets,
};

Map<String, dynamic> _apk(String name) => {
  'name': name,
  'browser_download_url':
      'https://github.com/1250080247-cloud/BCMusic/releases/download/v1.3.1/$name',
};

void main() {
  group('compareVersions', () {
    test('orders dotted versions numerically, not as text', () {
      expect(compareVersions('1.3.1', '1.3.0'), greaterThan(0));
      expect(compareVersions('1.10.0', '1.9.0'), greaterThan(0));
      expect(compareVersions('1.2.9', '1.3.0'), lessThan(0));
      expect(compareVersions('1.3.0', '1.3.0'), 0);
      expect(compareVersions('1.3', '1.3.0'), 0);
    });
  });

  group('parseLatestRelease', () {
    test('uses the HTTPS release page when the APK link is unsafe', () {
      final json = _release(assets: [
        {'name': 'bcmusic-arm64.apk', 'browser_download_url': 'http://example.org/app.apk'},
        {'name': 'bcmusic.apk', 'browser_download_url': 'https://user@example.org/app.apk'},
      ]);
      final update = parseLatestRelease(json, currentVersion: '1.3.0');
      expect(update?.downloadUrl, json['html_url']);
    });

    test('reads the payload GitHub returns for the real v1.3.0 release', () {
      final json = jsonDecode(_githubReleaseV130) as Map<String, dynamic>;

      final update = parseLatestRelease(json, currentVersion: '1.2.9');
      expect(update, isNotNull);
      expect(update!.version, '1.3.0');
      expect(update.date, '13/11/2026');
      expect(update.changelog, 'Fix web preview, fix nav overflow');
      expect(
        update.downloadUrl,
        'https://github.com/1250080247-cloud/BCMusic/releases/download/v1.3.0/bcmusic-v1.3.0-arm64.apk',
      );

      expect(parseLatestRelease(json, currentVersion: '1.3.0'), isNull);
    });

    test('returns a newer release with its APK, date and notes', () {
      final update = parseLatestRelease(
        _release(assets: [_apk('bcmusic-v1.3.1-arm64.apk')]),
        currentVersion: '1.3.0',
      );
      expect(update, isNotNull);
      expect(update!.version, '1.3.1');
      expect(update.date, '20/11/2026');
      expect(update.changelog, 'Sửa lỗi kiểm tra cập nhật.');
      expect(
        update.downloadUrl,
        'https://github.com/1250080247-cloud/BCMusic/releases/download/v1.3.1/bcmusic-v1.3.1-arm64.apk',
      );
    });

    test('compares numerically, so 1.10.0 is newer than 1.9.0', () {
      expect(
        parseLatestRelease(_release(tag: 'v1.10.0'), currentVersion: '1.9.0'),
        isNotNull,
      );
    });

    test('returns null when the release is the same or older', () {
      expect(
        parseLatestRelease(_release(tag: 'v1.3.0'), currentVersion: '1.3.0'),
        isNull,
      );
      expect(
        parseLatestRelease(_release(tag: 'v1.2.9'), currentVersion: '1.3.0'),
        isNull,
      );
    });

    test('ignores drafts and pre-releases', () {
      expect(
        parseLatestRelease(_release(draft: true), currentVersion: '1.3.0'),
        isNull,
      );
      expect(
        parseLatestRelease(_release(prerelease: true), currentVersion: '1.3.0'),
        isNull,
      );
    });

    test('accepts a tag without the v prefix and rejects non-version tags', () {
      expect(
        parseLatestRelease(_release(tag: '1.3.1'), currentVersion: '1.3.0')
            ?.version,
        '1.3.1',
      );
      expect(
        parseLatestRelease(_release(tag: 'latest'), currentVersion: '1.3.0'),
        isNull,
      );
      expect(
        parseLatestRelease(_release(tag: 'v1.3.1-beta'), currentVersion: '1.3.0'),
        isNull,
      );
      expect(
        parseLatestRelease(<String, dynamic>{}, currentVersion: '1.3.0'),
        isNull,
      );
    });

    test('prefers the arm64 APK, then any APK, then the release page', () {
      final arm = parseLatestRelease(
        _release(
          assets: [
            _apk('bcmusic-v1.3.1-x86_64.apk'),
            _apk('bcmusic-v1.3.1-arm64.apk'),
          ],
        ),
        currentVersion: '1.3.0',
      );
      expect(arm!.downloadUrl, endsWith('bcmusic-v1.3.1-arm64.apk'));

      final anyApk = parseLatestRelease(
        _release(
          assets: [
            {
              'name': 'notes.txt',
              'browser_download_url': 'https://example.test/notes.txt',
            },
            _apk('app-release.apk'),
          ],
        ),
        currentVersion: '1.3.0',
      );
      expect(anyApk!.downloadUrl, endsWith('app-release.apk'));

      final releasePage = parseLatestRelease(
        _release(
          assets: [
            {
              'name': 'source.zip',
              'browser_download_url': 'https://example.test/source.zip',
            },
          ],
        ),
        currentVersion: '1.3.0',
      );
      expect(
        releasePage!.downloadUrl,
        'https://github.com/1250080247-cloud/BCMusic/releases/tag/v1.3.1',
      );
    });

    test('tolerates missing or malformed optional fields', () {
      final update = parseLatestRelease(
        _release(body: null, publishedAt: 'not a date'),
        currentVersion: '1.3.0',
      );
      expect(update, isNotNull);
      expect(update!.changelog, '');
      expect(update.date, '');

      final numericBody = parseLatestRelease(
        _release(body: 42),
        currentVersion: '1.3.0',
      );
      expect(numericBody!.changelog, '');
    });

    test('shortens very long release notes', () {
      final update = parseLatestRelease(
        _release(body: 'a' * 1000),
        currentVersion: '1.3.0',
      );
      expect(update!.changelog.length, lessThanOrEqualTo(601));
      expect(update.changelog, endsWith('…'));
    });
  });

  group('checkForUpdate over HTTP', () {
    late HttpServer server;
    late Uri uri;

    setUp(() async {
      // flutter_test replaces the HTTP stack by default; use real sockets here.
      HttpOverrides.global = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      uri = Uri.http(
        '127.0.0.1:${server.port}',
        '/repos/owner/repo/releases/latest',
      );
    });

    tearDown(() => server.close(force: true));

    void serve(
      int status,
      String body, {
      void Function(HttpRequest request)? onRequest,
    }) {
      server.listen((request) async {
        onRequest?.call(request);
        request.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(body);
        await request.response.close();
      });
    }

    test('returns the newer release and sends the headers GitHub expects', () async {
      String? userAgent;
      String? accept;
      serve(
        200,
        jsonEncode(_release(assets: [_apk('bcmusic-v1.3.1-arm64.apk')])),
        onRequest: (request) {
          userAgent = request.headers.value(HttpHeaders.userAgentHeader);
          accept = request.headers.value(HttpHeaders.acceptHeader);
        },
      );

      final update = await checkForUpdate(uri: uri, currentVersion: '1.3.0');
      expect(update?.version, '1.3.1');
      expect(userAgent, BCMusicConfig.userAgent);
      expect(accept, 'application/vnd.github+json');
    });

    test('returns null when GitHub answers without a release', () async {
      serve(404, '{"message":"Not Found"}');
      expect(
        await checkForUpdate(uri: uri, currentVersion: '1.3.0'),
        isNull,
      );
    });

    test('returns null when the response is not a JSON object', () async {
      serve(200, '["not", "an", "object"]');
      expect(
        await checkForUpdate(uri: uri, currentVersion: '1.3.0'),
        isNull,
      );
    });
  });
}
