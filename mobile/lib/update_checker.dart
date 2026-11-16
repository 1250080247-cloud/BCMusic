import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'app_config.dart';
import 'platform_io.dart';

const _maxResponseBytes = 256 * 1024;
const _maxChangelogChars = 600;
final _versionTag = RegExp(r'^[vV]?(\d+(?:\.\d+)*)$');

class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.date,
    this.changelog = '',
    this.downloadUrl = '',
  });
  final String version, date, changelog, downloadUrl;
}

/// Asks GitHub for the latest published release of the app. Returns null when
/// the app is up to date, when the check cannot finish (offline, rate limited,
/// unexpected response), or on web.
Future<AppUpdate?> checkForUpdate({
  Uri? uri,
  String currentVersion = BCMusicConfig.appVersion,
}) async {
  if (kIsWeb) return null;

  final client = JsonClient(const Duration(seconds: 10));
  try {
    final json = await client.get(
      uri ?? BCMusicConfig.latestReleaseUri,
      responseTimeout: const Duration(seconds: 15),
      bodyTimeout: const Duration(seconds: 10),
      maxBytes: _maxResponseBytes,
      headers: const {
        'accept': 'application/vnd.github+json',
        'user-agent': BCMusicConfig.userAgent,
        'X-GitHub-Api-Version': '2022-11-28',
      },
    );
    return json == null ? null : parseLatestRelease(json, currentVersion: currentVersion);
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

/// Turns the JSON of `GET /repos/{repo}/releases/latest` into an [AppUpdate]
/// when its tag is newer than [currentVersion]. Drafts and pre-releases are
/// ignored.
AppUpdate? parseLatestRelease(
  Map<String, dynamic> json, {
  required String currentVersion,
}) {
  if (json['draft'] == true || json['prerelease'] == true) return null;
  final tag = (_string(json['tag_name']) ?? '').trim();
  final match = _versionTag.firstMatch(tag);
  if (match == null) return null;
  final latest = match.group(1)!;
  if (compareVersions(latest, currentVersion) <= 0) return null;
  return AppUpdate(
    version: latest,
    date: _formatDate(_string(json['published_at'])),
    changelog: _trimChangelog(_string(json['body'])),
    downloadUrl: _downloadUrl(json),
  );
}

/// Compares dotted version numbers such as `1.10.0`. Returns a negative
/// number, zero or a positive number when [a] is older, equal or newer than [b].
int compareVersions(String a, String b) {
  final pa = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final pb = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return 0;
}

String? _string(Object? value) => value is String ? value : null;

String _formatDate(String? iso) {
  final parsed = DateTime.tryParse(iso ?? '');
  if (parsed == null) return '';
  final local = parsed.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  return '$day/$month/${local.year}';
}

String _trimChangelog(String? body) {
  final text = (body ?? '').trim();
  if (text.length <= _maxChangelogChars) return text;
  return '${text.substring(0, _maxChangelogChars).trimRight()}…';
}

/// Prefers the arm64 APK, then any other APK, and falls back to the release
/// page when the release has no APK attached.
String _downloadUrl(Map<String, dynamic> json) {
  String? firstApk;
  final assets = json['assets'];
  if (assets is List) {
    for (final asset in assets) {
      if (asset is! Map<String, dynamic>) continue;
      final name = (_string(asset['name']) ?? '').toLowerCase();
      final url = _httpsUrl(asset['browser_download_url']);
      if (!name.endsWith('.apk') || url.isEmpty) continue;
      if (name.contains('arm64')) return url;
      firstApk ??= url;
    }
  }
  return firstApk ?? _httpsUrl(json['html_url']);
}

String _httpsUrl(Object? value) {
  final uri = Uri.tryParse(_string(value) ?? '');
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return '';
  }
  return uri.toString();
}

Future<void> showUpdateDialog(
  BuildContext context,
  AppUpdate update, {
  VoidCallback? onDownload,
}) => showDialog<void>(
  context: context,
  builder: (context) => AlertDialog(
    title: const Text(
      'Phiên bản mới có sẵn',
      style: TextStyle(fontWeight: FontWeight.w700),
    ),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Phiên bản v${update.version} có sẵn',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (update.date.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Xuất bản ngày: ${update.date}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (update.changelog.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Có gì mới',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(update.changelog, style: const TextStyle(height: 1.5)),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Huỷ'),
      ),
      if (onDownload != null)
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onDownload();
          },
          child: const Text('Tải xuống'),
        ),
    ],
  ),
);
