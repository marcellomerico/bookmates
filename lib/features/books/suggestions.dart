import '../../models/book.dart';
import '../../repositories/open_library_repository.dart';

/// Open Library subject key per app genre (genres table names). Keys checked
/// against search results: plain words like 'mystery' match far too broadly.
const genreSubjects = {
  'Fantasy': 'fantasy_fiction',
  'Science Fiction': 'science_fiction',
  'Krimi': 'detective_and_mystery_stories',
  'Thriller': 'thrillers',
  'Romance': 'romance',
  'Historisch': 'historical_fiction',
  'Biografie': 'biography',
  'Sachbuch': 'nonfiction',
  'Young Adult': 'young_adult_fiction',
  'Horror': 'horror_tales',
  'Klassiker': 'classic_literature',
  'Poetry': 'poetry',
  'Graphic Novel': 'graphic_novels',
  'Self-Help': 'self-help',
  'Philosophie': 'philosophy',
};

/// A friend rated a book highly.
class FriendPick {
  const FriendPick({
    required this.book,
    required this.friendName,
    required this.rating,
  });
  final Book book;
  final String friendName;
  final int rating;
}

class BookSuggestion {
  const BookSuggestion({
    required this.book,
    required this.reason,
    required this.score,
  });

  /// Enough to show the book and put it on the wishlist.
  final OpenLibraryBook book;
  final String reason;
  final int score;

  String get workId => normalizeWorkId(book.openLibraryId);
}

/// Merges friend favourites and genre picks into one ranked list. Books the
/// reader already has (any status) or dismissed are left out.
List<BookSuggestion> rankSuggestions({
  required List<FriendPick> friendPicks,
  required Map<String, List<OpenLibraryBook>> genreBooks,
  required Set<String> excludedWorkIds,
}) {
  final excluded = excludedWorkIds.map(normalizeWorkId).toSet();
  final byWork = <String, BookSuggestion>{};

  final friendsByWork = <String, List<FriendPick>>{};
  for (final pick in friendPicks) {
    final id = pick.book.openLibraryId;
    if (id == null) continue;
    friendsByWork.putIfAbsent(normalizeWorkId(id), () => []).add(pick);
  }
  friendsByWork.forEach((workId, picks) {
    if (excluded.contains(workId)) return;
    picks.sort((a, b) => b.rating.compareTo(a.rating));
    final top = picks.first;
    byWork[workId] = BookSuggestion(
      book: OpenLibraryBook(
        openLibraryId: workId,
        title: top.book.title,
        author: top.book.author,
        isbn: top.book.isbn,
      ).withCoverUrl(top.book.coverUrl),
      reason: picks.length == 1
          ? '${top.friendName} hat es mit ${top.rating} Sternen bewertet'
          : '${top.friendName} und ${picks.length - 1} weitere lieben es',
      score: 100 + top.rating * 10 + (picks.length - 1) * 5,
    );
  });

  genreBooks.forEach((genre, books) {
    for (var i = 0; i < books.length; i++) {
      final workId = normalizeWorkId(books[i].openLibraryId);
      if (excluded.contains(workId) || byWork.containsKey(workId)) continue;
      byWork[workId] = BookSuggestion(
        book: books[i],
        // Open Library genre tags are loose, so don't name a specific genre.
        reason: 'Passt zu deinen Lieblingsgenres',
        score: 50 - i,
      );
    }
  });

  return byWork.values.toList()..sort((a, b) => b.score.compareTo(a.score));
}

/// Today's pick: stable for the whole day, different per reader. Friends'
/// favourites come first; genre picks only when no friend has one.
BookSuggestion? pickForDay(
  List<BookSuggestion> ranked,
  DateTime day,
  String userId,
) {
  if (ranked.isEmpty) return null;
  final fromFriends = ranked.where((s) => s.score >= 100).toList();
  if (fromFriends.isNotEmpty) ranked = fromFriends;
  final key = '$userId-${day.year}-${day.month}-${day.day}';
  var hash = 0;
  for (final unit in key.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  final pool = ranked.length < 10 ? ranked.length : 10;
  return ranked[hash % pool];
}
