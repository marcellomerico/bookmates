import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/post.dart';
import '../../auth/providers/auth_provider.dart';
import 'social_providers.dart';

typedef LikeState = ({bool liked, int count});

/// Optimistic like state per post id; wins over the post's server values.
/// Lives for the session and resets when the signed-in user changes.
class LikeOverrides extends Notifier<Map<String, LikeState>> {
  final _pending = <String>{};

  @override
  Map<String, LikeState> build() {
    ref.watch(currentUserProvider.select((u) => u?.id));
    _pending.clear();
    return const {};
  }

  LikeState of(Post post) =>
      state[post.id] ?? (liked: post.likedByMe, count: post.likeCount);

  /// Flips the like at once; rolls back and rethrows if the request fails.
  /// Taps while a request for the same post is in flight are ignored.
  Future<void> toggle(Post post, {required String userId}) async {
    if (!_pending.add(post.id)) return;
    // build() resets state on sign-out/switch; a late rollback must not leak in.
    final sessionUser = ref.read(currentUserProvider)?.id;
    bool sameUser() => ref.read(currentUserProvider)?.id == sessionUser;
    final previous = state[post.id];
    final current = of(post);
    state = {
      ...state,
      post.id: (
        liked: !current.liked,
        count: current.count + (current.liked ? -1 : 1),
      ),
    };
    try {
      final repo = ref.read(postRepositoryProvider);
      if (current.liked) {
        await repo.unlikePost(postId: post.id, userId: userId);
      } else {
        await repo.likePost(postId: post.id, userId: userId);
      }
    } catch (_) {
      if (sameUser()) {
        state = previous == null
            ? ({...state}..remove(post.id))
            : {...state, post.id: previous};
      }
      rethrow;
    } finally {
      if (sameUser()) _pending.remove(post.id);
    }
  }

  /// Drops overrides that fresh server data now confirms, so later server
  /// changes (other users' likes) show through. Skips in-flight posts.
  void reconcile(Iterable<Post> posts) {
    final next = {...state};
    for (final p in posts) {
      final o = next[p.id];
      if (o != null &&
          !_pending.contains(p.id) &&
          o.liked == p.likedByMe &&
          o.count == p.likeCount) {
        next.remove(p.id);
      }
    }
    if (next.length != state.length) state = next;
  }
}

final likeOverridesProvider =
    NotifierProvider<LikeOverrides, Map<String, LikeState>>(LikeOverrides.new);
