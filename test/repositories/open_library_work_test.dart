import 'dart:convert';

import 'package:booksquad/repositories/open_library_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

OpenLibraryRepository repo(int status, Object body) => OpenLibraryRepository(
  client: MockClient((req) async {
    expect(req.headers['User-Agent'], contains('Booksquad'));
    expect(req.url.path, '/works/OL1W.json');
    return http.Response(jsonEncode(body), status);
  }),
);

void main() {
  test('normalizeWorkId', () {
    expect(normalizeWorkId('/works/OL123W'), 'OL123W');
    expect(normalizeWorkId('OL123W'), 'OL123W');
  });

  test('string description, subjects capped, cover L', () async {
    final w = await repo(200, {
      'title': 'T',
      'description': '  Hi  ',
      'subjects': List.generate(12, (i) => 's$i'),
      'covers': [-1, 42],
    }).getWork('/works/OL1W');
    expect(w.id, 'OL1W');
    expect(w.description, 'Hi');
    expect(w.subjects.length, 5);
    expect(w.coverUrl, 'https://covers.openlibrary.org/b/id/42-L.jpg');
  });

  test('object description', () async {
    final w = await repo(200, {
      'title': 'T',
      'description': {'type': '/type/text', 'value': 'Obj'},
    }).getWork('OL1W');
    expect(w.description, 'Obj');
  });

  test('missing fields', () async {
    final w = await repo(200, <String, dynamic>{}).getWork('OL1W');
    expect(w.description, isNull);
    expect(w.subjects, isEmpty);
    expect(w.coverUrl, isNull);
  });

  test('404 throws', () {
    expect(repo(404, {}).getWork('OL1W'), throwsA(isA<OpenLibraryException>()));
  });

  test('follows a /type/redirect stub once', () async {
    final paths = <String>[];
    final w = await OpenLibraryRepository(
      client: MockClient((req) async {
        paths.add(req.url.path);
        final body = req.url.path == '/works/OL1W.json'
            ? {
                'type': {'key': '/type/redirect'},
                'location': '/works/OL2W',
              }
            : {'title': 'Merged'};
        return http.Response(jsonEncode(body), 200);
      }),
    ).getWork('OL1W');
    expect(paths, ['/works/OL1W.json', '/works/OL2W.json']);
    expect(w.id, 'OL2W');
    expect(w.title, 'Merged');
  });

  test('network failure becomes OpenLibraryException', () {
    final r = OpenLibraryRepository(
      client: MockClient((_) => throw http.ClientException('offline')),
    );
    expect(r.getWork('OL1W'), throwsA(isA<OpenLibraryException>()));
  });

  test('cleanSubjects drops near-duplicates and catalogue noise', () {
    expect(
      cleanSubjects([
        'Dune (Imaginary place)',
        'Fiction',
        'Fiction, science fiction, general',
        'New York Times reviewed',
        'Science fiction',
        'Science-fiction',
        'American literature',
      ]),
      ['Fiction', 'Science fiction', 'American literature'],
    );
  });
}
