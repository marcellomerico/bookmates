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
      state = previous == null
          ? ({...state}..remove(post.id))
          : {...state, post.id: previous};
      rethrow;
    } finally {
      _pending.remove(post.id);
    }
  }
}

final likeOverridesProvider =
    NotifierProvider<LikeOverrides, Map<String, LikeState>>(LikeOverrides.new);
