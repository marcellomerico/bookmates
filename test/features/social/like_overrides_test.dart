import 'dart:async';

import 'package:bookmates/features/auth/providers/auth_provider.dart';
import 'package:bookmates/features/social/providers/like_overrides.dart';
import 'package:bookmates/features/social/providers/social_providers.dart';
import 'package:bookmates/models/post.dart';
import 'package:bookmates/repositories/post_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fixtures.dart';

class FakeLikeRepository extends PostRepository {
  FakeLikeRepository() : super(offlineClient());

  Completer<void>? gate;
  bool fail = false;
  final calls = <String>[];

  Future<void> _call(String what) async {
    calls.add(what);
    if (gate != null) await gate!.future;
    if (fail) throw Exception('network');
  }

  @override
  Future<void> likePost({required String postId, required String userId}) =>
      _call('like $postId');

  @override
  Future<void> unlikePost({required String postId, required String userId}) =>
      _call('unlike $postId');
}

final _post = Post(
  id: 'p1',
  authorId: 'a',
  content: 'x',
  postType: PostType.discussion,
  createdAt: DateTime.utc(2026),
  likeCount: 3,
);

void main() {
  late FakeLikeRepository repo;
  late ProviderContainer container;

  setUp(() {
    repo = FakeLikeRepository();
    container = ProviderContainer(
      overrides: [
        currentUserProvider.overrideWithValue(testUser('me')),
        postRepositoryProvider.overrideWithValue(repo),
      ],
    );
  });
  tearDown(() => container.dispose());

  LikeOverrides likes() => container.read(likeOverridesProvider.notifier);
  ({bool liked, int count})? override() => container.read(likeOverridesProvider)['p1'];

  test('toggle applies the like immediately, then unlike reverts', () async {
    repo.gate = Completer();
    final f = likes().toggle(_post, userId: 'me');
    expect(override(), (liked: true, count: 4));
    repo.gate!.complete();
    await f;
    expect(repo.calls, ['like p1']);

    repo.gate = null;
    await likes().toggle(_post, userId: 'me');
    expect(override(), (liked: false, count: 3));
    expect(repo.calls, ['like p1', 'unlike p1']);
  });

  test('failed request rolls back and rethrows', () async {
    repo.fail = true;
    await expectLater(likes().toggle(_post, userId: 'me'), throwsException);
    expect(override(), isNull);
  });

  test('taps while a request is pending are ignored', () async {
    repo.gate = Completer();
    final first = likes().toggle(_post, userId: 'me');
    await likes().toggle(_post, userId: 'me');
    expect(override(), (liked: true, count: 4));
    repo.gate!.complete();
    await first;
    expect(repo.calls, ['like p1']);
  });

  test('overrides reset when the user changes', () async {
    await likes().toggle(_post, userId: 'me');
    expect(override(), isNotNull);
    container.updateOverrides([
      currentUserProvider.overrideWithValue(testUser('other')),
      postRepositoryProvider.overrideWithValue(repo),
    ]);
    expect(override(), isNull);
  });
}
