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

class OpenLibraryRepository {
  OpenLibraryRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<OpenLibraryBook>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.https('openlibrary.org', '/search.json', {
      'q': query.trim(),
      'limit': '20',
      'fields': 'key,title,author_name,cover_i,isbn',
    });

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Open Library Suche fehlgeschlagen.');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final docs = data['docs'] as List<dynamic>? ?? [];

    return docs.map((doc) {
      final map = doc as Map<String, dynamic>;
      final key = map['key'] as String? ?? '';
      final authors = map['author_name'] as List<dynamic>?;
      final isbns = map['isbn'] as List<dynamic>?;

      return OpenLibraryBook(
        openLibraryId: key.replaceFirst('/works/', '').replaceFirst('/books/', ''),
        title: map['title'] as String? ?? 'Unbekannter Titel',
        author: authors?.isNotEmpty == true ? authors!.first as String : null,
        coverId: map['cover_i'] as int?,
        isbn: isbns?.isNotEmpty == true ? isbns!.first as String : null,
      );
    }).where((book) => book.openLibraryId.isNotEmpty).toList();
  }
}
