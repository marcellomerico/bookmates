import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/reading_stats.dart';
import '../../../models/book.dart';
import '../../../models/user_book.dart';
import '../../../repositories/book_repository.dart';
import '../../../repositories/open_library_repository.dart';
import '../../../repositories/profile_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../social/providers/social_providers.dart';
import '../suggestions.dart';

final openLibraryRepositoryProvider = Provider<OpenLibraryRepository>((ref) {
  return OpenLibraryRepository();
});

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  return BookRepository(ref.watch(supabaseClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

final bookshelfProvider = FutureProvider<List<UserBook>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  return ref.watch(bookRepositoryProvider).getBookshelf(user.id);
});

final bookshelfByUserProvider = FutureProvider.autoDispose
    .family<List<UserBook>, String>((ref, userId) {
      return ref.watch(bookRepositoryProvider).getBookshelf(userId);
    });

final userGenresProvider = FutureProvider<List<String>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  return ref.watch(profileRepositoryProvider).getUserGenreNames(user.id);
});

final openLibraryWorkProvider = FutureProvider.autoDispose
    .family<OpenLibraryWork, String>((ref, workId) {
      return ref.watch(openLibraryRepositoryProvider).getWork(workId);
    });

final bookByWorkIdProvider = FutureProvider.autoDispose.family<Book?, String>((
  ref,
  workId,
) {
  return ref.watch(bookRepositoryProvider).getByOpenLibraryId(workId);
});

final bookReaderCountProvider = FutureProvider.autoDispose.family<int, String>((
  ref,
  bookId,
) {
  return ref.watch(bookRepositoryProvider).readerCount(bookId);
});

final myShelfEntryProvider = FutureProvider.autoDispose
    .family<UserBook?, String>((ref, bookId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) return null;
      return ref
          .watch(bookRepositoryProvider)
          .myEntry(userId: user.id, bookId: bookId);
    });

/// Today's book suggestion from friends' favourites and the reader's genres.
/// Open Library failures only drop the genre picks.
final dailySuggestionProvider = FutureProvider<BookSuggestion?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final books = ref.watch(bookRepositoryProvider);
  final openLibrary = ref.watch(openLibraryRepositoryProvider);

  final shelf = await ref.watch(bookshelfProvider.future);
  final genres = await ref.watch(userGenresProvider.future);
  final following = await ref
      .watch(followRepositoryProvider)
      .getFollowingIds(user.id);
  final dismissed = await books.dismissedWorkIds();
  final friendPicks = await books.friendsFavorites(following);

  final genreBooks = <String, List<OpenLibraryBook>>{};
  for (final genre in genres.take(2)) {
    final subject = genreSubjects[genre];
    if (subject == null) continue;
    try {
      genreBooks[genre] = await openLibrary.searchBySubject(subject);
    } catch (_) {
      // Offline or Open Library down: friends' picks still work.
    }
  }

  final ranked = rankSuggestions(
    friendPicks: friendPicks,
    genreBooks: genreBooks,
    excludedWorkIds: {
      ...dismissed,
      for (final e in shelf)
        if (e.book?.openLibraryId != null) e.book!.openLibraryId!,
    },
  );
  return pickForDay(ranked, DateTime.now(), user.id);
});

/// Streak and yearly goal. Refetches whenever the shelf reloads (progress, status changes).
final readingStatsProvider = FutureProvider.autoDispose<ReadingStats>((
  ref,
) async {
  if (ref.watch(currentUserProvider) == null) return ReadingStats.empty;
  await ref.watch(bookshelfProvider.future);
  return ref.watch(bookRepositoryProvider).getReadingStats();
});

/// This year's reading days for the statistics screen.
final readingDaysProvider = FutureProvider.autoDispose<Map<DateTime, int>>((
  ref,
) async {
  if (ref.watch(currentUserProvider) == null) return {};
  await ref.watch(bookshelfProvider.future);
  return ref
      .watch(bookRepositoryProvider)
      .getReadingDays(DateTime(DateTime.now().year));
});
