// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: lib/l10n/app_localizations.dart
// Regenerate: fvm dart run tool/gen_ota_localizations.dart

import '../../../../../l10n/app_localizations.dart';
import '../../../../core/l10n/icu_message_formatter.dart';

/// [AppLocalizations] that prefers strings delivered over the air and
/// falls back to the bundled ARB string per key when the OTA string
/// is missing, empty or malformed.
class OtaAppLocalizations extends AppLocalizations {
  OtaAppLocalizations({
    required AppLocalizations bundled,
    required this._messages,
  }) : _bundled = bundled,
       super(bundled.localeName);

  final AppLocalizations _bundled;
  final Map<String, String> _messages;

  String _resolve(
    String key,
    String Function() fallback, [
    Map<String, Object> args = const {},
  ]) {
    final message = _messages[key];
    if (message == null || message.isEmpty) return fallback();
    return IcuMessageFormatter.format(
          message,
          locale: localeName,
          args: args,
        ) ??
        fallback();
  }

  @override
  String get welcomeTitle =>
      _resolve('welcomeTitle', () => _bundled.welcomeTitle);

  @override
  String get welcomeSubtitle =>
      _resolve('welcomeSubtitle', () => _bundled.welcomeSubtitle);

  @override
  String get getStarted => _resolve('getStarted', () => _bundled.getStarted);

  @override
  String get chooseLanguage =>
      _resolve('chooseLanguage', () => _bundled.chooseLanguage);

  @override
  String get retry => _resolve('retry', () => _bundled.retry);

  @override
  String resendOtpIn(String time) =>
      _resolve('resendOtpIn', () => _bundled.resendOtpIn(time), {'time': time});

  @override
  String optionalField(String label) => _resolve(
    'optionalField',
    () => _bundled.optionalField(label),
    {'label': label},
  );

  @override
  String farmerRegistered(String name) => _resolve(
    'farmerRegistered',
    () => _bundled.farmerRegistered(name),
    {'name': name},
  );

  @override
  String weatherHumidity(int humidity) => _resolve(
    'weatherHumidity',
    () => _bundled.weatherHumidity(humidity),
    {'humidity': humidity},
  );

  @override
  String typeToSearchVillage(int count) => _resolve(
    'typeToSearchVillage',
    () => _bundled.typeToSearchVillage(count),
    {'count': count},
  );

  @override
  String launchpadComingSoon(String title) => _resolve(
    'launchpadComingSoon',
    () => _bundled.launchpadComingSoon(title),
    {'title': title},
  );

  @override
  String pondCount(int count) =>
      _resolve('pondCount', () => _bundled.pondCount(count), {'count': count});

  @override
  String get pocTitle => _resolve('pocTitle', () => _bundled.pocTitle);

  @override
  String get pocLanguage => _resolve('pocLanguage', () => _bundled.pocLanguage);

  @override
  String get pocSourceBundled =>
      _resolve('pocSourceBundled', () => _bundled.pocSourceBundled);

  @override
  String get pocSourceCache =>
      _resolve('pocSourceCache', () => _bundled.pocSourceCache);

  @override
  String get pocSourceNetwork =>
      _resolve('pocSourceNetwork', () => _bundled.pocSourceNetwork);

  @override
  String get pocRefresh => _resolve('pocRefresh', () => _bundled.pocRefresh);

  @override
  String get pocCdnNotConfigured =>
      _resolve('pocCdnNotConfigured', () => _bundled.pocCdnNotConfigured);

  @override
  String pocRefreshFailed(String reason) => _resolve(
    'pocRefreshFailed',
    () => _bundled.pocRefreshFailed(reason),
    {'reason': reason},
  );

  @override
  String pocOverriddenKeys(int count) => _resolve(
    'pocOverriddenKeys',
    () => _bundled.pocOverriddenKeys(count),
    {'count': count},
  );
}
