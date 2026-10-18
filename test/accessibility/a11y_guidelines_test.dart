import 'package:booksquad/core/theme/app_theme.dart';
import 'package:booksquad/core/widgets/post_card.dart';
import 'package:booksquad/features/auth/presentation/login_screen.dart';
import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:booksquad/models/post.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<void> _pump(WidgetTester tester, Widget child) => tester.pumpWidget(
  ProviderScope(
    overrides: [currentUserProvider.overrideWithValue(null)],
    child: MaterialApp(theme: AppTheme.light, home: Scaffold(body: child)),
  ),
);

Future<void> _expectAccessible(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}

void main() {
  setUpAll(() => initializeDateFormatting('de'));
  testWidgets('LoginScreen meets a11y guidelines', (tester) async {
    await _pump(tester, const LoginScreen());
    await _expectAccessible(tester);
  });

  testWidgets('PostCard meets a11y guidelines', (tester) async {
    final post = Post(
      id: 'p1',
      authorId: 'u1',
      content: 'Ein toller Beitrag',
      postType: PostType.discussion,
      createdAt: DateTime(2026, 1, 1),
      likeCount: 3,
      commentCount: 2,
    );
    await _pump(tester, PostCard(post: post));
    await _expectAccessible(tester);
  });
}
