// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get welcomeTitle => 'Welcome to AquaSetu';

  @override
  String get welcomeSubtitle =>
      'Your partner for healthier ponds and better harvests.';

  @override
  String get getStarted => 'Get started';

  @override
  String get chooseLanguage => 'Choose your preferred language';

  @override
  String get retry => 'Retry';

  @override
  String resendOtpIn(String time) {
    return 'You can resend the OTP in $time';
  }

  @override
  String optionalField(String label) {
    return '$label (Optional)';
  }

  @override
  String farmerRegistered(String name) {
    return '$name registered';
  }

  @override
  String weatherHumidity(int humidity) {
    return 'Humidity $humidity%';
  }

  @override
  String typeToSearchVillage(int count) {
    return 'Type at least $count letters to search';
  }

  @override
  String launchpadComingSoon(String title) {
    return '$title is coming soon';
  }

  @override
  String pondCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ponds',
      one: '1 pond',
      zero: 'No ponds yet',
    );
    return '$_temp0';
  }

  @override
  String get pocTitle => 'Tolgee OTA POC';

  @override
  String get pocLanguage => 'Language';

  @override
  String get pocSourceBundled => 'Source: bundled ARB';

  @override
  String get pocSourceCache => 'Source: device cache';

  @override
  String get pocSourceNetwork => 'Source: Tolgee CDN';

  @override
  String get pocRefresh => 'Fetch from CDN';

  @override
  String get pocCdnNotConfigured =>
      'TOLGEE_CDN_URL is not set, showing bundled strings only';

  @override
  String pocRefreshFailed(String reason) {
    return 'Could not fetch translations: $reason';
  }

  @override
  String pocOverriddenKeys(int count) {
    return '$count keys from OTA';
  }
}
