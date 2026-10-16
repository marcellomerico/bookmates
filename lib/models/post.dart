import '../models/book.dart';
import '../models/profile.dart';

enum PostType {
  review,
  recommendation,
  discussion,
  quote;

  String get dbValue => name;

  String get label => switch (this) {
    PostType.review => 'Rezension',
    PostType.recommendation => 'Empfehlung',
    PostType.discussion => 'Diskussion',
    PostType.quote => 'Zitat',
  };

  static PostType fromDb(String value) => switch (value) {
    'review' => PostType.review,
    'recommendation' => PostType.recommendation,
    'quote' => PostType.quote,
    _ => PostType.discussion,
  };
}

class Post {
  const Post({
    required this.id,
    required this.authorId,
    required this.content,
    required this.postType,
    required this.createdAt,
    this.bookId,
    this.groupId,
    this.imageUrl,
    this.author,
    this.book,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });

  final String id;
  final String authorId;
  final String? bookId;
  final String? groupId;
  final String content;
  final PostType postType;
  final String? imageUrl;
  final DateTime createdAt;
  final Profile? author;
  final Book? book;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  Post copyWith({int? likeCount, int? commentCount, bool? likedByMe}) {
    return Post(
      id: id,
      authorId: authorId,
      bookId: bookId,
      groupId: groupId,
      content: content,
      postType: postType,
      imageUrl: imageUrl,
      createdAt: createdAt,
      author: author,
      book: book,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByMe: likedByMe ?? this.likedByMe,
    );
  }

  factory Post.fromJson(Map<String, dynamic> json, {String? currentUserId}) {
    final authorJson = json['profiles'];
    final bookJson = json['books'];
    final likes = json['likes'];
    final comments = json['comments'];

    var likeCount = 0;
    var likedByMe = false;
    if (likes is List) {
      likeCount = likes.length;
      if (currentUserId != null) {
        likedByMe = likes.any(
          (row) => row is Map && row['user_id'] == currentUserId,
        );
      }
    } else if (json['like_count'] is int) {
      likeCount = json['like_count'] as int;
      likedByMe = json['liked_by_me'] as bool? ?? false;
    }

    var commentCount = 0;
    if (comments is List) {
      commentCount = comments.length;
    } else if (json['comment_count'] is int) {
      commentCount = json['comment_count'] as int;
    }

    return Post(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      bookId: json['book_id'] as String?,
      groupId: json['group_id'] as String?,
      content: json['content'] as String,
      postType: PostType.fromDb(json['post_type'] as String? ?? 'discussion'),
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      author: authorJson is Map<String, dynamic>
          ? Profile.fromJson(authorJson)
          : null,
      book: bookJson is Map<String, dynamic> ? Book.fromJson(bookJson) : null,
      likeCount: likeCount,
      commentCount: commentCount,
      likedByMe: likedByMe,
    );
  }
}

class Comment {
  const Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.author,
  });

  final String id;
  final String postId;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final Profile? author;

  factory Comment.fromJson(Map<String, dynamic> json) {
    final authorJson = json['profiles'];
    return Comment(
      id: json['id'] as String,
      postId: json['post_id'] as String,
      authorId: json['author_id'] as String,
      content: json['content'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      author: authorJson is Map<String, dynamic>
          ? Profile.fromJson(authorJson)
          : null,
    );
  }
}
