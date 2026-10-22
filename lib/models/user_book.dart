import 'book.dart';

/// Shelf = books the user owns (reading, unread, read); wantToRead is the
/// separate wishlist.
enum BookStatus {
  reading,
  unread,
  read,
  wantToRead;

  /// Statuses that put a book on the shelf, in display order.
  static const shelf = [BookStatus.reading, BookStatus.unread, BookStatus.read];

  bool get onShelf => this != BookStatus.wantToRead;

  String get dbValue => switch (this) {
    BookStatus.reading => 'reading',
    BookStatus.unread => 'unread',
    BookStatus.read => 'read',
    BookStatus.wantToRead => 'want_to_read',
  };

  String get label => switch (this) {
    BookStatus.reading => 'Lese ich',
    BookStatus.unread => 'Ungelesen',
    BookStatus.read => 'Gelesen',
    BookStatus.wantToRead => 'Wunschliste',
  };

  static BookStatus fromDb(String value) => switch (value) {
    'reading' => BookStatus.reading,
    'unread' => BookStatus.unread,
    'read' => BookStatus.read,
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
  });

  final String id;
  final String userId;
  final String bookId;
  final BookStatus status;
  final int? rating;
  final Book? book;
  final int? pageCount;
  final int? currentPage;

  /// 0..1 once both page numbers are known, else null.
  double? get progress => pageCount == null || currentPage == null
      ? null
      : (currentPage! / pageCount!).clamp(0.0, 1.0);

  UserBook copyWith({
    BookStatus? status,
    int? Function()? rating,
    int? Function()? pageCount,
    int? Function()? currentPage,
  }) => UserBook(
    id: id,
    userId: userId,
    bookId: bookId,
    status: status ?? this.status,
    rating: rating == null ? this.rating : rating(),
    book: book,
    pageCount: pageCount == null ? this.pageCount : pageCount(),
    currentPage: currentPage == null ? this.currentPage : currentPage(),
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
    );
  }
}
