// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Telugu (`te`).
class AppLocalizationsTe extends AppLocalizations {
  AppLocalizationsTe([String locale = 'te']) : super(locale);

  @override
  String get welcomeTitle => 'ఆక్వాసేతుకు స్వాగతం';

  @override
  String get welcomeSubtitle =>
      'ఆరోగ్యకరమైన చెరువులు మరియు మంచి దిగుబడి కోసం మీ తోడు.';

  @override
  String get getStarted => 'ప్రారంభించండి';

  @override
  String get chooseLanguage => 'మీకు నచ్చిన భాషను ఎంచుకోండి';

  @override
  String get retry => 'మళ్ళీ ప్రయత్నించండి';

  @override
  String resendOtpIn(String time) {
    return 'మీరు $time తర్వాత OTP మళ్ళీ పంపవచ్చు';
  }

  @override
  String optionalField(String label) {
    return '$label (ఐచ్ఛికం)';
  }

  @override
  String farmerRegistered(String name) {
    return '$name నమోదు చేయబడ్డారు';
  }

  @override
  String weatherHumidity(int humidity) {
    return 'తేమ $humidity%';
  }

  @override
  String typeToSearchVillage(int count) {
    return 'వెతకడానికి కనీసం $count అక్షరాలు టైప్ చేయండి';
  }

  @override
  String launchpadComingSoon(String title) {
    return '$title త్వరలో వస్తోంది';
  }

  @override
  String pondCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count చెరువులు',
      one: '1 చెరువు',
      zero: 'ఇంకా చెరువులు లేవు',
    );
    return '$_temp0';
  }

  @override
  String get pocTitle => 'Tolgee OTA POC';

  @override
  String get pocLanguage => 'భాష';

  @override
  String get pocSourceBundled => 'మూలం: యాప్‌లోని ARB';

  @override
  String get pocSourceCache => 'మూలం: పరికర కాష్';

  @override
  String get pocSourceNetwork => 'మూలం: Tolgee CDN';

  @override
  String get pocRefresh => 'CDN నుండి తీసుకురండి';

  @override
  String get pocCdnNotConfigured =>
      'TOLGEE_CDN_URL సెట్ చేయలేదు, యాప్‌లోని పాఠ్యం మాత్రమే చూపిస్తోంది';

  @override
  String pocRefreshFailed(String reason) {
    return 'అనువాదాలు తీసుకురాలేకపోయాము: $reason';
  }

  @override
  String pocOverriddenKeys(int count) {
    return 'OTA నుండి $count కీలు';
  }
}
