import 'package:booksquad/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateUsername', () {
    for (final ok in ['max', 'lese_ratte', 'anna.k', 'a1b2c3', 'x' * 24]) {
      test('accepts $ok', () => expect(validateUsername(ok), isNull));
    }
    for (final bad in ['', 'ab', 'Max', 'max mustermann', 'müller', 'max-m', 'x' * 25]) {
      test('rejects "$bad"', () => expect(validateUsername(bad), isNotNull));
    }
  });

  group('sanitizeSearchTerm', () {
    test('strips PostgREST/LIKE control characters', () {
      expect(sanitizeSearchTerm('a,b(c)%d*e\\f"g'), 'a b c  d e f g');
    });
    test('keeps dots and underscores used in usernames', () {
      expect(sanitizeSearchTerm(' anna.k_1 '), 'anna.k_1');
    });
  });
}
