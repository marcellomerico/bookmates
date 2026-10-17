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
  });

  final String openLibraryId;
  final String title;
  final String? author;
  final int? coverId;
  final String? isbn;

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

class OpenLibraryRepository {
  OpenLibraryRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {
    'User-Agent': 'Bookmates/1.0 (support@bookmates.app)',
  };
  static const _timeout = Duration(seconds: 10);

  Future<OpenLibraryWork> getWork(String workId) async {
    final id = normalizeWorkId(workId);
    final uri = Uri.https('openlibrary.org', '/works/$id.json');
    final http.Response response;
    try {
      response = await _client.get(uri, headers: _headers).timeout(_timeout);
    } on TimeoutException {
      throw const OpenLibraryException('Open Library antwortet nicht.');
    }
    if (response.statusCode != 200) {
      throw OpenLibraryException(
        'Buchdetails konnten nicht geladen werden.',
        response.statusCode,
      );
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final rawDesc = data['description'];
    final desc = (rawDesc is Map ? rawDesc['value'] : rawDesc);
    final description = desc is String && desc.trim().isNotEmpty
        ? desc.trim()
        : null;
    final subjects = (data['subjects'] as List<dynamic>? ?? [])
        .whereType<String>()
        .take(8)
        .toList();
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
      'fields': 'key,title,author_name,cover_i,isbn',
    });

    final http.Response response;
    try {
      response = await _client.get(uri, headers: _headers).timeout(_timeout);
    } on TimeoutException {
      throw const OpenLibraryException('Open Library antwortet nicht.');
    }
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
          );
        })
        .where((book) => book.openLibraryId.isNotEmpty)
        .toList();
  }
}
