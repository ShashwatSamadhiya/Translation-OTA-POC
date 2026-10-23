import 'l10n_key_catalog.dart';

/// Invisible tag appended to every localized string in edit mode, so a tap on
/// rendered text can be traced back to its ARB key.
///
/// A tag is [_start] followed by the key's index in [l10nKeyCatalog] in
/// binary, most significant bit first, written as zero-width characters:
/// [_zero] (ZWNJ) and [_one] (ZWJ).
abstract final class L10nKeyTag {
  static const String _start = '⁣';
  static const String _zero = '‌';
  static const String _one = '‍';

  static final RegExp _pattern = RegExp('$_start([$_zero$_one]+)');

  static final Map<String, int> _indexByKey = {
    for (var i = 0; i < l10nKeyCatalog.length; i++) l10nKeyCatalog[i].name: i,
  };

  static String encode(int index) {
    if (index < 0) throw ArgumentError.value(index, 'index');
    final bits = index.toRadixString(2);
    return _start + bits.replaceAll('0', _zero).replaceAll('1', _one);
  }

  /// Indexes of every tag in [text], in order of appearance.
  static List<int> decode(String text) => [
    for (final match in _pattern.allMatches(text))
      int.parse(
        match.group(1)!.replaceAll(_zero, '0').replaceAll(_one, '1'),
        radix: 2,
      ),
  ];

  /// Appends the tag for [key]; returns [value] unchanged for unknown keys.
  static String tag(String key, String value) {
    final index = _indexByKey[key];
    return index == null ? value : value + encode(index);
  }

  /// Catalog keys tagged in [text], without duplicates, in order.
  static List<String> keysIn(String text) => [
    for (final index in decode(text).toSet())
      if (index < l10nKeyCatalog.length) l10nKeyCatalog[index].name,
  ];

  static String strip(String text) => text.replaceAll(_pattern, '');
}
