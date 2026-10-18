import 'package:booksquad/repositories/post_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const base = 'https://abc.supabase.co/storage/v1/object/public';

  test('extracts the object path from a public URL', () {
    expect(
      postImagePathFromUrl('$base/post-images/u1/1700000000.jpg'),
      'u1/1700000000.jpg',
    );
  });

  test('ignores the query string', () {
    expect(
      postImagePathFromUrl('$base/post-images/u1/1700000000.jpg?t=1'),
      'u1/1700000000.jpg',
    );
  });

  test('returns null when post-images is not the bucket segment', () {
    expect(postImagePathFromUrl('$base/avatars/post-images/x.jpg'), isNull);
    expect(postImagePathFromUrl('https://x.co/avatars/post-images/x'), isNull);
  });

  test('returns null for other buckets', () {
    expect(postImagePathFromUrl('$base/avatars/u1/a.jpg'), isNull);
  });
}
