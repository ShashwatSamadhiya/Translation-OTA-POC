import 'package:flutter_test/flutter_test.dart';
import 'package:tolgee_poc/src/core/l10n/l10n_key_catalog.dart';
import 'package:tolgee_poc/src/features/l10n_editor/domain/validate_message.dart';

void main() {
  final pondCount = l10nKeyCatalog.firstWhere((k) => k.name == 'pondCount');
  final farmerRegistered = l10nKeyCatalog.firstWhere(
    (k) => k.name == 'farmerRegistered',
  );
  final retry = l10nKeyCatalog.firstWhere((k) => k.name == 'retry');

  test('accepts every bundled message', () {
    for (final key in l10nKeyCatalog) {
      for (final MapEntry(key: lang, value: message) in key.bundled.entries) {
        expect(
          validateMessage(message, key, locale: lang),
          isNull,
          reason: '$lang:${key.name}',
        );
      }
    }
  });

  test('rejects empty text', () {
    expect(validateMessage('  ', retry), contains('empty'));
  });

  test('rejects invalid ICU', () {
    expect(
      validateMessage('{count, plural, =0{none}', pondCount),
      contains('Invalid ICU'),
    );
  });

  test('rejects a misspelled placeholder', () {
    expect(
      validateMessage('{nmae} registered', farmerRegistered),
      contains('Unknown placeholder {nmae}'),
    );
  });

  test('rejects a missing placeholder', () {
    expect(
      validateMessage('Farmer registered', farmerRegistered),
      contains('Missing placeholder {name}'),
    );
  });

  test('rejects placeholders on a key without any', () {
    expect(
      validateMessage('Retry {x}', retry),
      contains('has no placeholders'),
    );
  });

  test('rejects a plural on a text placeholder', () {
    expect(
      validateMessage('{name, plural, other{x}}', farmerRegistered),
      contains('does not render'),
    );
  });
}
