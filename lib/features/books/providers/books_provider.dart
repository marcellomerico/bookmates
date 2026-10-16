import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  ref.watch(authStateProvider);
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
