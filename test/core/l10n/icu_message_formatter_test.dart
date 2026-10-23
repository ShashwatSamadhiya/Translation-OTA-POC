import 'package:flutter_test/flutter_test.dart';
import 'package:tolgee_poc/src/core/l10n/icu_message_formatter.dart';

void main() {
  String? format(
    String message, {
    String locale = 'en',
    Map<String, Object> args = const {},
  }) => IcuMessageFormatter.format(message, locale: locale, args: args);

  group('plain text and placeholders', () {
    test('returns plain text unchanged', () {
      expect(format('Retry'), 'Retry');
    });

    test('keeps apostrophes literally like gen-l10n', () {
      expect(format("Farmer's pond"), "Farmer's pond");
    });

    test('substitutes placeholders', () {
      expect(
        format('{name} पंजीकृत हो गए', args: {'name': 'Ramesh'}),
        'Ramesh पंजीकृत हो गए',
      );
    });

    test('substitutes int placeholders', () {
      expect(format('Humidity {h}%', args: {'h': 72}), 'Humidity 72%');
    });

    test('returns null when an argument is missing (a typo in the translation)', () {
      expect(format('Humidity {humidty}%', args: {'humidity': 72}), isNull);
    });

    test('returns null on unbalanced braces', () {
      expect(format('Hello {name'), isNull);
      expect(format('Hello name}'), isNull);
    });

    test('returns null on unsupported argument types', () {
      expect(format('{n, number}', args: {'n': 1}), isNull);
    });
  });

  group('plural', () {
    const message =
        '{count, plural, =0{No ponds yet} =1{1 pond} other{{count} ponds}}';

    test('prefers exact =N branches', () {
      expect(format(message, args: {'count': 0}), 'No ponds yet');
      expect(format(message, args: {'count': 1}), '1 pond');
    });

    test('falls back to other', () {
      expect(format(message, args: {'count': 5}), '5 ponds');
    });

    test('replaces # with the value', () {
      expect(
        format('{c, plural, one{# pond} other{# ponds}}', args: {'c': 3}),
        '3 ponds',
      );
    });

    test('uses CLDR categories per locale (Hindi treats 0 as one)', () {
      const hi = '{c, plural, one{एक या शून्य} other{अनेक}}';
      expect(format(hi, locale: 'hi', args: {'c': 0}), 'एक या शून्य');
      expect(format(hi, locale: 'en', args: {'c': 0}), 'अनेक');
    });

    test('returns null without an other branch', () {
      expect(format('{c, plural, one{x}}', args: {'c': 1}), isNull);
    });

    test('returns null when the plural argument is not a number', () {
      expect(format(message, args: {'count': 'two'}), isNull);
    });
  });

  group('select', () {
    const message = '{role, select, farmer{Farmer} other{Staff}}';

    test('picks the matching branch', () {
      expect(format(message, args: {'role': 'farmer'}), 'Farmer');
    });

    test('falls back to other', () {
      expect(format(message, args: {'role': 'admin'}), 'Staff');
    });
  });

  group('argumentNames', () {
    test('collects plain, plural and nested arguments', () {
      expect(
        IcuMessageFormatter.argumentNames(
          '{name}: {count, plural, =0{none} other{# {unit}}}',
        ),
        {'name', 'count', 'unit'},
      );
    });

    test('returns an empty set for plain text', () {
      expect(IcuMessageFormatter.argumentNames('Retry'), isEmpty);
    });

    test('throws on invalid syntax', () {
      expect(
        () => IcuMessageFormatter.argumentNames('{count, plural, one{x}'),
        throwsFormatException,
      );
    });
  });
}
