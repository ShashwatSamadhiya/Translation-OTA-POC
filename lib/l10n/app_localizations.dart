import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';
import 'app_localizations_te.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
    Locale('te'),
  ];

  /// Heading on the home and sign-in screens
  ///
  /// In en, this message translates to:
  /// **'Welcome to AquaSetu'**
  String get welcomeTitle;

  /// Subheading on the home and sign-in screens
  ///
  /// In en, this message translates to:
  /// **'Your partner for healthier ponds and better harvests.'**
  String get welcomeSubtitle;

  /// Primary button label on the home screen
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get getStarted;

  /// Heading on the language selection screen
  ///
  /// In en, this message translates to:
  /// **'Choose your preferred language'**
  String get chooseLanguage;

  /// Button that retries a failed action
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Countdown until the OTP can be resent
  ///
  /// In en, this message translates to:
  /// **'You can resend the OTP in {time}'**
  String resendOtpIn(String time);

  /// Label of an optional form field
  ///
  /// In en, this message translates to:
  /// **'{label} (Optional)'**
  String optionalField(String label);

  /// Confirmation after a farmer is registered
  ///
  /// In en, this message translates to:
  /// **'{name} registered'**
  String farmerRegistered(String name);

  /// Relative humidity on the weather card
  ///
  /// In en, this message translates to:
  /// **'Humidity {humidity}%'**
  String weatherHumidity(int humidity);

  /// Shown in village search until enough letters are typed
  ///
  /// In en, this message translates to:
  /// **'Type at least {count} letters to search'**
  String typeToSearchVillage(int count);

  /// Shown when a home shortcut tile is tapped before its screen exists
  ///
  /// In en, this message translates to:
  /// **'{title} is coming soon'**
  String launchpadComingSoon(String title);

  /// POC-only plural: number of ponds a farmer owns
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No ponds yet} =1{1 pond} other{{count} ponds}}'**
  String pondCount(int count);

  /// App bar title of the POC screen
  ///
  /// In en, this message translates to:
  /// **'Firebase OTA POC'**
  String get pocTitle;

  /// Label of the language picker
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get pocLanguage;

  /// Shown when no OTA translations are loaded
  ///
  /// In en, this message translates to:
  /// **'Source: bundled ARB'**
  String get pocSourceBundled;

  /// Shown when OTA translations come from the local cache
  ///
  /// In en, this message translates to:
  /// **'Source: device cache'**
  String get pocSourceCache;

  /// Shown when OTA translations were just fetched from Firestore
  ///
  /// In en, this message translates to:
  /// **'Source: Firestore'**
  String get pocSourceNetwork;

  /// Button that re-fetches OTA translations from Firestore
  ///
  /// In en, this message translates to:
  /// **'Fetch from Firestore'**
  String get pocRefresh;

  /// Shown when the Firebase options are missing from env
  ///
  /// In en, this message translates to:
  /// **'Firebase is not configured, showing bundled strings only'**
  String get pocNotConfigured;

  /// Shown when the Firestore fetch fails
  ///
  /// In en, this message translates to:
  /// **'Could not fetch translations: {reason}'**
  String pocRefreshFailed(String reason);

  /// Number of keys currently served from OTA
  ///
  /// In en, this message translates to:
  /// **'{count} keys from OTA'**
  String pocOverriddenKeys(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'mr', 'te'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'mr':
      return AppLocalizationsMr();
    case 'te':
      return AppLocalizationsTe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
