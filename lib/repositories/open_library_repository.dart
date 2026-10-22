import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class OpenLibraryBook {
  const OpenLibraryBook({
    required this.openLibraryId,
    required this.title,
    this.author,
    this.coverId,
    this.isbn,
    this.pageCount,
  });

  final String openLibraryId;
  final String title;
  final String? author;
  final int? coverId;
  final String? isbn;

  /// Median page count across editions, a starting value the user can correct.
  final int? pageCount;

  String? get coverUrl => coverId != null
      ? 'https://covers.openlibrary.org/b/id/$coverId-M.jpg'
      : null;
}

/// 'OL123W' from '/works/OL123W' or 'OL123W'.
String normalizeWorkId(String id) => id.trim().replaceFirst('/works/', '');

class OpenLibraryException implements Exception {
  const OpenLibraryException(this.message, [this.statusCode]);
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class OpenLibraryWork {
  const OpenLibraryWork({
    required this.id,
    required this.title,
    this.description,
    this.subjects = const [],
    this.coverId,
  });

  final String id;
  final String title;
  final String? description;
  final List<String> subjects;
  final int? coverId;

  String? get coverUrl => coverId != null
      ? 'https://covers.openlibrary.org/b/id/$coverId-L.jpg'
      : null;
}

/// Open Library subjects are raw catalogue tags: near-duplicates
/// ("Science fiction" / "Science-fiction"), qualified entries ("Dune
/// (Imaginary place), fiction") and list markers ("New York Times reviewed").
/// Keeps up to [max] short, distinct topics.
List<String> cleanSubjects(Iterable<String> raw, {int max = 5}) {
  final seen = <String>{};
  final result = <String>[];
  for (final s in raw) {
    final t = s.trim();
    if (t.isEmpty || t.length > 30) continue;
    if (t.contains(',') || t.contains('(') || t.contains(':')) continue;
    if (t.toLowerCase().contains('reviewed') ||
        t.toLowerCase().startsWith('nyt:')) {
      continue;
    }
    final key = t.toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß]'), '');
    if (!seen.add(key)) continue;
    result.add(t);
    if (result.length == max) break;
  }
  return result;
}

class OpenLibraryRepository {
  OpenLibraryRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {
    'User-Agent': 'Booksquad/1.0 (support@booksquad.de)',
  };
  static const _timeout = Duration(seconds: 10);

  /// GET with timeout; network failures become [OpenLibraryException].
  Future<http.Response> _get(Uri uri) async {
    try {
      return await _client.get(uri, headers: _headers).timeout(_timeout);
    } on TimeoutException {
      throw const OpenLibraryException('Open Library antwortet nicht.');
    } on http.ClientException {
      // IOClient wraps SocketException in a ClientException.
      throw const OpenLibraryException('Keine Verbindung zu Open Library.');
    }
  }

  Future<Map<String, dynamic>> _getWorkJson(String id) async {
    final response = await _get(
      Uri.https('openlibrary.org', '/works/$id.json'),
    );
    if (response.statusCode != 200) {
      throw OpenLibraryException(
        'Buchdetails konnten nicht geladen werden.',
        response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<OpenLibraryWork> getWork(String workId) async {
    var id = normalizeWorkId(workId);
    var data = await _getWorkJson(id);
    // Merged works are redirect stubs; follow once (no loops).
    final location = data['location'];
    final type = data['type'];
    if (type is Map &&
        type['key'] == '/type/redirect' &&
        location is String &&
        RegExp(r'^/works/OL\d+W$').hasMatch(location)) {
      id = normalizeWorkId(location);
      data = await _getWorkJson(id);
    }
    final rawDesc = data['description'];
    final desc = (rawDesc is Map ? rawDesc['value'] : rawDesc);
    final description = desc is String && desc.trim().isNotEmpty
        ? desc.trim()
        : null;
    final subjects = cleanSubjects(
      (data['subjects'] as List<dynamic>? ?? []).whereType<String>(),
    );
    final covers = data['covers'] as List<dynamic>?;
    final coverId = covers?.whereType<int>().where((c) => c > 0).firstOrNull;
    return OpenLibraryWork(
      id: id,
      title: data['title'] as String? ?? 'Unbekannter Titel',
      description: description,
      subjects: subjects,
      coverId: coverId,
    );
  }

  Future<List<OpenLibraryBook>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.https('openlibrary.org', '/search.json', {
      'q': query.trim(),
      'limit': '20',
      'fields': 'key,title,author_name,cover_i,isbn,number_of_pages_median',
    });

    final response = await _get(uri);
    if (response.statusCode != 200) {
      throw Exception('Open Library Suche fehlgeschlagen.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = data['docs'] as List<dynamic>? ?? [];

    return docs
        .map((doc) {
          final map = doc as Map<String, dynamic>;
          final key = map['key'] as String? ?? '';
          final authors = map['author_name'] as List<dynamic>?;
          final isbns = map['isbn'] as List<dynamic>?;

          return OpenLibraryBook(
            openLibraryId: key
                .replaceFirst('/works/', '')
                .replaceFirst('/books/', ''),
            title: map['title'] as String? ?? 'Unbekannter Titel',
            author: authors?.isNotEmpty == true
                ? authors!.first as String
                : null,
            coverId: map['cover_i'] as int?,
            isbn: isbns?.isNotEmpty == true ? isbns!.first as String : null,
            pageCount: switch (map['number_of_pages_median']) {
              final int n when n > 0 && n <= 20000 => n,
              _ => null,
            },
          );
        })
        .where((book) => book.openLibraryId.isNotEmpty)
        .toList();
  }
}
