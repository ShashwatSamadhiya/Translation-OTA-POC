import 'package:flutter_test/flutter_test.dart';
import 'package:tolgee_poc/src/core/firebase/translations_firestore.dart';

void main() {
  test('reads string messages', () {
    expect(
      parseMessages({
        'messages': {'retry': 'Retry'},
        'publishedAt': 'ignored',
      }),
      {'retry': 'Retry'},
    );
  });

  test('treats a missing document or field as no messages', () {
    expect(parseMessages(null), isEmpty);
    expect(parseMessages({'publishedBy': 'uid'}), isEmpty);
  });

  test('skips non-string values', () {
    expect(
      parseMessages({
        'messages': {
          'retry': 'Retry',
          'count': 3,
          'nested': <String, Object>{},
        },
      }),
      {'retry': 'Retry'},
    );
  });

  test('throws when messages is not a map', () {
    expect(() => parseMessages({'messages': 'oops'}), throwsFormatException);
  });
}
