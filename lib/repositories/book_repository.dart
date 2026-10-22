import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/book.dart';
import '../models/user_book.dart';
import 'open_library_repository.dart';
import '../features/books/suggestions.dart';

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
          if (result.pageCount != null) 'page_count': result.pageCount,
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

  /// Saves page numbers; [status] lets the caller move "unread" to "reading" in the same write.
  Future<void> updateProgress(
    String userBookId, {
    required int? currentPage,
    required int? pageCount,
    BookStatus? status,
  }) async {
    await _client
        .from('user_books')
        .update({
          'current_page': currentPage,
          'page_count': pageCount,
          if (status != null) 'status': status.dbValue,
        })
        .eq('id', userBookId);
  }

  /// Makes [userBookIds] (max 3, in order) the user's favourites; others lose the mark.
  Future<void> setFavorites(String userId, List<String> userBookIds) async {
    assert(userBookIds.length <= 3);
    // Clear first: ranks are unique per user.
    await _client
        .from('user_books')
        .update({'favorite_rank': null})
        .eq('user_id', userId)
        .not('favorite_rank', 'is', null);
    for (var i = 0; i < userBookIds.length; i++) {
      await _client
          .from('user_books')
          .update({'favorite_rank': i + 1})
          .eq('id', userBookIds[i])
          .eq('user_id', userId);
    }
  }

  /// Books the given readers finished and rated 4+ stars, for suggestions.
  Future<List<FriendPick>> friendsFavorites(List<String> userIds) async {
    if (userIds.isEmpty) return const [];
    final rows = await _client
        .from('user_books')
        .select('rating, books(*), profiles(username, display_name)')
        .inFilter('user_id', userIds)
        .eq('status', BookStatus.read.dbValue)
        .gte('rating', 4)
        .limit(60);
    return [
      for (final row in rows as List)
        if (row['books'] is Map<String, dynamic>)
          FriendPick(
            book: Book.fromJson(row['books'] as Map<String, dynamic>),
            rating: row['rating'] as int,
            friendName: switch (row['profiles']) {
              {'display_name': final String name} when name.isNotEmpty => name,
              {'username': final String name} => name,
              _ => 'Jemand',
            },
          ),
    ];
  }

  Future<Set<String>> dismissedWorkIds() async {
    final rows = await _client
        .from('book_dismissals')
        .select('open_library_id');
    return {for (final r in rows as List) r['open_library_id'] as String};
  }

  /// "Kein Interesse": this book is never suggested again.
  Future<void> dismissSuggestion(String workId) async {
    await _client.from('book_dismissals').upsert({
      'open_library_id': workId,
    }, ignoreDuplicates: true);
  }

  Future<void> removeFromShelf(String userBookId) async {
    await _client.from('user_books').delete().eq('id', userBookId);
  }
}
