import 'package:booksquad/features/books/presentation/visual_shelf.dart';
import 'package:booksquad/features/profile/presentation/profile_layout.dart';
import 'package:booksquad/features/social/providers/social_providers.dart';
import 'package:booksquad/models/profile.dart';
import 'package:booksquad/models/profile_stats.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _private = Profile(id: 'p', username: 'leise', isPrivate: true);

void main() {
  test('is_private is read from the profile row', () {
    final json = {'id': 'p', 'username': 'leise', 'is_private': true};
    expect(Profile.fromJson(json).isPrivate, isTrue);
    expect(Profile.fromJson({'id': 'q', 'username': 'laut'}).isPrivate, isFalse);
  });

  testWidgets('locked private profile shows only the header', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStatsProvider.overrideWith(
            (ref, _) async => const ProfileStats(
              postCount: 3,
              followerCount: 1,
              followingCount: 2,
            ),
          ),
          userGenresByIdProvider.overrideWith((ref, _) async => []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ProfileLayout(
              profile: _private,
              own: false,
              locked: true,
              actions: const SizedBox.shrink(),
              onRefresh: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dieses Konto ist privat'), findsOneWidget);
    expect(find.text('@leise'), findsOneWidget);
    expect(find.byType(ShelfView), findsNothing);
  });
}
