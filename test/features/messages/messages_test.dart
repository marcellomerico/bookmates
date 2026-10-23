import 'dart:async';

import 'package:booksquad/features/auth/providers/auth_provider.dart';
import 'package:booksquad/features/messages/presentation/chat_screen.dart';
import 'package:booksquad/features/messages/presentation/inbox_screen.dart';
import 'package:booksquad/features/messages/providers/messages_providers.dart';
import 'package:booksquad/features/social/providers/social_providers.dart';
import 'package:booksquad/models/message.dart';
import 'package:booksquad/models/profile.dart';
import 'package:booksquad/repositories/message_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/auth_fixtures.dart';

class _FakeMessages extends MessageRepository {
  _FakeMessages({this.mutual = true}) : super(offlineClient());
  final bool mutual;
  final list = <Message>[
    Message(
      id: '1',
      conversationId: 'c',
      senderId: 'other',
      body: 'Wie war das Buch?',
      createdAt: DateTime(2026, 10, 23, 9),
    ),
  ];
  final _live = StreamController<List<Message>>.broadcast();
  final reads = <String>[];

  @override
  Future<List<ConversationSummary>> getConversations() async => [
    ConversationSummary.fromJson({
      'conversation_id': 'c',
      'other_id': 'other',
      'last_body': 'Wie war das Buch?',
      'last_sender_id': 'other',
      'last_message_at': '2026-10-23T09:00:00Z',
      'unread': true,
      'can_send': true,
    }),
  ];

  @override
  Stream<List<Message>> watchMessages(String conversationId) async* {
    yield List.of(list);
    yield* _live.stream;
  }

  @override
  Future<void> send(String conversationId, String body) async {
    list.add(
      Message(
        id: '${list.length + 1}',
        conversationId: conversationId,
        senderId: 'me',
        body: body,
        createdAt: DateTime(2026, 10, 23, 10),
      ),
    );
    _live.add(List.of(list));
  }

  @override
  Future<void> markRead(String conversationId) async =>
      reads.add(conversationId);

  @override
  Future<bool> isMutual(String me, String other) async => mutual;
}

List<Override> _overrides(_FakeMessages repo) => [
  currentUserProvider.overrideWithValue(testUser('me')),
  messageRepositoryProvider.overrideWithValue(repo),
  profileByIdProvider.overrideWith(
    (ref, id) async => Profile(id: id, username: 'lena', displayName: 'Lena'),
  ),
];

void main() {
  testWidgets('inbox marks unread conversations', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(_FakeMessages()),
        child: const MaterialApp(home: InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lena'), findsOneWidget);
    expect(find.text('Wie war das Buch?'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Ungelesen')), findsOneWidget);
  });

  testWidgets('chat shows history, sends and marks read', (tester) async {
    final repo = _FakeMessages();
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(repo),
        child: const MaterialApp(
          home: ChatScreen(conversationId: 'c', otherId: 'other'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wie war das Buch?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Großartig!');
    await tester.tap(find.byTooltip('Senden'));
    await tester.pumpAndSettle();

    expect(find.text('Großartig!'), findsOneWidget);
    expect(repo.reads, isNotEmpty);
  });

  testWidgets('no input once the mutual follow ended', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides(_FakeMessages(mutual: false)),
        child: const MaterialApp(
          home: ChatScreen(conversationId: 'c', otherId: 'other'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('nicht mehr gegenseitig'), findsOneWidget);
  });
}
