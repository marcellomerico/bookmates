import 'package:booksquad/features/auth/presentation/follow_suggestions_step.dart';
import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:booksquad/features/social/providers/social_providers.dart';
import 'package:booksquad/models/group.dart';
import 'package:booksquad/models/profile.dart';
import 'package:booksquad/repositories/follow_repository.dart';
import 'package:booksquad/repositories/group_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fixtures.dart';

class FakeFollowRepository extends FollowRepository {
  FakeFollowRepository() : super(offlineClient());
  final calls = <String>[];
  bool fail = false;

  @override
  Future<FollowState> follow({
    required String followerId,
    required String followingId,
  }) async {
    calls.add('follow $followingId');
    if (fail) throw Exception('network');
    return FollowState.following;
  }
}

class FakeGroupRepository extends GroupRepository {
  FakeGroupRepository() : super(offlineClient());
  final calls = <String>[];

  @override
  Future<void> joinGroup({
    required String groupId,
    required String userId,
  }) async => calls.add('join $groupId');
}

Future<void> _pump(
  WidgetTester tester,
  OnboardingSuggestions data, {
  FakeFollowRepository? follows,
  FakeGroupRepository? groups,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserProvider.overrideWithValue(testUser('me')),
        onboardingSuggestionsProvider.overrideWith((ref) async => data),
        followRepositoryProvider.overrideWithValue(
          follows ?? FakeFollowRepository(),
        ),
        groupRepositoryProvider.overrideWithValue(
          groups ?? FakeGroupRepository(),
        ),
      ],
      child: const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: FollowSuggestionsStep()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const anna = Profile(id: 'u1', username: 'anna', displayName: 'Anna');
  final circle = BookGroup(
    id: 'g1',
    creatorId: 'u1',
    name: 'Krimi-Kreis',
    isPrivate: false,
    createdAt: DateTime.utc(2026),
  );

  testWidgets('renders suggestions; Folgen calls repo and flips label', (
    tester,
  ) async {
    final follows = FakeFollowRepository();
    final groups = FakeGroupRepository();
    await _pump(
      tester,
      OnboardingSuggestions(people: const [anna], groups: [circle]),
      follows: follows,
      groups: groups,
    );

    expect(find.text('Anna'), findsOneWidget);
    expect(find.text('@anna'), findsOneWidget);
    expect(find.text('Lesekreise für dich'), findsOneWidget);

    await tester.tap(find.text('Folgen'));
    await tester.pumpAndSettle();
    expect(follows.calls, ['follow u1']);
    expect(find.text('Folge ich'), findsOneWidget);

    await tester.tap(find.text('Beitreten'));
    await tester.pumpAndSettle();
    expect(groups.calls, ['join g1']);
    expect(find.text('Beigetreten'), findsOneWidget);
  });

  testWidgets('failed follow reverts and shows SnackBar', (tester) async {
    final follows = FakeFollowRepository()..fail = true;
    await _pump(
      tester,
      const OnboardingSuggestions(people: [anna]),
      follows: follows,
    );

    await tester.tap(find.text('Folgen'));
    await tester.pumpAndSettle();
    expect(find.text('Folgen'), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('empty suggestions show empty state', (tester) async {
    await _pump(tester, const OnboardingSuggestions());
    expect(find.text('Du bist eine der ersten Personen hier'), findsOneWidget);
  });
}
