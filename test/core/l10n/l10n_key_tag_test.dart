import 'package:flutter_test/flutter_test.dart';
import 'package:tolgee_poc/src/core/l10n/l10n_key_catalog.dart';
import 'package:tolgee_poc/src/core/l10n/l10n_key_tag.dart';

void main() {
  test('round-trips indexes, including 0 and multi-bit values', () {
    for (final index in [0, 1, 2, 5, 150, 1023]) {
      expect(L10nKeyTag.decode('x${L10nKeyTag.encode(index)}'), [index]);
    }
  });

  test('is invisible: only zero-width and format characters', () {
    final tag = L10nKeyTag.encode(150);
    expect(
      tag.runes.every((r) => {0x2063, 0x200C, 0x200D}.contains(r)),
      isTrue,
    );
  });

  test('finds every tag in concatenated text', () {
    final text =
        '${L10nKeyTag.tag('retry', 'Retry')} · '
        '${L10nKeyTag.tag('getStarted', 'Go')}';
    expect(L10nKeyTag.keysIn(text), ['retry', 'getStarted']);
    expect(L10nKeyTag.strip(text), 'Retry · Go');
  });

  test('leaves unknown keys and untagged text alone', () {
    expect(L10nKeyTag.tag('notAKey', 'x'), 'x');
    expect(L10nKeyTag.keysIn('plain'), isEmpty);
  });

  test('ignores indexes outside the catalog', () {
    expect(
      L10nKeyTag.keysIn('x${L10nKeyTag.encode(l10nKeyCatalog.length)}'),
      isEmpty,
    );
  });

  test('rejects negative indexes', () {
    expect(() => L10nKeyTag.encode(-1), throwsArgumentError);
  });
}
