/// One ARB key as described by the template ARB, used by the in-context
/// editor. Instances are generated into `l10n_key_catalog.dart`.
class L10nKeyInfo {
  const L10nKeyInfo({
    required this.name,
    required this.description,
    required this.placeholders,
    required this.bundled,
    required this.otaEnabled,
  });

  final String name;
  final String description;
  final List<L10nPlaceholder> placeholders;

  /// Raw ICU message per language code, as written in the bundled ARB files.
  final Map<String, String> bundled;

  /// False for keys the app always takes from the bundled ARB (formatted
  /// placeholders, unsupported types), so editing them has no effect.
  final bool otaEnabled;

  Set<String> get placeholderNames => {for (final p in placeholders) p.name};

  /// Arguments for previewing a message: the ARB `example`, otherwise a
  /// value that fits the type.
  Map<String, Object> get exampleArgs => {
    for (final p in placeholders) p.name: p.exampleValue,
  };
}

class L10nPlaceholder {
  const L10nPlaceholder({required this.name, required this.type, this.example});

  final String name;
  final String type;
  final String? example;

  bool get isNumeric => const {'int', 'num', 'double'}.contains(type);

  Object get exampleValue {
    final example = this.example;
    if (isNumeric) return num.tryParse(example ?? '') ?? 3;
    return example ?? name;
  }
}
