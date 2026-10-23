import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tolgee_poc/l10n/app_localizations.dart';
import 'package:tolgee_poc/src/core/l10n/l10n_key_tag.dart';
import 'package:tolgee_poc/src/features/ota_translations/domain/entities/ota_translation_bundle.dart';
import 'package:tolgee_poc/src/features/ota_translations/presentation/l10n/ota_localizations_delegate.dart';

void main() {
  const hindi = Locale('hi');
  final bundled = lookupAppLocalizations(hindi);

  OtaTranslationBundle bundle(Map<String, String> messages, {String? lang}) =>
      OtaTranslationBundle(
        languageCode: lang ?? hindi.languageCode,
        messages: messages,
        fetchedAt: DateTime(2026, 10, 22),
      );

  Future<AppLocalizations> load(OtaTranslationBundle? b) =>
      OtaLocalizationsDelegate(b).load(hindi);

  test('uses the OTA string when present', () async {
    final l10n = await load(bundle({'retry': 'दोबारा कोशिश करें'}));
    expect(l10n.retry, 'दोबारा कोशिश करें');
  });

  test('falls back per key when the OTA string is missing', () async {
    final l10n = await load(bundle({'retry': 'X'}));
    expect(l10n.getStarted, bundled.getStarted);
  });

  test('falls back when the OTA string is empty', () async {
    final l10n = await load(bundle({'retry': ''}));
    expect(l10n.retry, bundled.retry);
  });

  test('falls back when the OTA string is malformed', () async {
    final l10n = await load(bundle({'weatherHumidity': 'नमी {humidty}%'}));
    expect(l10n.weatherHumidity(72), bundled.weatherHumidity(72));
  });

  test('formats OTA placeholders and plurals', () async {
    final l10n = await load(
      bundle({
        'farmerRegistered': '{name} का पंजीकरण हो गया',
        'pondCount': '{count, plural, =0{कोई नहीं} other{# तालाब}}',
      }),
    );
    expect(l10n.farmerRegistered('Ramesh'), 'Ramesh का पंजीकरण हो गया');
    expect(l10n.pondCount(0), 'कोई नहीं');
    expect(l10n.pondCount(4), '4 तालाब');
  });

  test('ignores a bundle for another language', () async {
    final l10n = await load(bundle({'retry': 'Try again'}, lang: 'en'));
    expect(l10n.retry, bundled.retry);
  });

  test('uses bundled strings when there is no bundle', () async {
    final l10n = await load(null);
    expect(l10n.retry, bundled.retry);
  });

  test('reloads only when the bundle changes', () {
    final a = OtaLocalizationsDelegate(bundle({'retry': 'A'}));
    expect(
      OtaLocalizationsDelegate(bundle({'retry': 'A'})).shouldReload(a),
      isFalse,
    );
    expect(
      OtaLocalizationsDelegate(bundle({'retry': 'B'})).shouldReload(a),
      isTrue,
    );
  });

  group('edit mode', () {
    Future<AppLocalizations> loadTagged(OtaTranslationBundle? b) =>
        OtaLocalizationsDelegate(b, tagKeys: true).load(hindi);

    test('tags OTA strings with their key', () async {
      final l10n = await loadTagged(bundle({'retry': 'फिर से'}));
      expect(L10nKeyTag.keysIn(l10n.retry), ['retry']);
      expect(L10nKeyTag.strip(l10n.retry), 'फिर से');
    });

    test('tags bundled strings even without a bundle', () async {
      final l10n = await loadTagged(null);
      expect(L10nKeyTag.keysIn(l10n.pondCount(2)), ['pondCount']);
      expect(L10nKeyTag.strip(l10n.pondCount(2)), bundled.pondCount(2));
    });

    test('does not tag outside edit mode', () async {
      final l10n = await load(bundle({'retry': 'फिर से'}));
      expect(l10n.retry, 'फिर से');
    });

    test('reloads when tagging is switched', () {
      expect(
        const OtaLocalizationsDelegate(
          null,
          tagKeys: true,
        ).shouldReload(const OtaLocalizationsDelegate(null)),
        isTrue,
      );
    });
  });
}
