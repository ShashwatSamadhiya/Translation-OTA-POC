// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: the ARB files in l10n.yaml `arb-dir`
// Regenerate: fvm dart run tool/gen_ota_localizations.dart

import 'l10n_key_info.dart';

/// Every ARB key in template order. The index of a key is what
/// the edit-mode tag encodes, so it is only stable within a build.
const List<L10nKeyInfo> l10nKeyCatalog = [
  L10nKeyInfo(
    name: 'welcomeTitle',
    description: 'Heading on the home and sign-in screens',
    placeholders: [],
    bundled: {
      'en': 'Welcome to AquaSetu',
      'hi': 'एक्वासेतु में आपका स्वागत है',
      'mr': 'ॲक्वासेतुमध्ये आपले स्वागत आहे',
      'te': 'ఆక్వాసేతుకు స్వాగతం',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'welcomeSubtitle',
    description: 'Subheading on the home and sign-in screens',
    placeholders: [],
    bundled: {
      'en': 'Your partner for healthier ponds and better harvests.',
      'hi': 'स्वस्थ तालाबों और बेहतर फसल के लिए आपका साथी।',
      'mr': 'निरोगी तलाव आणि चांगल्या उत्पादनासाठी तुमचा साथीदार.',
      'te': 'ఆరోగ్యకరమైన చెరువులు మరియు మంచి దిగుబడి కోసం మీ తోడు.',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'getStarted',
    description: 'Primary button label on the home screen',
    placeholders: [],
    bundled: {
      'en': 'Get started',
      'hi': 'शुरू करें',
      'mr': 'सुरू करा',
      'te': 'ప్రారంభించండి',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'chooseLanguage',
    description: 'Heading on the language selection screen',
    placeholders: [],
    bundled: {
      'en': 'Choose your preferred language',
      'hi': 'अपनी पसंदीदा भाषा चुनें',
      'mr': 'तुमची आवडती भाषा निवडा',
      'te': 'మీకు నచ్చిన భాషను ఎంచుకోండి',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'retry',
    description: 'Button that retries a failed action',
    placeholders: [],
    bundled: {
      'en': 'Retry',
      'hi': 'फिर से प्रयास करें',
      'mr': 'पुन्हा प्रयत्न करा',
      'te': 'మళ్ళీ ప్రయత్నించండి',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'resendOtpIn',
    description: 'Countdown until the OTP can be resent',
    placeholders: [
      L10nPlaceholder(name: 'time', type: 'String', example: '04:59'),
    ],
    bundled: {
      'en': 'You can resend the OTP in {time}',
      'hi': 'आप {time} में OTP दोबारा भेज सकते हैं',
      'mr': 'तुम्ही {time} नंतर OTP पुन्हा पाठवू शकता',
      'te': 'మీరు {time} తర్వాత OTP మళ్ళీ పంపవచ్చు',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'optionalField',
    description: 'Label of an optional form field',
    placeholders: [
      L10nPlaceholder(name: 'label', type: 'String', example: 'Pincode'),
    ],
    bundled: {
      'en': '{label} (Optional)',
      'hi': '{label} (वैकल्पिक)',
      'mr': '{label} (ऐच्छिक)',
      'te': '{label} (ఐచ్ఛికం)',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'farmerRegistered',
    description: 'Confirmation after a farmer is registered',
    placeholders: [
      L10nPlaceholder(name: 'name', type: 'String', example: 'Ramesh Patil'),
    ],
    bundled: {
      'en': '{name} registered',
      'hi': '{name} पंजीकृत हो गए',
      'mr': '{name} यांची नोंदणी झाली',
      'te': '{name} నమోదు చేయబడ్డారు',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'weatherHumidity',
    description: 'Relative humidity on the weather card',
    placeholders: [L10nPlaceholder(name: 'humidity', type: 'int')],
    bundled: {
      'en': 'Humidity {humidity}%',
      'hi': 'नमी {humidity}%',
      'mr': 'आर्द्रता {humidity}%',
      'te': 'తేమ {humidity}%',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'typeToSearchVillage',
    description: 'Shown in village search until enough letters are typed',
    placeholders: [L10nPlaceholder(name: 'count', type: 'int')],
    bundled: {
      'en': 'Type at least {count} letters to search',
      'hi': 'खोजने के लिए कम से कम {count} अक्षर लिखें',
      'mr': 'शोधण्यासाठी किमान {count} अक्षरे टाइप करा',
      'te': 'వెతకడానికి కనీసం {count} అక్షరాలు టైప్ చేయండి',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'launchpadComingSoon',
    description:
        'Shown when a home shortcut tile is tapped before its screen exists',
    placeholders: [
      L10nPlaceholder(name: 'title', type: 'String', example: 'Ponds'),
    ],
    bundled: {
      'en': '{title} is coming soon',
      'hi': '{title} जल्द आ रहा है',
      'mr': '{title} लवकरच येत आहे',
      'te': '{title} త్వరలో వస్తోంది',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'pondCount',
    description: 'POC-only plural: number of ponds a farmer owns',
    placeholders: [L10nPlaceholder(name: 'count', type: 'int')],
    bundled: {
      'en': '{count, plural, =0{No ponds yet} =1{1 pond} other{{count} ponds}}',
      'hi': '{count, plural, =0{अभी कोई तालाब नहीं} =1{1 तालाब} other{{count} तालाब}}',
      'mr': '{count, plural, =0{अजून एकही तलाव नाही} =1{1 तलाव} other{{count} तलाव}}',
      'te': '{count, plural, =0{ఇంకా చెరువులు లేవు} =1{1 చెరువు} other{{count} చెరువులు}}',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'pocTitle',
    description: 'App bar title of the POC screen',
    placeholders: [],
    bundled: {
      'en': 'Firebase OTA POC',
      'hi': 'Firebase OTA POC',
      'mr': 'Firebase OTA POC',
      'te': 'Firebase OTA POC',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'pocLanguage',
    description: 'Label of the language picker',
    placeholders: [],
    bundled: {'en': 'Language', 'hi': 'भाषा', 'mr': 'भाषा', 'te': 'భాష'},
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'pocSourceBundled',
    description: 'Shown when no OTA translations are loaded',
    placeholders: [],
    bundled: {
      'en': 'Source: bundled ARB',
      'hi': 'स्रोत: ऐप में शामिल ARB',
      'mr': 'स्रोत: ॲपमधील ARB',
      'te': 'మూలం: యాప్‌లోని ARB',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'pocSourceCache',
    description: 'Shown when OTA translations come from the local cache',
    placeholders: [],
    bundled: {
      'en': 'Source: device cache',
      'hi': 'स्रोत: डिवाइस कैश',
      'mr': 'स्रोत: डिव्हाइस कॅशे',
      'te': 'మూలం: పరికర కాష్',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'pocSourceNetwork',
    description: 'Shown when OTA translations were just fetched from Firestore',
    placeholders: [],
    bundled: {
      'en': 'Source: Firestore',
      'hi': 'स्रोत: Firestore',
      'mr': 'स्रोत: Firestore',
      'te': 'మూలం: Firestore',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'pocRefresh',
    description: 'Button that re-fetches OTA translations from Firestore',
    placeholders: [],
    bundled: {
      'en': 'Fetch from Firestore',
      'hi': 'Firestore से लाएं',
      'mr': 'Firestore वरून आणा',
      'te': 'Firestore నుండి తీసుకురండి',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'pocNotConfigured',
    description: 'Shown when the Firebase options are missing from env',
    placeholders: [],
    bundled: {
      'en': 'Firebase is not configured, showing bundled strings only',
      'hi': 'Firebase कॉन्फ़िगर नहीं है, केवल ऐप में शामिल टेक्स्ट दिखाया जा रहा है',
      'mr': 'Firebase कॉन्फिगर केलेले नाही, फक्त ॲपमधील मजकूर दाखवत आहे',
      'te': 'Firebase కాన్ఫిగర్ చేయలేదు, యాప్‌లోని పాఠ్యం మాత్రమే చూపిస్తోంది',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'pocRefreshFailed',
    description: 'Shown when the Firestore fetch fails',
    placeholders: [L10nPlaceholder(name: 'reason', type: 'String')],
    bundled: {
      'en': 'Could not fetch translations: {reason}',
      'hi': 'अनुवाद नहीं लाए जा सके: {reason}',
      'mr': 'भाषांतरे आणता आली नाहीत: {reason}',
      'te': 'అనువాదాలు తీసుకురాలేకపోయాము: {reason}',
    },
    otaEnabled: true,
  ),
  L10nKeyInfo(
    name: 'pocOverriddenKeys',
    description: 'Number of keys currently served from OTA',
    placeholders: [L10nPlaceholder(name: 'count', type: 'int')],
    bundled: {
      'en': '{count} keys from OTA',
      'hi': 'OTA से {count} कुंजियाँ',
      'mr': 'OTA मधून {count} की',
      'te': 'OTA నుండి {count} కీలు',
    },
    otaEnabled: true,
  ),
];
