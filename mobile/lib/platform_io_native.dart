import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class JsonClient {
  JsonClient(this._connectionTimeout)
    : _client = (HttpClient()..connectionTimeout = _connectionTimeout);

  final Duration _connectionTimeout;
  final HttpClient _client;

  Future<Map<String, dynamic>?> get(
    Uri uri, {
    required Duration responseTimeout,
    Duration? bodyTimeout,
    required int maxBytes,
    Map<String, String> headers = const {},
  }) async {
    HttpClientRequest? request;
    try {
      final connect = responseTimeout < _connectionTimeout
          ? responseTimeout
          : _connectionTimeout;
      request = await _client.getUrl(uri).timeout(connect);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      headers.forEach(request.headers.set);
      final response = await request.close().timeout(responseTimeout);
      if (response.statusCode != 200) {
        request.abort();
        return null;
      }

      final bytes = <int>[];
      await for (final chunk in response.timeout(bodyTimeout ?? responseTimeout)) {
        if (bytes.length + chunk.length > maxBytes) {
          throw PlatformException(code: 'response_too_large');
        }
        bytes.addAll(chunk);
      }
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, dynamic>) throw const FormatException();
      return json;
    } on SocketException {
      request?.abort();
      throw PlatformException(code: 'offline');
    } catch (_) {
      request?.abort();
      rethrow;
    }
  }

  void close() => _client.close(force: true);
}

File _lyricsFile(String trackId) {
  final key = trackId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  return File('${Directory.systemTemp.path}/bcmusic_lyrics/$key.json');
}

Future<String?> readLyricsFile(String trackId) async {
  final file = _lyricsFile(trackId);
  return await file.exists() ? file.readAsString() : null;
}

Future<void> writeLyricsFile(String trackId, String data) async {
  final file = _lyricsFile(trackId);
  await file.parent.create(recursive: true);
  await file.writeAsString(data, flush: true);
}

Widget? localArtwork(
  String? path, {
  double? size,
  required ImageErrorWidgetBuilder errorBuilder,
}) {
  if (path == null || path.isEmpty) return null;
  return Image.file(
    File(path),
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: errorBuilder,
  );
}
