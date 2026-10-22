import 'package:booksquad/core/widgets/verified_badge.dart';
import 'package:booksquad/models/profile.dart';
import 'package:booksquad/models/verification.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: child)),
);

void main() {
  test('profile reads the verification columns', () {
    final p = Profile.fromJson({
      'id': 'u1',
      'username': 'anna',
      'verified_at': '2026-10-01T10:00:00Z',
      'verified_kind': 'author',
    });
    expect(p.isVerified, isTrue);
    expect(p.verifiedKind, VerificationKind.author);
    expect(
      Profile.fromJson({'id': 'u2', 'username': 'ben'}).isVerified,
      isFalse,
    );
  });

  testWidgets('verified profile shows a labelled check mark', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _wrap(
        VerifiedBadge(
          profile: Profile(
            id: 'u1',
            username: 'anna',
            verifiedAt: DateTime(2026),
            verifiedKind: VerificationKind.blog,
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.verified), findsOneWidget);
    expect(find.bySemanticsLabel('Verifiziert'), findsOneWidget);
    expect(find.byTooltip('Verifiziert · Buchblog'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('unverified profile shows nothing', (tester) async {
    await tester.pumpWidget(
      _wrap(
        const VerifiedBadge(
          profile: Profile(id: 'u1', username: 'ben'),
        ),
      ),
    );
    expect(find.byIcon(Icons.verified), findsNothing);
  });

  test('request parses owner rows and admin queue rows', () {
    final own = VerificationRequest.fromJson({
      'id': 'r1',
      'kind': 'bookstore',
      'link': 'https://laden.de',
      'status': 'open',
      'created_at': '2026-10-22T10:00:00Z',
    });
    expect((own.kind, own.status), (VerificationKind.bookstore, 'open'));
    final queued = VerificationRequest.fromJson({
      'request_id': 'r2',
      'requested_at': '2026-10-22T10:00:00Z',
      'user_id': 'u1',
      'username': 'anna',
      'kind': 'author',
      'link': 'https://anna.de',
    });
    expect((queued.id, queued.username), ('r2', 'anna'));
  });
}
