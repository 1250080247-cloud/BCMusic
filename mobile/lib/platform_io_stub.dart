import 'package:flutter/material.dart';

class JsonClient {
  JsonClient(Duration connectionTimeout);

  Future<Map<String, dynamic>?> get(
    Uri uri, {
    required Duration responseTimeout,
    Duration? bodyTimeout,
    required int maxBytes,
    Map<String, String> headers = const {},
  }) async => null;

  void close() {}
}

Future<String?> readLyricsFile(String trackId) async => null;
Future<void> writeLyricsFile(String trackId, String data) async {}

Widget? localArtwork(
  String? path, {
  double? size,
  required ImageErrorWidgetBuilder errorBuilder,
}) => null;
