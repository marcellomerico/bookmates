class Book {
  const Book({
    required this.id,
    required this.title,
    this.openLibraryId,
    this.author,
    this.coverUrl,
    this.isbn,
  });

  final String id;
  final String? openLibraryId;
  final String title;
  final String? author;
  final String? coverUrl;
  final String? isbn;

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      openLibraryId: json['open_library_id'] as String?,
      title: json['title'] as String,
      author: json['author'] as String?,
      coverUrl: json['cover_url'] as String?,
      isbn: json['isbn'] as String?,
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      if (openLibraryId != null) 'open_library_id': openLibraryId,
      'title': title,
      if (author != null) 'author': author,
      if (coverUrl != null) 'cover_url': coverUrl,
      if (isbn != null) 'isbn': isbn,
    };
  }
}
