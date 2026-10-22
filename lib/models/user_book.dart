import 'book.dart';

/// Shelf = books the user owns (reading, unread, read); abandoned books are
/// owned but kept in their own corner; wantToRead is the separate wishlist.
enum BookStatus {
  reading,
  unread,
  read,
  abandoned,
  wantToRead;

  /// Statuses shown on the main shelf, in display order.
  static const shelf = [BookStatus.reading, BookStatus.unread, BookStatus.read];

  /// Owned (main shelf or abandoned), as opposed to the wishlist.
  bool get onShelf => this != BookStatus.wantToRead;

  String get dbValue => switch (this) {
    BookStatus.reading => 'reading',
    BookStatus.unread => 'unread',
    BookStatus.read => 'read',
    BookStatus.abandoned => 'abandoned',
    BookStatus.wantToRead => 'want_to_read',
  };

  String get label => switch (this) {
    BookStatus.reading => 'Lese ich',
    BookStatus.unread => 'Ungelesen',
    BookStatus.read => 'Gelesen',
    BookStatus.abandoned => 'Abgebrochen',
    BookStatus.wantToRead => 'Wunschliste',
  };

  static BookStatus fromDb(String value) => switch (value) {
    'reading' => BookStatus.reading,
    'unread' => BookStatus.unread,
    'read' => BookStatus.read,
    'abandoned' => BookStatus.abandoned,
    _ => BookStatus.wantToRead,
  };
}

class UserBook {
  const UserBook({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.status,
    this.rating,
    this.book,
    this.pageCount,
    this.currentPage,
    this.favoriteRank,
  });

  final String id;
  final String userId;
  final String bookId;
  final BookStatus status;
  final int? rating;
  final Book? book;
  final int? pageCount;
  final int? currentPage;

  /// 1..3 when the book is one of the reader's favourites on the profile.
  final int? favoriteRank;

  /// 0..1 once both page numbers are known, else null.
  double? get progress => pageCount == null || currentPage == null
      ? null
      : (currentPage! / pageCount!).clamp(0.0, 1.0);

  UserBook copyWith({
    BookStatus? status,
    int? Function()? rating,
    int? Function()? pageCount,
    int? Function()? currentPage,
    int? Function()? favoriteRank,
  }) => UserBook(
    id: id,
    userId: userId,
    bookId: bookId,
    status: status ?? this.status,
    rating: rating == null ? this.rating : rating(),
    book: book,
    pageCount: pageCount == null ? this.pageCount : pageCount(),
    currentPage: currentPage == null ? this.currentPage : currentPage(),
    favoriteRank: favoriteRank == null ? this.favoriteRank : favoriteRank(),
  );

  factory UserBook.fromJson(Map<String, dynamic> json) {
    final bookJson = json['books'];
    return UserBook(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as String,
      status: BookStatus.fromDb(json['status'] as String),
      rating: json['rating'] as int?,
      book: bookJson is Map<String, dynamic> ? Book.fromJson(bookJson) : null,
      pageCount: json['page_count'] as int?,
      currentPage: json['current_page'] as int?,
      favoriteRank: json['favorite_rank'] as int?,
    );
  }
}

/// Favourites in profile order.
List<UserBook> favoriteBooks(Iterable<UserBook> shelf) =>
    shelf.where((e) => e.favoriteRank != null).toList()
      ..sort((a, b) => a.favoriteRank!.compareTo(b.favoriteRank!));
