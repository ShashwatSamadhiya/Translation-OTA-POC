import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/ota_translation_bundle.dart';

/// Persists the last good bundle per language so OTA strings survive
/// restarts and work offline.
class OtaLocalDataSource {
  const OtaLocalDataSource(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyPrefix = 'ota_translations_';
  static const String _fetchedAtField = 'fetchedAt';
  static const String _messagesField = 'messages';

  /// Returns null when nothing is cached or the entry is corrupt; corrupt
  /// entries are removed so they are not retried on every launch.
  Future<OtaTranslationBundle?> read(String languageCode) async {
    final key = '$_keyPrefix$languageCode';
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final messages = (json[_messagesField] as Map<String, dynamic>).map(
        (key, value) => MapEntry(key, value as String),
      );
      return OtaTranslationBundle(
        languageCode: languageCode,
        messages: messages,
        fetchedAt: DateTime.parse(json[_fetchedAtField] as String),
      );
    } on Object {
      await _prefs.remove(key);
      return null;
    }
  }

  Future<void> write(OtaTranslationBundle bundle) async {
    await _prefs.setString(
      '$_keyPrefix${bundle.languageCode}',
      jsonEncode({
        _fetchedAtField: bundle.fetchedAt.toIso8601String(),
        _messagesField: bundle.messages,
      }),
    );
  }
}
