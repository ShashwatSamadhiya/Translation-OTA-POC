import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n_in_context/l10n_in_context.dart';
import 'package:tolgee_poc/l10n/app_localizations.dart';
import 'package:tolgee_poc/l10n/app_localizations_override.dart';

void main() {
  const hindi = Locale('hi');
  final bundled = lookupAppLocalizations(hindi);

  Future<AppLocalizations> load(
    Map<String, String> messages, {
    bool tagKeys = false,
  }) => AppLocalizationsOverrideDelegate(
    messages: {hindi.languageCode: messages},
    tagKeys: tagKeys,
  ).load(hindi);

  test('uses OTA strings and falls back per key', () async {
    final l10n = await load({
      'retry': 'दोबारा कोशिश करें',
      'weatherHumidity': 'नमी {humidty}%',
    });
    expect(l10n.retry, 'दोबारा कोशिश करें');
    expect(l10n.getStarted, bundled.getStarted);
    expect(l10n.weatherHumidity(72), bundled.weatherHumidity(72));
  });

  test('formats OTA placeholders and plurals', () async {
    final l10n = await load({
      'farmerRegistered': '{name} का पंजीकरण हो गया',
      'pondCount': '{count, plural, =0{कोई नहीं} other{# तालाब}}',
    });
    expect(l10n.farmerRegistered('Ramesh'), 'Ramesh का पंजीकरण हो गया');
    expect(l10n.pondCount(0), 'कोई नहीं');
    expect(l10n.pondCount(4), '4 तालाब');
  });

  test('edit mode tags every string without changing its text', () async {
    final l10n = await load(const {}, tagKeys: true);
    expect(l10n.pondCount(2), isNot(bundled.pondCount(2)));
    expect(L10nKeyTag.strip(l10n.pondCount(2)), bundled.pondCount(2));
  });

  test('the catalog lists every ARB key and language', () {
    expect(
      appLocalizationsCatalog.languages,
      AppLocalizations.supportedLocales.map((l) => l.languageCode),
    );
    expect(appLocalizationsCatalog.lookup('pondCount')?.placeholderNames, {
      'count',
    });
  });

  test('every bundled message passes editor validation', () {
    const validate = ValidateMessage();
    for (final key in appLocalizationsCatalog.keys) {
      for (final MapEntry(key: lang, value: message) in key.bundled.entries) {
        expect(
          validate(message, key, locale: lang),
          isNull,
          reason: '$lang:${key.name}',
        );
      }
    }
  });
}
