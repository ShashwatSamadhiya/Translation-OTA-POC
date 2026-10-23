/// Firestore layout shared by app delivery and the in-context editor. Keep
/// in sync with `firestore.rules`.
abstract final class TranslationsFirestore {
  /// `{lang}` documents every app build reads.
  static const String published = 'translations_published';

  /// `{lang}` documents editors change; only editors can read them.
  static const String draft = 'translations_draft';

  /// Append-only audit log: edit, import and publish entries.
  static const String history = 'translation_history';

  /// `{uid}` documents, created in the console, that mark editors.
  static const String editors = 'editors';

  static const String messagesField = 'messages';
}

/// Reads the `messages` map of a translations document.
///
/// A missing document means "no OTA strings yet" and gives an empty map.
/// Non-string values are skipped so one bad value only drops that key.
/// Throws [FormatException] when `messages` is present but not a map.
Map<String, String> parseMessages(Map<String, dynamic>? data) {
  final messages = data?[TranslationsFirestore.messagesField];
  if (messages == null) return const {};
  if (messages is! Map) {
    throw const FormatException('"messages" is not a map');
  }
  return {
    for (final MapEntry(:key, :value) in messages.entries)
      if (key is String && value is String) key: value,
  };
}
