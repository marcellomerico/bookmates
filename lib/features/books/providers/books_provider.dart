import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/book.dart';
import '../../../models/user_book.dart';
import '../../../repositories/book_repository.dart';
import '../../../repositories/open_library_repository.dart';
import '../../../repositories/profile_repository.dart';
import '../../auth/providers/auth_provider.dart';

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
