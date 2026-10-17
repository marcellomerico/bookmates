import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book.dart';
import '../models/user_book.dart';
import 'open_library_repository.dart';

final _workId = RegExp(r'^OL\d+W$');

String _clip(String s, int max) => s.length > max ? s.substring(0, max) : s;

class BookRepository {
  BookRepository(this._client);

  final SupabaseClient _client;

  Future<Book> upsertFromOpenLibrary(OpenLibraryBook result) async {
    final id = normalizeWorkId(result.openLibraryId);
    if (!_workId.hasMatch(id)) {
      throw ArgumentError.value(result.openLibraryId, 'openLibraryId');
    }
    // Rows may store either 'OL1W' or '/works/OL1W'; match both.
    final existing = await getByOpenLibraryId(id);
    if (existing != null) return existing;

    final inserted = await _client
        .from('books')
        .insert({
          'open_library_id': id,
          'title': _clip(result.title, 500),
          'author': result.author == null ? null : _clip(result.author!, 300),
          'cover_url': result.coverUrl,
          'isbn': result.isbn,
        })
        .select()
        .single();

    return Book.fromJson(inserted);
  }

  Future<Book?> getByOpenLibraryId(String workId) async {
    final id = normalizeWorkId(workId);
    if (!_workId.hasMatch(id)) return null;
    final rows = await _client
        .from('books')
        .select()
        .or('open_library_id.eq.$id,open_library_id.eq./works/$id')
        .limit(1);
    return rows.isEmpty ? null : Book.fromJson(rows.first);
  }

  Future<int> readerCount(String bookId) async {
    final res = await _client
        .from('user_books')
        .select('id')
        .eq('book_id', bookId)
        .count(CountOption.exact);
    return res.count;
  }

  Future<UserBook?> myEntry({
    required String userId,
    required String bookId,
  }) async {
    final row = await _client
        .from('user_books')
        .select('*, books(*)')
        .eq('user_id', userId)
        .eq('book_id', bookId)
        .maybeSingle();
    return row == null ? null : UserBook.fromJson(row);
  }

  Future<UserBook> addToShelf({
    required String userId,
    required OpenLibraryBook result,
    required BookStatus status,
  }) async {
    final book = await upsertFromOpenLibrary(result);

    final existing = await _client
        .from('user_books')
        .select('*, books(*)')
        .eq('user_id', userId)
        .eq('book_id', book.id)
        .maybeSingle();

    if (existing != null) {
      final updated = await _client
          .from('user_books')
          .update({'status': status.dbValue})
          .eq('id', existing['id'] as String)
          .select('*, books(*)')
          .single();
      return UserBook.fromJson(updated);
    }

    final inserted = await _client
        .from('user_books')
        .insert({
          'user_id': userId,
          'book_id': book.id,
          'status': status.dbValue,
        })
        .select('*, books(*)')
        .single();

    return UserBook.fromJson(inserted);
  }

  Future<List<UserBook>> getBookshelf(String userId) async {
    final rows = await _client
        .from('user_books')
        .select('*, books(*)')
        .eq('user_id', userId)
        .order('id');

    return (rows as List)
        .map((row) => UserBook.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  Future<void> updateStatus(String userBookId, BookStatus status) async {
    await _client
        .from('user_books')
        .update({'status': status.dbValue})
        .eq('id', userBookId);
  }

  Future<void> updateRating(String userBookId, int? rating) async {
    await _client
        .from('user_books')
        .update({'rating': rating})
        .eq('id', userBookId);
  }

  Future<void> removeFromShelf(String userBookId) async {
    await _client.from('user_books').delete().eq('id', userBookId);
  }
}
