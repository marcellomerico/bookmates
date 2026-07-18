import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book.dart';
import '../models/user_book.dart';
import 'open_library_repository.dart';

class BookRepository {
  BookRepository(this._client);

  final SupabaseClient _client;

  Future<Book> upsertFromOpenLibrary(OpenLibraryBook result) async {
    final existing = await _client
        .from('books')
        .select()
        .eq('open_library_id', result.openLibraryId)
        .maybeSingle();

    if (existing != null) {
      return Book.fromJson(existing);
    }

    final inserted = await _client
        .from('books')
        .insert({
          'open_library_id': result.openLibraryId,
          'title': result.title,
          'author': result.author,
          'cover_url': result.coverUrl,
          'isbn': result.isbn,
        })
        .select()
        .single();

    return Book.fromJson(inserted);
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

    return (rows as List).map((row) => UserBook.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<void> updateStatus(String userBookId, BookStatus status) async {
    await _client.from('user_books').update({'status': status.dbValue}).eq('id', userBookId);
  }

  Future<void> updateRating(String userBookId, int? rating) async {
    await _client.from('user_books').update({'rating': rating}).eq('id', userBookId);
  }

  Future<void> removeFromShelf(String userBookId) async {
    await _client.from('user_books').delete().eq('id', userBookId);
  }
}
