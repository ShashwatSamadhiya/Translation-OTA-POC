// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppLocalizationsMr extends AppLocalizations {
  AppLocalizationsMr([String locale = 'mr']) : super(locale);

  @override
  String get welcomeTitle => 'ॲक्वासेतुमध्ये आपले स्वागत आहे';

  @override
  String get welcomeSubtitle =>
      'निरोगी तलाव आणि चांगल्या उत्पादनासाठी तुमचा साथीदार.';

  @override
  String get getStarted => 'सुरू करा';

  @override
  String get chooseLanguage => 'तुमची आवडती भाषा निवडा';

  @override
  String get retry => 'पुन्हा प्रयत्न करा';

  @override
  String resendOtpIn(String time) {
    return 'तुम्ही $time नंतर OTP पुन्हा पाठवू शकता';
  }

  @override
  String optionalField(String label) {
    return '$label (ऐच्छिक)';
  }

  @override
  String farmerRegistered(String name) {
    return '$name यांची नोंदणी झाली';
  }

  @override
  String weatherHumidity(int humidity) {
    return 'आर्द्रता $humidity%';
  }

  @override
  String typeToSearchVillage(int count) {
    return 'शोधण्यासाठी किमान $count अक्षरे टाइप करा';
  }

  @override
  String launchpadComingSoon(String title) {
    return '$title लवकरच येत आहे';
  }

  @override
  String pondCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count तलाव',
      one: '1 तलाव',
      zero: 'अजून एकही तलाव नाही',
    );
    return '$_temp0';
  }

  @override
  String get pocTitle => 'Firebase OTA POC';

  @override
  String get pocLanguage => 'भाषा';

  @override
  String get pocSourceBundled => 'स्रोत: ॲपमधील ARB';

  @override
  String get pocSourceCache => 'स्रोत: डिव्हाइस कॅशे';

  @override
  String get pocSourceNetwork => 'स्रोत: Firestore';

  @override
  String get pocRefresh => 'Firestore वरून आणा';

  @override
  String get pocNotConfigured =>
      'Firebase कॉन्फिगर केलेले नाही, फक्त ॲपमधील मजकूर दाखवत आहे';

  @override
  String pocRefreshFailed(String reason) {
    return 'भाषांतरे आणता आली नाहीत: $reason';
  }

  @override
  String pocOverriddenKeys(int count) {
    return 'OTA मधून $count की';
  }
}
