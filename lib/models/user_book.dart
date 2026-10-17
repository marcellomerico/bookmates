import 'book.dart';

enum BookStatus {
  reading,
  read,
  wantToRead;

  String get dbValue => switch (this) {
    BookStatus.reading => 'reading',
    BookStatus.read => 'read',
    BookStatus.wantToRead => 'want_to_read',
  };

  String get label => switch (this) {
    BookStatus.reading => 'Lese gerade',
    BookStatus.read => 'Gelesen',
    BookStatus.wantToRead => 'Möchte lesen',
  };

  static BookStatus fromDb(String value) => switch (value) {
    'reading' => BookStatus.reading,
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
  });

  final String id;
  final String userId;
  final String bookId;
  final BookStatus status;
  final int? rating;
  final Book? book;

  factory UserBook.fromJson(Map<String, dynamic> json) {
    final bookJson = json['books'];
    return UserBook(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as String,
      status: BookStatus.fromDb(json['status'] as String),
      rating: json['rating'] as int?,
      book: bookJson is Map<String, dynamic> ? Book.fromJson(bookJson) : null,
    );
  }
}
