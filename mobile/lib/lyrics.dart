import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'app_config.dart';
import 'platform_bridge.dart';

class LyricLine {
  const LyricLine({required this.timeMs, required this.text});
  final int timeMs;
  final String text;

  Map<String, dynamic> toMap() => {'timeMs': timeMs, 'text': text};

  factory LyricLine.fromMap(Map<String, dynamic> map) => LyricLine(
        timeMs: (map['timeMs'] as num?)?.toInt() ?? 0,
        text: (map['text'] as String?) ?? '',
      );
}

class LyricsData {
  const LyricsData({
    required this.status,
    this.source,
    this.plainLyrics = '',
    this.lines = const [],
  });

  final String status;
  final String? source;
  final String plainLyrics;
  final List<LyricLine> lines;

  bool get isSynced => status == 'synced' && lines.isNotEmpty;
  bool get isInstrumental => status == 'instrumental';
  bool get hasLyrics => isSynced || plainLyrics.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'status': status,
        'source': source,
        'plainLyrics': plainLyrics,
        'lines': lines.map((line) => line.toMap()).toList(),
      };

  factory LyricsData.fromMap(Map<String, dynamic> map) => LyricsData(
        status: (map['status'] as String?) ?? 'unavailable',
        source: map['source'] as String?,
        plainLyrics: (map['plainLyrics'] as String?) ?? '',
        lines: ((map['lines'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => LyricLine.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );

  static const empty = LyricsData(status: 'unavailable');
}

String cleanSongTitle(String title) {
  var text = title.trim();
  final split = RegExp(r'^(.+?)\s[-–—]\s(.+)$').firstMatch(text);
  if (split != null) {
    text = split.group(2)!.trim();
  }
  text = text.replaceAll(
    RegExp(
      r'\s*[[(](?:official(?:\s+(?:music|lyric))?(?:\s+video)?|official\s+audio|lyrics?|lyric\s+video|music\s+video|mv|(?:hd|4k)(?:\s+remaster(?:ed)?)?|visualizer)[\])]\s*',
      caseSensitive: false,
    ),
    ' ',
  );
  text = text.replaceAll(
    RegExp(
      r'\s*(?:\||[-–—])\s*(?:official(?:\s+(?:music|lyric))?(?:\s+video)?|official\s+audio|lyrics?|lyric\s+video|music\s+video|mv|visualizer)\s*$',
      caseSensitive: false,
    ),
    '',
  );
  return text.replaceAll(RegExp(r'\s+'), ' ').trim();
}

String cleanArtist(String artist) {
  return artist
      .replaceAll(RegExp(r'\s*-\s*Topic$', caseSensitive: false), '')
      .replaceAll(RegExp(r'-Topic$', caseSensitive: false), '')
      .replaceAll(RegExp(r'VEVO$', caseSensitive: false), '')
      .trim();
}

List<LyricLine> parseLrc(String? lrc) {
  if (lrc == null || lrc.trim().isEmpty) return const [];
  final lines = <LyricLine>[];
  final regex = RegExp(r'^\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');

  for (final raw in lrc.split(RegExp(r'\r?\n')).take(1500)) {
    var remaining = raw.trim();
    final stamps = <int>[];
    Match? match;
    while ((match = regex.firstMatch(remaining)) != null) {
      final min = int.tryParse(match!.group(1)!) ?? 0;
      final sec = int.tryParse(match.group(2)!) ?? 0;
      final millisStr = match.group(3) ?? '0';
      final millis = (double.tryParse('0.$millisStr') ?? 0.0) * 1000;
      final totalMs = (min * 60 + sec) * 1000 + millis.round();
      stamps.add(totalMs);
      remaining = remaining.substring(match.group(0)!.length).trim();
    }
    for (final ms in stamps) {
      lines.add(LyricLine(timeMs: ms, text: remaining));
    }
  }

  lines.sort((a, b) => a.timeMs.compareTo(b.timeMs));
  return lines;
}

int activeLyricIndex(List<LyricLine> lines, int positionMs) {
  if (lines.isEmpty || positionMs < lines.first.timeMs) return -1;
  var low = 0;
  var high = lines.length - 1;
  while (low <= high) {
    final mid = (low + high) ~/ 2;
    if (lines[mid].timeMs <= positionMs) {
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return high;
}

class LyricsRepository {
  LyricsRepository({HttpClient? client, this.platform})
      : _client = client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 10));

  final HttpClient _client;
  final MusicPlatform? platform;
  final Map<String, LyricsData> _memoryCache = {};

  Future<LyricsData> getLyrics({
    required String trackId,
    required String rawTitle,
    required String rawArtist,
    int durationMs = 0,
    String? backendHost,
  }) async {
    final host = backendHost ?? BCMusicConfig.websiteHost;
    if (_memoryCache.containsKey(trackId)) {
      return _memoryCache[trackId]!;
    }

    if (platform != null) {
      try {
        final cached = await platform!.getLyrics(trackId);
        if (cached != null && cached.isNotEmpty) {
          final map = jsonDecode(cached) as Map<String, dynamic>;
          final data = LyricsData.fromMap(map);
          _memoryCache[trackId] = data;
          return data;
        }
      } catch (_) {}
    }

    final cached = await LyricsStore.load(trackId);
    if (cached != null) {
      _memoryCache[trackId] = cached;
      return cached;
    }

    final title = cleanSongTitle(rawTitle);
    final artist = cleanArtist(rawArtist);
    final durationSeconds = (durationMs / 1000).round();

    LyricsData result = LyricsData.empty;

    // 1. Thử gọi backend BCMusic Next.js (/api/lyrics)
    try {
      final uri = Uri.https(host, '/api/lyrics', {
        'title': title,
        'artist': artist,
        if (durationSeconds > 0) 'duration': durationSeconds.toString(),
      });
      final req = await _client.getUrl(uri).timeout(const Duration(seconds: 8));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final body = await res.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final status = json['status'] as String? ?? 'unavailable';
        if (status != 'unavailable') {
          final lines = ((json['lines'] as List?) ?? [])
              .whereType<Map>()
              .map((row) => LyricLine(
                    timeMs: (((row['time'] as num?)?.toDouble() ?? 0.0) * 1000).round(),
                    text: (row['text'] as String?)?.trim() ?? '',
                  ))
              .toList();
          result = LyricsData(
            status: status,
            source: json['source'] as String? ?? 'BCMusic',
            plainLyrics: (json['plainLyrics'] as String?)?.trim() ?? '',
            lines: lines,
          );
        }
      }
    } catch (_) {
      // Backend có thể không khả dụng hoặc offline
    }

    // 2. Dự phòng trực tiếp từ LRCLIB nếu backend chưa có kết quả
    if (!result.hasLyrics && !result.isInstrumental) {
      try {
        final uri = Uri.https('lrclib.net', '/api/get', {
          'track_name': title,
          'artist_name': artist,
          if (durationSeconds > 0) 'duration': durationSeconds.toString(),
        });
        final req = await _client.getUrl(uri).timeout(const Duration(seconds: 6));
        req.headers.set('Lrclib-Client', 'BCMusic/1.3.0 (Android)');
        req.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final res = await req.close().timeout(const Duration(seconds: 6));
        if (res.statusCode == 200) {
          final body = await res.transform(utf8.decoder).join();
          final json = jsonDecode(body) as Map<String, dynamic>;
          if (json['instrumental'] == true) {
            result = const LyricsData(status: 'instrumental', source: 'LRCLIB');
          } else {
            final synced = json['syncedLyrics'] as String?;
            final plain = json['plainLyrics'] as String?;
            final lines = parseLrc(synced);
            result = LyricsData(
              status: lines.isNotEmpty ? 'synced' : (plain != null && plain.isNotEmpty ? 'plain' : 'unavailable'),
              source: 'LRCLIB',
              plainLyrics: plain ?? '',
              lines: lines,
            );
          }
        }
      } catch (_) {}
    }

    if (result.hasLyrics || result.isInstrumental) {
      _memoryCache[trackId] = result;
      if (platform != null) {
        unawaited(platform!.saveLyrics(trackId, jsonEncode(result.toMap())));
      }
      unawaited(LyricsStore.save(trackId, result));
    }

    return result;
  }

  void dispose() {
    _client.close(force: true);
  }
}

class LyricsStore {
  static final Map<String, LyricsData> _fileStore = {};

  static Future<void> save(String trackId, LyricsData data) async {
    _fileStore[trackId] = data;
    try {
      final file = await _cacheFile(trackId);
      if (file != null) {
        await file.writeAsString(jsonEncode(data.toMap()), flush: true);
      }
    } catch (_) {}
  }

  static Future<LyricsData?> load(String trackId) async {
    if (_fileStore.containsKey(trackId)) return _fileStore[trackId];
    try {
      final file = await _cacheFile(trackId);
      if (file != null && await file.exists()) {
        final text = await file.readAsString();
        final map = jsonDecode(text) as Map<String, dynamic>;
        final data = LyricsData.fromMap(map);
        _fileStore[trackId] = data;
        return data;
      }
    } catch (_) {}
    return null;
  }

  static Future<File?> _cacheFile(String trackId) async {
    try {
      final key = trackId.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
      final dir = Directory('${Directory.systemTemp.path}/bcmusic_lyrics');
      if (!await dir.exists()) await dir.create(recursive: true);
      return File('${dir.path}/$key.json');
    } catch (_) {
      return null;
    }
  }
}
