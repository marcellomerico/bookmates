import 'package:booksquad/features/books/presentation/reading_progress_sheet.dart';
import 'package:booksquad/models/user_book.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

UserBook _entry({int? current, int? total}) => UserBook(
  id: 'ub1',
  userId: 'u1',
  bookId: 'b1',
  status: BookStatus.reading,
  currentPage: current,
  pageCount: total,
);

void main() {
  test('progress needs both page numbers and stays within 0..1', () {
    expect(_entry(current: 50).progress, isNull);
    expect(_entry(total: 100).progress, isNull);
    expect(_entry(current: 25, total: 100).progress, 0.25);
    expect(_entry(current: 0, total: 100).progress, 0);
  });

  test('page numbers are read from the database row', () {
    final e = UserBook.fromJson({
      'id': 'ub1',
      'user_id': 'u1',
      'book_id': 'b1',
      'status': 'reading',
      'page_count': 320,
      'current_page': 187,
    });
    expect((e.currentPage, e.pageCount), (187, 320));
  });

  test('copyWith can clear page numbers', () {
    final e = _entry(current: 10, total: 100);
    final cleared = e.copyWith(currentPage: () => null, pageCount: () => null);
    expect((cleared.currentPage, cleared.pageCount), (null, null));
    expect(e.copyWith(status: BookStatus.read).currentPage, 10);
  });

  test('validation rejects impossible input', () {
    expect(validateReadingProgress(currentPage: 10, pageCount: 100), isNull);
    expect(validateReadingProgress(currentPage: null, pageCount: null), isNull);
    expect(
      validateReadingProgress(currentPage: 101, pageCount: 100),
      isNotNull,
    );
    expect(validateReadingProgress(pageCount: 0), isNotNull);
    expect(validateReadingProgress(pageCount: 20001), isNotNull);
  });

  test('label shows what is known', () {
    expect(readingProgressLabel(_entry()), 'Lesefortschritt eintragen');
    expect(readingProgressLabel(_entry(current: 42)), 'Seite 42');
    expect(readingProgressLabel(_entry(total: 300)), '300 Seiten');
    expect(
      readingProgressLabel(_entry(current: 150, total: 300)),
      'Seite 150 von 300 · 50 %',
    );
  });

  testWidgets('sheet validates and returns the entered pages', (tester) async {
    ReadingProgress? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await showReadingProgressSheet(context, _entry()),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Aktuelle Seite'),
      '400',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Seitenzahl'), '300');
    await tester.pump();
    expect(find.byType(Slider), findsOneWidget);
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(
      find.text('Die aktuelle Seite ist größer als die Seitenzahl.'),
      findsOneWidget,
    );
    expect(result, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Aktuelle Seite'),
      '120',
    );
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(result, (currentPage: 120, pageCount: 300));
  });
}
