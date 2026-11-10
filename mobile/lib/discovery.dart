import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_config.dart';

class DiscoverySong {
  const DiscoverySong({
    required this.id,
    required this.title,
    required this.artist,
    this.durationMs = 0,
    this.viewCount = 0,
  });
  final String id, title, artist;
  final int durationMs, viewCount;
  String get sourceUrl => 'https://www.youtube.com/watch?v=$id';
  String get thumbnail => 'https://i.ytimg.com/vi/$id/hqdefault.jpg';

  static List<DiscoverySong> parseItems(Map<String, dynamic> response) {
    final items = response['items'];
    if (items is! List) {
      throw const DiscoveryFailure('Dữ liệu nhạc chưa đọc được. Hãy thử lại.');
    }
    return items
        .take(50)
        .whereType<Map>()
        .where(
          (row) =>
              row['id'] is String &&
              RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(row['id'] as String),
        )
        .map(
          (row) => DiscoverySong(
            id: row['id'] as String,
            title: _decode(row['title'], 'Chưa có tên'),
            artist: _decode(row['artist'], ''),
            durationMs: _number(row['durationSeconds']) * 1000,
            viewCount: _number(row['viewCount']),
          ),
        )
        .toList(growable: false);
  }

  static int _number(Object? value) =>
      (value is num ? value.toInt() : int.tryParse('$value') ?? 0).clamp(
        0,
        1 << 50,
      );
  static String _decode(Object? input, String fallback) {
    if (input is! String || input.trim().isEmpty) return fallback;
    var text = input.length > 500 ? input.substring(0, 500) : input;
    const entities = {
      '&amp;': '&',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&lt;': '<',
      '&gt;': '>',
    };
    entities.forEach((entity, value) {
      text = text.replaceAll(entity, value);
    });
    return text
        .replaceAllMapped(RegExp(r'&#(x[0-9a-fA-F]+|\d+);'), (match) {
          final value = match[1]!;
          final point = value.startsWith('x')
              ? int.tryParse(value.substring(1), radix: 16)
              : int.tryParse(value);
          return point != null &&
                  point > 0 &&
                  point <= 0x10ffff &&
                  (point < 0xd800 || point > 0xdfff)
              ? String.fromCharCode(point)
              : '';
        })
        .replaceAll(RegExp(r'[\x00-\x1f]'), ' ')
        .trim();
  }
}

class DiscoveryFailure implements Exception {
  const DiscoveryFailure(this.message);
  final String message;
}

abstract class DiscoveryRepository {
  Future<List<DiscoverySong>> feed(String query, String order);
  Future<List<DiscoverySong>> search(String query);
  void dispose();
}

abstract interface class SearchSuggestions {
  Future<List<String>> suggestions(String query);
}

class WebsiteDiscoveryRepository
    implements DiscoveryRepository, SearchSuggestions {
  WebsiteDiscoveryRepository({String? host})
      : host = host ?? BCMusicConfig.websiteHost;

  static const defaultWebsiteHost = BCMusicConfig.defaultWebsiteHost;

  final String host;
  final _client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  final _cache = <String, (DateTime, List<DiscoverySong>)>{};
  final _pending = <String, Future<List<DiscoverySong>>>{};

  @override
  Future<List<DiscoverySong>> feed(String query, String order) =>
      _cached('explore', {'q': query, 'order': order});
  @override
  Future<List<DiscoverySong>> search(String query) =>
      _cached('search', {'q': query, 'maxResults': '20'});

  @override
  Future<List<String>> suggestions(String query) async {
    final data = await _request(
      Uri.https(host, '/api/search/suggestions', {
        'q': query,
        'language': 'vi',
      }),
    ).timeout(const Duration(seconds: 5));
    final rows = data['suggestions'];
    return rows is List
        ? rows
              .whereType<String>()
              .where((text) => text.trim().isNotEmpty && text.length <= 200)
              .take(6)
              .toList()
        : [];
  }

  Future<List<DiscoverySong>> _cached(
    String endpoint,
    Map<String, String> parameters,
  ) async {
    final uri = Uri.https(
      host,
      '/api/$endpoint',
      parameters,
    );
    final key = uri.toString();
    final cached = _cache[key];
    if (cached != null &&
        DateTime.now().difference(cached.$1) < const Duration(minutes: 10)) {
      return cached.$2;
    }
    if (_pending[key] case final request?) return request;
    final future = _request(uri).then(DiscoverySong.parseItems);
    _pending[key] = future;
    try {
      final songs = await future;
      if (_cache.length >= 30) _cache.remove(_cache.keys.first);
      _cache[key] = (DateTime.now(), songs);
      return songs;
    } finally {
      _pending.remove(key);
    }
  }

  Future<Map<String, dynamic>> _request(Uri uri) async {
    HttpClientRequest? request;
    try {
      request = await _client.getUrl(uri).timeout(const Duration(seconds: 15));
      request.followRedirects = false;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 35),
      );
      if (response.statusCode != 200) {
        request.abort();
        throw const DiscoveryFailure(
          'Nguồn khám phá đang bận. Hãy thử lại sau.',
        );
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        if (bytes.length + chunk.length > 2 * 1024 * 1024) {
          request.abort();
          throw const DiscoveryFailure('Dữ liệu trả về quá lớn.');
        }
        bytes.addAll(chunk);
      }
      final json = jsonDecode(utf8.decode(bytes));
      if (json is! Map<String, dynamic>) throw const FormatException();
      return json;
    } on DiscoveryFailure {
      rethrow;
    } on SocketException {
      throw const DiscoveryFailure(
        'Không có kết nối. Bạn vẫn có thể nghe các bài đã tải.',
      );
    } on TimeoutException {
      request?.abort();
      throw const DiscoveryFailure('Kết nối chậm. Hãy thử lại.');
    } catch (_) {
      throw const DiscoveryFailure(
        'Không tải được danh sách nhạc. Hãy thử lại.',
      );
    }
  }

  @override
  void dispose() => _client.close(force: true);
}

class MusicGenre {
  const MusicGenre(this.label, this.query);
  final String label, query;
}

const musicGenres = [
  MusicGenre('TikTok Remix', 'tiktok remix'),
  MusicGenre('Nhạc Trung', 'nhạc trung douyin'),
  MusicGenre('Lofi', 'lofi chill vietnamese'),
  MusicGenre('EDM', 'edm ncs'),
  MusicGenre('Acoustic', 'acoustic nhẹ nhàng'),
  MusicGenre('K-Pop', 'kpop hit'),
  MusicGenre('Rap Việt', 'rap việt hot'),
  MusicGenre('R&B', 'rnb soul'),
  MusicGenre('Piano', 'piano instrumental relaxing'),
  MusicGenre('Pop Hits', 'pop hits 2024 2025'),
];

class FeedSection {
  const FeedSection({this.songs = const [], this.loading = true, this.error});
  final List<DiscoverySong> songs;
  final bool loading;
  final String? error;
}

class DiscoveryController extends ChangeNotifier {
  DiscoveryController(this.repository);
  final DiscoveryRepository repository;
  int genreIndex = 0;
  List<FeedSection> sections = List.generate(3, (_) => const FeedSection());
  List<DiscoverySong> searchResults = [];
  String query = '';
  String? searchError;
  bool searching = false, _disposed = false;
  int _feedRequest = 0, _searchRequest = 0;

  Future<void> selectGenre(int index) async {
    if (index < 0 || index >= musicGenres.length) return;
    final request = ++_feedRequest;
    genreIndex = index;
    sections = List.generate(3, (_) => const FeedSection());
    _notify();
    final query = musicGenres[index].query;
    await Future.wait([
      _section(0, '$query trending', 'relevance', request),
      _section(1, query, 'viewCount', request),
      _section(2, query, 'date', request),
    ]);
  }

  Future<void> _section(
    int index,
    String query,
    String order,
    int request,
  ) async {
    try {
      final songs = await repository.feed(query, order);
      if (!_disposed && request == _feedRequest) {
        sections[index] = FeedSection(songs: songs, loading: false);
      }
    } catch (error) {
      if (!_disposed && request == _feedRequest) {
        sections[index] = FeedSection(loading: false, error: _message(error));
      }
    }
    if (request == _feedRequest) _notify();
  }

  Future<void> search(String input) async {
    final request = ++_searchRequest;
    query = input.trim().substring(0, input.trim().length.clamp(0, 200));
    searchError = null;
    searchResults = [];
    searching = query.isNotEmpty;
    _notify();
    if (query.isEmpty) return;
    try {
      final songs = await repository.search(query);
      if (!_disposed && request == _searchRequest) searchResults = songs;
    } catch (error) {
      if (!_disposed && request == _searchRequest) {
        searchError = _message(error);
      }
    } finally {
      if (!_disposed && request == _searchRequest) {
        searching = false;
        _notify();
      }
    }
  }

  String _message(Object error) => error is DiscoveryFailure
      ? error.message
      : 'Không tải được nhạc. Hãy thử lại.';
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    repository.dispose();
    super.dispose();
  }
}
