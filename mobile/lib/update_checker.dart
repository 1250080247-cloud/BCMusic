import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import 'app_config.dart';

const _currentVersion = '1.2.9';

class AppUpdate {
  const AppUpdate({
    required this.version,
    required this.date,
    this.changelog = '',
    this.downloadUrl = '',
  });
  final String version, date, changelog, downloadUrl;
}

Future<AppUpdate?> checkForUpdate() async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
  try {
    final uri = Uri.https(BCMusicConfig.websiteHost, '/api/version');
    final request = await client.getUrl(uri).timeout(
      const Duration(seconds: 10),
    );
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(
      const Duration(seconds: 15),
    );
    if (response.statusCode != 200) {
      request.abort();
      return null;
    }
    final bytes = <int>[];
    await for (final chunk in response.timeout(const Duration(seconds: 10))) {
      if (bytes.length + chunk.length > 64 * 1024) break;
      bytes.addAll(chunk);
    }
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! Map<String, dynamic>) return null;
    final latest = json['version'] as String?;
    if (latest == null || latest == _currentVersion) return null;
    if (_compareVersions(latest, _currentVersion) <= 0) return null;
    return AppUpdate(
      version: latest,
      date: (json['date'] as String?) ?? '',
      changelog: (json['changelog'] as String?) ?? '',
      downloadUrl: (json['downloadUrl'] as String?) ?? '',
    );
  } catch (_) {
    return null;
  } finally {
    client.close(force: true);
  }
}

int _compareVersions(String a, String b) {
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
