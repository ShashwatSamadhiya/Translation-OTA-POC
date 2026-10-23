// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get welcomeTitle => 'एक्वासेतु में आपका स्वागत है';

  @override
  String get welcomeSubtitle => 'स्वस्थ तालाबों और बेहतर फसल के लिए आपका साथी।';

  @override
  String get getStarted => 'शुरू करें';

  @override
  String get chooseLanguage => 'अपनी पसंदीदा भाषा चुनें';

  @override
  String get retry => 'फिर से प्रयास करें';

  @override
  String resendOtpIn(String time) {
    return 'आप $time में OTP दोबारा भेज सकते हैं';
  }

  @override
  String optionalField(String label) {
    return '$label (वैकल्पिक)';
  }

  @override
  String farmerRegistered(String name) {
    return '$name पंजीकृत हो गए';
  }

  @override
  String weatherHumidity(int humidity) {
    return 'नमी $humidity%';
  }

  @override
  String typeToSearchVillage(int count) {
    return 'खोजने के लिए कम से कम $count अक्षर लिखें';
  }

  @override
  String launchpadComingSoon(String title) {
    return '$title जल्द आ रहा है';
  }

  @override
  String pondCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count तालाब',
      one: '1 तालाब',
      zero: 'अभी कोई तालाब नहीं',
    );
    return '$_temp0';
  }

  @override
  String get pocTitle => 'Firebase OTA POC';

  @override
  String get pocLanguage => 'भाषा';

  @override
  String get pocSourceBundled => 'स्रोत: ऐप में शामिल ARB';

  @override
  String get pocSourceCache => 'स्रोत: डिवाइस कैश';

  @override
  String get pocSourceNetwork => 'स्रोत: Firestore';

  @override
  String get pocRefresh => 'Firestore से लाएं';

  @override
  String get pocNotConfigured =>
      'Firebase कॉन्फ़िगर नहीं है, केवल ऐप में शामिल टेक्स्ट दिखाया जा रहा है';

  @override
  String pocRefreshFailed(String reason) {
    return 'अनुवाद नहीं लाए जा सके: $reason';
  }

  @override
  String pocOverriddenKeys(int count) {
    return 'OTA से $count कुंजियाँ';
  }
}
